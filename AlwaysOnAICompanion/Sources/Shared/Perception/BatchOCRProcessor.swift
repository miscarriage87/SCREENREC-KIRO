import Foundation
import CoreGraphics

/// Batch processing system for efficient OCR processing of multiple keyframes
public class BatchOCRProcessor {
    
    private let fallbackProcessor: FallbackOCRProcessor
    private let roiDetector: ROIDetector
    private let maxConcurrentTasks: Int
    
    /// Configuration for batch processing
    public struct BatchConfiguration {
        public let maxConcurrentTasks: Int
        public let enableROIDetection: Bool
        public let minimumConfidence: Float
        public let processingTimeout: TimeInterval
        
        public init(maxConcurrentTasks: Int = 4, 
                   enableROIDetection: Bool = true, 
                   minimumConfidence: Float = 0.3,
                   processingTimeout: TimeInterval = 30.0) {
            self.maxConcurrentTasks = maxConcurrentTasks
            self.enableROIDetection = enableROIDetection
            self.minimumConfidence = minimumConfidence
            self.processingTimeout = processingTimeout
        }
    }
    
    /// Batch processing result
    public struct BatchResult {
        public let frameId: String
        public let ocrResults: [OCRResult]
        public let rois: [ROI]
        public let processingTime: TimeInterval
        public let error: Error?
        
        public init(frameId: String, ocrResults: [OCRResult], rois: [ROI], processingTime: TimeInterval, error: Error? = nil) {
            self.frameId = frameId
            self.ocrResults = ocrResults
            self.rois = rois
            self.processingTime = processingTime
            self.error = error
        }
    }
    
    /// Input frame for batch processing
    public struct FrameInput {
        public let id: String
        public let image: CGImage
        public let timestamp: Date
        public let metadata: [String: Any]
        
        public init(id: String, image: CGImage, timestamp: Date = Date(), metadata: [String: Any] = [:]) {
            self.id = id
            self.image = image
            self.timestamp = timestamp
            self.metadata = metadata
        }
    }
    
    private let configuration: BatchConfiguration
    
    public init(configuration: BatchConfiguration = BatchConfiguration()) throws {
        self.configuration = configuration
        self.maxConcurrentTasks = configuration.maxConcurrentTasks
        self.fallbackProcessor = try FallbackOCRProcessor()
        self.roiDetector = ROIDetector()
    }
    
    /// Process a batch of keyframes with OCR
    public func processBatch(_ frames: [FrameInput]) async throws -> [BatchResult] {
        print("Starting batch processing of \(frames.count) frames")
        let startTime = Date()
        
        var results: [BatchResult] = []
        
        // Process frames with controlled concurrency
        await withTaskGroup(of: BatchResult.self) { group in
            let semaphore = AsyncSemaphore(value: maxConcurrentTasks)
            
            for frame in frames {
                group.addTask {
                    await semaphore.wait()
                    defer { 
                        Task { await semaphore.signal() }
                    }
                    
                    return await self.processFrame(frame)
                }
            }
            
            for await result in group {
                results.append(result)
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("Batch processing completed in \(totalTime)s for \(frames.count) frames")
        
        return results.sorted { $0.frameId < $1.frameId }
    }
    
    /// Process frames in streaming fashion for real-time processing
    public func processStream<S: AsyncSequence>(_ frameStream: S) async throws -> AsyncStream<BatchResult> where S.Element == FrameInput {
        return AsyncStream { continuation in
            Task {
                let semaphore = AsyncSemaphore(value: maxConcurrentTasks)
                
                do {
                    for try await frame in frameStream {
                        Task {
                            await semaphore.wait()
                            defer { 
                                Task { await semaphore.signal() }
                            }
                            
                            let result = await self.processFrame(frame)
                            continuation.yield(result)
                        }
                    }
                } catch {
                    print("Stream processing error: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// Process frames with ROI-based optimization
    public func processWithROIOptimization(_ frames: [FrameInput]) async throws -> [BatchResult] {
        guard configuration.enableROIDetection else {
            return try await processBatch(frames)
        }
        
        print("Starting ROI-optimized batch processing of \(frames.count) frames")
        var results: [BatchResult] = []
        
        await withTaskGroup(of: BatchResult.self) { group in
            let semaphore = AsyncSemaphore(value: maxConcurrentTasks)
            
            for frame in frames {
                group.addTask {
                    await semaphore.wait()
                    defer { 
                        Task { await semaphore.signal() }
                    }
                    
                    return await self.processFrameWithROI(frame)
                }
            }
            
            for await result in group {
                results.append(result)
            }
        }
        
        return results.sorted { $0.frameId < $1.frameId }
    }
    
    /// Get performance metrics from the fallback processor
    public func getPerformanceMetrics() -> FallbackOCRProcessor.PerformanceMetrics {
        return fallbackProcessor.getPerformanceMetrics()
    }
    
    /// Reset performance metrics
    public func resetMetrics() {
        fallbackProcessor.resetMetrics()
    }
    
    // MARK: - Private Methods
    
    private func processFrame(_ frame: FrameInput) async -> BatchResult {
        let startTime = Date()
        
        do {
            // Apply timeout to prevent hanging
            let ocrResults = try await withTimeout(configuration.processingTimeout) {
                try await self.fallbackProcessor.extractText(from: frame.image)
            }
            
            // Filter results by confidence
            let filteredResults = ocrResults.filter { $0.confidence >= configuration.minimumConfidence }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            return BatchResult(
                frameId: frame.id,
                ocrResults: filteredResults,
                rois: [],
                processingTime: processingTime
            )
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            print("OCR processing failed for frame \(frame.id): \(error)")
            
            return BatchResult(
                frameId: frame.id,
                ocrResults: [],
                rois: [],
                processingTime: processingTime,
                error: error
            )
        }
    }
    
    private func processFrameWithROI(_ frame: FrameInput) async -> BatchResult {
        let startTime = Date()
        
        do {
            // First detect ROIs
            let rois = try await withTimeout(configuration.processingTimeout / 2) {
                try await self.roiDetector.detectROIs(in: frame.image)
            }
            
            var allOCRResults: [OCRResult] = []
            
            if rois.isEmpty {
                // No ROIs detected, process entire image
                let ocrResults = try await withTimeout(configuration.processingTimeout / 2) {
                    try await self.fallbackProcessor.extractText(from: frame.image)
                }
                allOCRResults = ocrResults
            } else {
                // Process each ROI separately for better accuracy
                let prioritizedROIs = rois.sorted { $0.processingPriority > $1.processingPriority }
                
                for roi in prioritizedROIs.prefix(10) { // Limit to top 10 ROIs
                    if let croppedImage = roiDetector.cropToROI(frame.image, roi: roi) {
                        let roiResults = try await fallbackProcessor.extractText(from: croppedImage)
                        
                        // Adjust bounding boxes to original image coordinates
                        let adjustedResults = roiResults.map { result in
                            let adjustedBoundingBox = CGRect(
                                x: result.boundingBox.origin.x + roi.rect.origin.x,
                                y: result.boundingBox.origin.y + roi.rect.origin.y,
                                width: result.boundingBox.width,
                                height: result.boundingBox.height
                            )
                            
                            return OCRResult(
                                text: result.text,
                                boundingBox: adjustedBoundingBox,
                                confidence: result.confidence,
                                language: result.language
                            )
                        }
                        
                        allOCRResults.append(contentsOf: adjustedResults)
                    }
                }
            }
            
            // Filter results by confidence
            let filteredResults = allOCRResults.filter { $0.confidence >= configuration.minimumConfidence }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            return BatchResult(
                frameId: frame.id,
                ocrResults: filteredResults,
                rois: rois,
                processingTime: processingTime
            )
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            print("ROI-based OCR processing failed for frame \(frame.id): \(error)")
            
            return BatchResult(
                frameId: frame.id,
                ocrResults: [],
                rois: [],
                processingTime: processingTime,
                error: error
            )
        }
    }
}

// MARK: - Utility Classes

/// Async semaphore for controlling concurrency
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if waiters.isEmpty {
            value += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

/// Timeout utility for async operations
private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

private struct TimeoutError: Error {
    let message = "Operation timed out"
}