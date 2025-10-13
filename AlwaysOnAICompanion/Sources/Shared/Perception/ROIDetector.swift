import Foundation
import Vision
import CoreImage
import CoreGraphics
import AppKit

/// ROI (Region of Interest) detector for identifying text regions and UI elements
public class ROIDetector {
    
    private let minimumROISize: CGSize = CGSize(width: 20, height: 10)
    private let maximumROISize: CGSize = CGSize(width: 800, height: 200)
    private let confidenceThreshold: Float = 0.3
    
    public init() {}
    
    /// Detect regions of interest in an image for targeted OCR processing
    public func detectROIs(in image: CGImage) async throws -> [ROI] {
        var rois: [ROI] = []
        
        // Detect text regions using Vision
        let textROIs = try await detectTextRegions(in: image)
        rois.append(contentsOf: textROIs)
        
        // Detect UI elements using rectangle detection
        let uiROIs = try await detectUIElements(in: image)
        rois.append(contentsOf: uiROIs)
        
        // Filter and merge overlapping ROIs
        let filteredROIs = filterAndMergeROIs(rois)
        
        return filteredROIs
    }
    
    /// Crop image to specific ROI for focused processing
    public func cropToROI(_ image: CGImage, roi: ROI) -> CGImage? {
        let cropRect = roi.rect
        
        // Ensure crop rect is within image bounds
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let validCropRect = cropRect.intersection(imageRect)
        
        guard !validCropRect.isEmpty else { return nil }
        
        return image.cropping(to: validCropRect)
    }
    
    /// Batch process multiple ROIs from an image
    public func batchCropROIs(_ image: CGImage, rois: [ROI]) -> [(ROI, CGImage)] {
        var results: [(ROI, CGImage)] = []
        
        for roi in rois {
            if let croppedImage = cropToROI(image, roi: roi) {
                results.append((roi, croppedImage))
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func detectTextRegions(in image: CGImage) async throws -> [ROI] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let rois = self.processTextObservations(observations, imageSize: CGSize(width: image.width, height: image.height))
                continuation.resume(returning: rois)
            }
            
            // Configure for better text detection
            request.reportCharacterBoxes = true
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func detectUIElements(in image: CGImage) async throws -> [ROI] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let rois = self.processRectangleObservations(observations, imageSize: CGSize(width: image.width, height: image.height))
                continuation.resume(returning: rois)
            }
            
            // Configure rectangle detection
            request.minimumAspectRatio = 0.1
            request.maximumAspectRatio = 10.0
            request.minimumSize = 0.01
            request.minimumConfidence = confidenceThreshold
            request.maximumObservations = 50
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func processTextObservations(_ observations: [VNTextObservation], imageSize: CGSize) -> [ROI] {
        var rois: [ROI] = []
        
        for observation in observations {
            let boundingBox = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
            
            // Filter by size
            guard boundingBox.width >= minimumROISize.width && boundingBox.height >= minimumROISize.height else { continue }
            guard boundingBox.width <= maximumROISize.width && boundingBox.height <= maximumROISize.height else { continue }
            
            // Classify text region type based on characteristics
            let roiType = classifyTextRegion(boundingBox: boundingBox, imageSize: imageSize)
            
            let roi = ROI(rect: boundingBox, type: roiType)
            rois.append(roi)
        }
        
        return rois
    }
    
    private func processRectangleObservations(_ observations: [VNRectangleObservation], imageSize: CGSize) -> [ROI] {
        var rois: [ROI] = []
        
        for observation in observations {
            let boundingBox = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
            
            // Filter by size and confidence
            guard observation.confidence >= confidenceThreshold else { continue }
            guard boundingBox.width >= minimumROISize.width && boundingBox.height >= minimumROISize.height else { continue }
            
            // Classify UI element type based on shape and position
            let roiType = classifyUIElement(boundingBox: boundingBox, imageSize: imageSize)
            
            let roi = ROI(rect: boundingBox, type: roiType)
            rois.append(roi)
        }
        
        return rois
    }
    
    private func classifyTextRegion(boundingBox: CGRect, imageSize: CGSize) -> ROI.ROIType {
        let aspectRatio = boundingBox.width / boundingBox.height
        let relativeWidth = boundingBox.width / imageSize.width
        let relativeHeight = boundingBox.height / imageSize.height
        let yPosition = boundingBox.midY / imageSize.height
        
        // Classify based on characteristics
        if aspectRatio > 5.0 && relativeHeight < 0.05 {
            return .textField // Long, thin regions are likely text fields
        } else if aspectRatio < 3.0 && relativeWidth < 0.3 && relativeHeight < 0.1 {
            return .button // Square-ish, small regions might be buttons
        } else if yPosition < 0.1 || yPosition > 0.9 {
            return .menuItem // Top or bottom regions might be menu items
        } else if relativeWidth > 0.5 && relativeHeight > 0.3 {
            return .dialog // Large regions might be dialogs
        } else {
            return .label // Default to label
        }
    }
    
    private func classifyUIElement(boundingBox: CGRect, imageSize: CGSize) -> ROI.ROIType {
        let aspectRatio = boundingBox.width / boundingBox.height
        let relativeArea = (boundingBox.width * boundingBox.height) / (imageSize.width * imageSize.height)
        
        // Simple classification based on shape
        if aspectRatio > 2.0 && aspectRatio < 8.0 && relativeArea < 0.05 {
            return .button
        } else if relativeArea > 0.2 {
            return .dialog
        } else {
            return .general
        }
    }
    
    private func filterAndMergeROIs(_ rois: [ROI]) -> [ROI] {
        var filteredROIs: [ROI] = []
        
        // Sort ROIs by area (largest first)
        let sortedROIs = rois.sorted { $0.rect.width * $0.rect.height > $1.rect.width * $1.rect.height }
        
        for roi in sortedROIs {
            var shouldAdd = true
            
            // Check for significant overlap with existing ROIs
            for existingROI in filteredROIs {
                let intersection = roi.rect.intersection(existingROI.rect)
                let unionArea = roi.rect.union(existingROI.rect)
                let overlapRatio = (intersection.width * intersection.height) / (unionArea.width * unionArea.height)
                
                if overlapRatio > 0.5 {
                    shouldAdd = false
                    break
                }
            }
            
            if shouldAdd {
                filteredROIs.append(roi)
            }
        }
        
        return filteredROIs
    }
}

// MARK: - ROI Extensions

extension ROI {
    /// Check if this ROI is suitable for text extraction
    public var isTextSuitable: Bool {
        let area = rect.width * rect.height
        return area >= 200 && rect.width >= 20 && rect.height >= 10
    }
    
    /// Get priority for processing (higher values processed first)
    public var processingPriority: Int {
        switch type {
        case .textField:
            return 5
        case .button:
            return 4
        case .dialog:
            return 3
        case .label:
            return 2
        case .menuItem:
            return 1
        case .general:
            return 0
        }
    }
}