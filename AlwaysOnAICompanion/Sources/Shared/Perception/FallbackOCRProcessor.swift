import Foundation
import CoreGraphics

/// OCR processor that automatically falls back from Apple Vision to Tesseract based on confidence scores and error conditions
public class FallbackOCRProcessor: OCRProcessor {
    
    public var confidence: Float = 0.0
    
    private let visionProcessor: VisionOCRProcessor
    private let tesseractProcessor: TesseractOCRProcessor
    private let configuration: FallbackConfiguration
    
    /// Configuration for fallback behavior
    public struct FallbackConfiguration {
        public let minimumVisionConfidence: Float
        public let enableAutomaticFallback: Bool
        public let fallbackTimeout: TimeInterval
        public let maxRetryAttempts: Int
        public let preferTesseractForLanguages: Set<String>
        
        public init(minimumVisionConfidence: Float = 0.4,
                   enableAutomaticFallback: Bool = true,
                   fallbackTimeout: TimeInterval = 10.0,
                   maxRetryAttempts: Int = 2,
                   preferTesseractForLanguages: Set<String> = ["de-DE", "fr-FR"]) {
            self.minimumVisionConfidence = minimumVisionConfidence
            self.enableAutomaticFallback = enableAutomaticFallback
            self.fallbackTimeout = fallbackTimeout
            self.maxRetryAttempts = maxRetryAttempts
            self.preferTesseractForLanguages = preferTesseractForLanguages
        }
    }
    
    /// Result with processor information
    public struct FallbackResult {
        public let ocrResults: [OCRResult]
        public let processorUsed: ProcessorType
        public let processingTime: TimeInterval
        public let fallbackReason: FallbackReason?
        public let attempts: Int
        
        public enum ProcessorType {
            case vision
            case tesseract
            case hybrid
        }
        
        public enum FallbackReason {
            case lowConfidence(Float)
            case visionError(Error)
            case timeout
            case languagePreference(String)
            case noTextDetected
        }
    }
    
    /// Performance metrics for monitoring
    public struct PerformanceMetrics {
        public let visionSuccessRate: Float
        public let tesseractSuccessRate: Float
        public let averageVisionTime: TimeInterval
        public let averageTesseractTime: TimeInterval
        public let fallbackRate: Float
        public let totalProcessed: Int
        
        public init(visionSuccessRate: Float = 0.0,
                   tesseractSuccessRate: Float = 0.0,
                   averageVisionTime: TimeInterval = 0.0,
                   averageTesseractTime: TimeInterval = 0.0,
                   fallbackRate: Float = 0.0,
                   totalProcessed: Int = 0) {
            self.visionSuccessRate = visionSuccessRate
            self.tesseractSuccessRate = tesseractSuccessRate
            self.averageVisionTime = averageVisionTime
            self.averageTesseractTime = averageTesseractTime
            self.fallbackRate = fallbackRate
            self.totalProcessed = totalProcessed
        }
    }
    
    private var metrics = PerformanceMetrics()
    private var visionAttempts = 0
    private var visionSuccesses = 0
    private var tesseractAttempts = 0
    private var tesseractSuccesses = 0
    private var fallbackCount = 0
    private var totalVisionTime: TimeInterval = 0
    private var totalTesseractTime: TimeInterval = 0
    
    public init(configuration: FallbackConfiguration = FallbackConfiguration()) throws {
        self.configuration = configuration
        self.visionProcessor = VisionOCRProcessor()
        self.tesseractProcessor = try TesseractOCRProcessor()
    }
    
    /// Extract text with automatic fallback logic
    public func extractText(from image: CGImage) async throws -> [OCRResult] {
        let result = try await extractTextWithDetails(from: image)
        return result.ocrResults
    }
    
    /// Extract text with detailed fallback information
    public func extractTextWithDetails(from image: CGImage) async throws -> FallbackResult {
        let startTime = Date()
        var attempts = 0
        
        // Check if we should prefer Tesseract for this image based on language hints
        if shouldPreferTesseract(for: image) {
            return try await processWithTesseract(image, startTime: startTime, attempts: &attempts, fallbackReason: .languagePreference("detected"))
        }
        
        // Primary attempt with Apple Vision
        do {
            attempts += 1
            let visionStartTime = Date()
            let visionResults = try await withTimeout(configuration.fallbackTimeout) {
                try await self.visionProcessor.extractText(from: image)
            }
            let visionTime = Date().timeIntervalSince(visionStartTime)
            
            visionAttempts += 1
            totalVisionTime += visionTime
            
            // Check if Vision results meet confidence threshold
            let averageConfidence = visionResults.isEmpty ? 0.0 : visionResults.map { $0.confidence }.reduce(0, +) / Float(visionResults.count)
            
            if averageConfidence >= configuration.minimumVisionConfidence && !visionResults.isEmpty {
                visionSuccesses += 1
                self.confidence = averageConfidence
                
                let totalTime = Date().timeIntervalSince(startTime)
                return FallbackResult(
                    ocrResults: visionResults,
                    processorUsed: .vision,
                    processingTime: totalTime,
                    fallbackReason: nil,
                    attempts: attempts
                )
            } else if configuration.enableAutomaticFallback {
                // Fall back to Tesseract due to low confidence
                let fallbackReason: FallbackResult.FallbackReason = visionResults.isEmpty ? .noTextDetected : .lowConfidence(averageConfidence)
                return try await processWithTesseract(image, startTime: startTime, attempts: &attempts, fallbackReason: fallbackReason)
            } else {
                // Return Vision results even if confidence is low
                self.confidence = averageConfidence
                let totalTime = Date().timeIntervalSince(startTime)
                return FallbackResult(
                    ocrResults: visionResults,
                    processorUsed: .vision,
                    processingTime: totalTime,
                    fallbackReason: nil,
                    attempts: attempts
                )
            }
            
        } catch {
            if configuration.enableAutomaticFallback {
                // Fall back to Tesseract due to Vision error
                return try await processWithTesseract(image, startTime: startTime, attempts: &attempts, fallbackReason: .visionError(error))
            } else {
                throw error
            }
        }
    }
    
    /// Process image with hybrid approach (both processors)
    public func extractTextHybrid(from image: CGImage) async throws -> FallbackResult {
        let startTime = Date()
        
        // Run both processors concurrently
        async let visionTask = tryVisionOCR(image)
        async let tesseractTask = tryTesseractOCR(image)
        
        let (visionResult, tesseractResult) = await (visionTask, tesseractTask)
        
        // Combine and compare results
        let combinedResults = combineResults(vision: visionResult, tesseract: tesseractResult)
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        return FallbackResult(
            ocrResults: combinedResults,
            processorUsed: .hybrid,
            processingTime: totalTime,
            fallbackReason: nil,
            attempts: 2
        )
    }
    
    /// Preprocess image using the best available method
    public func preprocessImage(_ image: CGImage) -> CGImage {
        // Use Vision preprocessing as primary, with Tesseract as fallback
        let visionProcessed = visionProcessor.preprocessImage(image)
        
        // For certain image characteristics, Tesseract preprocessing might be better
        if shouldUseTesseractPreprocessing(image) {
            return tesseractProcessor.preprocessImage(image)
        }
        
        return visionProcessed
    }
    
    /// Get current performance metrics
    public func getPerformanceMetrics() -> PerformanceMetrics {
        let totalProcessed = visionAttempts + tesseractAttempts
        
        return PerformanceMetrics(
            visionSuccessRate: visionAttempts > 0 ? Float(visionSuccesses) / Float(visionAttempts) : 0.0,
            tesseractSuccessRate: tesseractAttempts > 0 ? Float(tesseractSuccesses) / Float(tesseractAttempts) : 0.0,
            averageVisionTime: visionAttempts > 0 ? totalVisionTime / Double(visionAttempts) : 0.0,
            averageTesseractTime: tesseractAttempts > 0 ? totalTesseractTime / Double(tesseractAttempts) : 0.0,
            fallbackRate: totalProcessed > 0 ? Float(fallbackCount) / Float(totalProcessed) : 0.0,
            totalProcessed: totalProcessed
        )
    }
    
    /// Reset performance metrics
    public func resetMetrics() {
        visionAttempts = 0
        visionSuccesses = 0
        tesseractAttempts = 0
        tesseractSuccesses = 0
        fallbackCount = 0
        totalVisionTime = 0
        totalTesseractTime = 0
    }
    
    // MARK: - Private Methods
    
    private func processWithTesseract(_ image: CGImage, startTime: Date, attempts: inout Int, fallbackReason: FallbackResult.FallbackReason) async throws -> FallbackResult {
        attempts += 1
        fallbackCount += 1
        
        let tesseractStartTime = Date()
        let tesseractResults = try await tesseractProcessor.extractText(from: image)
        let tesseractTime = Date().timeIntervalSince(tesseractStartTime)
        
        tesseractAttempts += 1
        totalTesseractTime += tesseractTime
        
        if !tesseractResults.isEmpty {
            tesseractSuccesses += 1
        }
        
        self.confidence = tesseractProcessor.confidence
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        return FallbackResult(
            ocrResults: tesseractResults,
            processorUsed: .tesseract,
            processingTime: totalTime,
            fallbackReason: fallbackReason,
            attempts: attempts
        )
    }
    
    private func tryVisionOCR(_ image: CGImage) async -> (results: [OCRResult], error: Error?) {
        do {
            let results = try await visionProcessor.extractText(from: image)
            return (results, nil)
        } catch {
            return ([], error)
        }
    }
    
    private func tryTesseractOCR(_ image: CGImage) async -> (results: [OCRResult], error: Error?) {
        do {
            let results = try await tesseractProcessor.extractText(from: image)
            return (results, nil)
        } catch {
            return ([], error)
        }
    }
    
    private func combineResults(vision: (results: [OCRResult], error: Error?), tesseract: (results: [OCRResult], error: Error?)) -> [OCRResult] {
        let visionResults = vision.results
        let tesseractResults = tesseract.results
        
        // If one processor failed, use the other
        if vision.error != nil && tesseract.error == nil {
            return tesseractResults
        } else if tesseract.error != nil && vision.error == nil {
            return visionResults
        } else if vision.error != nil && tesseract.error != nil {
            return [] // Both failed
        }
        
        // Both succeeded - combine intelligently
        var combinedResults: [OCRResult] = []
        
        // Use Vision results as base (generally more accurate for modern text)
        combinedResults.append(contentsOf: visionResults)
        
        // Add Tesseract results that don't overlap significantly with Vision results
        for tesseractResult in tesseractResults {
            let hasSignificantOverlap = visionResults.contains { visionResult in
                boundingBoxOverlap(tesseractResult.boundingBox, visionResult.boundingBox) > 0.5
            }
            
            if !hasSignificantOverlap {
                combinedResults.append(tesseractResult)
            }
        }
        
        return combinedResults
    }
    
    private func boundingBoxOverlap(_ box1: CGRect, _ box2: CGRect) -> Float {
        let intersection = box1.intersection(box2)
        if intersection.isNull {
            return 0.0
        }
        
        let intersectionArea = intersection.width * intersection.height
        let unionArea = box1.width * box1.height + box2.width * box2.height - intersectionArea
        
        return Float(intersectionArea / unionArea)
    }
    
    private func shouldPreferTesseract(for image: CGImage) -> Bool {
        // Analyze image characteristics to determine if Tesseract might be better
        // This is a simplified heuristic - in practice, you might use more sophisticated analysis
        
        // Check image dimensions - Tesseract often works better on high-resolution images
        if image.width > 2000 || image.height > 2000 {
            return true
        }
        
        // For now, use configuration-based language preference
        // In a real implementation, you might analyze the image for language hints
        return false
    }
    
    private func shouldUseTesseractPreprocessing(_ image: CGImage) -> Bool {
        // Determine if Tesseract preprocessing might be better for this image
        // Tesseract preprocessing is often better for:
        // - Low contrast images
        // - Images with complex backgrounds
        // - Scanned documents
        
        // Simple heuristic based on image size and aspect ratio
        let aspectRatio = Float(image.width) / Float(image.height)
        
        // Document-like aspect ratios might benefit from Tesseract preprocessing
        return aspectRatio > 0.7 && aspectRatio < 1.5
    }
}

// MARK: - Timeout Utility

private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw FallbackTimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw FallbackTimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

private struct FallbackTimeoutError: Error {
    let message = "Fallback operation timed out"
}