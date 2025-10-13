import Foundation
import Vision
import CoreImage
import CoreGraphics
import AppKit

/// Protocol defining OCR processing capabilities
public protocol OCRProcessor {
    func extractText(from image: CGImage) async throws -> [OCRResult]
    func preprocessImage(_ image: CGImage) -> CGImage
    var confidence: Float { get }
}

/// Result structure for OCR operations
public struct OCRResult {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
    public let language: String
    
    public init(text: String, boundingBox: CGRect, confidence: Float, language: String) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.language = language
    }
}

/// Region of Interest for targeted OCR processing
public struct ROI {
    public let rect: CGRect
    public let type: ROIType
    
    public enum ROIType {
        case textField
        case button
        case label
        case menuItem
        case dialog
        case general
    }
    
    public init(rect: CGRect, type: ROIType) {
        self.rect = rect
        self.type = type
    }
}

/// Apple Vision-based OCR processor
public class VisionOCRProcessor: OCRProcessor {
    
    public var confidence: Float = 0.0
    
    private let minimumTextHeight: Float = 0.01
    private let recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    private let supportedLanguages: [String] = ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR", "ja-JP", "ko-KR", "zh-Hans", "zh-Hant"]
    
    public init() {}
    
    /// Extract text from image using Apple Vision framework
    public func extractText(from image: CGImage) async throws -> [OCRResult] {
        let preprocessedImage = preprocessImage(image)
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = self.processObservations(observations, imageSize: CGSize(width: image.width, height: image.height))
                continuation.resume(returning: results)
            }
            
            // Configure the request for optimal accuracy
            request.recognitionLevel = recognitionLevel
            request.recognitionLanguages = supportedLanguages
            request.usesLanguageCorrection = true
            request.minimumTextHeight = minimumTextHeight
            
            let handler = VNImageRequestHandler(cgImage: preprocessedImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Preprocess image for better OCR accuracy
    public func preprocessImage(_ image: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: image)
        let context = CIContext()
        
        // Apply image preprocessing pipeline
        var processedImage = ciImage
        
        // 1. Binarization - convert to black and white for better text recognition
        processedImage = applyBinarization(to: processedImage)
        
        // 2. Deskew - correct any rotation
        processedImage = applyDeskew(to: processedImage)
        
        // 3. Noise reduction
        processedImage = applyNoiseReduction(to: processedImage)
        
        // 4. Contrast enhancement
        processedImage = applyContrastEnhancement(to: processedImage)
        
        guard let outputImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return image // Return original if preprocessing fails
        }
        
        return outputImage
    }
    
    /// Process batch of keyframes efficiently
    public func processBatch(_ images: [CGImage]) async throws -> [String: [OCRResult]] {
        var results: [String: [OCRResult]] = [:]
        
        // Process images concurrently with controlled concurrency
        await withTaskGroup(of: (String, [OCRResult]).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let imageId = "frame_\(index)"
                    do {
                        let ocrResults = try await self.extractText(from: image)
                        return (imageId, ocrResults)
                    } catch {
                        print("OCR failed for image \(imageId): \(error)")
                        return (imageId, [])
                    }
                }
            }
            
            for await (imageId, ocrResults) in group {
                results[imageId] = ocrResults
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func processObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [OCRResult] {
        var results: [OCRResult] = []
        var totalConfidence: Float = 0.0
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let confidence = topCandidate.confidence
            totalConfidence += confidence
            
            // Convert normalized coordinates to image coordinates
            let boundingBox = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
            
            // Detect language (simplified - in practice, Vision can provide this)
            let detectedLanguage = detectLanguage(for: topCandidate.string)
            
            let result = OCRResult(
                text: topCandidate.string,
                boundingBox: boundingBox,
                confidence: confidence,
                language: detectedLanguage
            )
            
            results.append(result)
        }
        
        // Update overall confidence
        self.confidence = results.isEmpty ? 0.0 : totalConfidence / Float(results.count)
        
        return results
    }
    
    private func detectLanguage(for text: String) -> String {
        // Simple language detection based on character patterns
        // In a production system, you might use NLLanguageRecognizer
        if text.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil {
            return "zh-Hans" // Chinese
        } else if text.range(of: "[\\u3040-\\u309f\\u30a0-\\u30ff]", options: .regularExpression) != nil {
            return "ja-JP" // Japanese
        } else if text.range(of: "[\\uac00-\\ud7af]", options: .regularExpression) != nil {
            return "ko-KR" // Korean
        } else {
            return "en-US" // Default to English
        }
    }
    
    // MARK: - Image Processing Methods
    
    private func applyBinarization(to image: CIImage) -> CIImage {
        // Convert to grayscale first
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return image }
        grayscaleFilter.setValue(image, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
        
        guard let grayscaleImage = grayscaleFilter.outputImage else { return image }
        
        // Apply threshold for binarization
        guard let thresholdFilter = CIFilter(name: "CIColorThreshold") else { return grayscaleImage }
        thresholdFilter.setValue(grayscaleImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(0.5, forKey: "inputThreshold")
        
        return thresholdFilter.outputImage ?? grayscaleImage
    }
    
    private func applyDeskew(to image: CIImage) -> CIImage {
        // Simple deskew using perspective correction
        // In a production system, you would detect the skew angle first
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else { return image }
        
        let extent = image.extent
        let topLeft = CGPoint(x: extent.minX, y: extent.maxY)
        let topRight = CGPoint(x: extent.maxX, y: extent.maxY)
        let bottomLeft = CGPoint(x: extent.minX, y: extent.minY)
        let bottomRight = CGPoint(x: extent.maxX, y: extent.minY)
        
        perspectiveFilter.setValue(image, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        return perspectiveFilter.outputImage ?? image
    }
    
    private func applyNoiseReduction(to image: CIImage) -> CIImage {
        guard let noiseFilter = CIFilter(name: "CINoiseReduction") else { return image }
        noiseFilter.setValue(image, forKey: kCIInputImageKey)
        noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
        noiseFilter.setValue(0.40, forKey: "inputSharpness")
        
        return noiseFilter.outputImage ?? image
    }
    
    private func applyContrastEnhancement(to image: CIImage) -> CIImage {
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return image }
        contrastFilter.setValue(image, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast
        contrastFilter.setValue(1.1, forKey: kCIInputBrightnessKey) // Slight brightness increase
        
        return contrastFilter.outputImage ?? image
    }
}