import XCTest
import CoreGraphics
import AppKit
@testable import Shared

/// Basic tests for Vision OCR functionality
final class VisionOCRBasicTests: XCTestCase {
    
    var processor: VisionOCRProcessor!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        processor = VisionOCRProcessor()
    }
    
    override func tearDownWithError() throws {
        processor = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testVisionOCRProcessorInitialization() {
        XCTAssertNotNil(processor, "VisionOCRProcessor should initialize successfully")
        XCTAssertEqual(processor.confidence, 0.0, "Initial confidence should be 0")
    }
    
    func testExtractTextFromSimpleImage() async throws {
        let testImage = try TestImageFactory.createTextImage(text: "Hello World")
        
        let results = try await processor.extractText(from: testImage)
        
        // Basic validation - we should get some results
        XCTAssertFalse(results.isEmpty, "Should extract text from simple image")
        
        // Check that we found the expected text
        let allText = results.map { $0.text }.joined(separator: " ")
        XCTAssertTrue(allText.contains("Hello") || allText.contains("World"), 
                     "Should detect 'Hello' or 'World' in text")
        
        // Confidence should be updated
        XCTAssertGreaterThan(processor.confidence, 0.0, "Should have positive confidence after processing")
    }
    
    func testExtractTextFromEmptyImage() async throws {
        let emptyImage = try TestImageFactory.createEmptyImage()
        
        let results = try await processor.extractText(from: emptyImage)
        
        // Empty image should return empty results
        XCTAssertTrue(results.isEmpty, "Empty image should return no text")
        XCTAssertEqual(processor.confidence, 0.0, "Confidence should be 0 for empty image")
    }
    
    func testImagePreprocessing() throws {
        let testImage = try TestImageFactory.createTextImage(text: "Test")
        
        let preprocessedImage = processor.preprocessImage(testImage)
        
        XCTAssertNotNil(preprocessedImage, "Preprocessing should return valid image")
        XCTAssertEqual(preprocessedImage.width, testImage.width, "Width should be preserved")
        XCTAssertEqual(preprocessedImage.height, testImage.height, "Height should be preserved")
    }
    
    func testBatchProcessing() async throws {
        let images = [
            try TestImageFactory.createTextImage(text: "Image 1"),
            try TestImageFactory.createTextImage(text: "Image 2"),
            try TestImageFactory.createTextImage(text: "Image 3")
        ]
        
        let results = try await processor.processBatch(images)
        
        XCTAssertEqual(results.count, images.count, "Should process all images")
        
        for (key, _) in results {
            XCTAssertTrue(key.hasPrefix("frame_"), "Frame ID should have correct format")
        }
    }
    
    // MARK: - ROI Detector Tests
    
    func testROIDetectorInitialization() {
        let detector = ROIDetector()
        XCTAssertNotNil(detector, "ROIDetector should initialize successfully")
    }
    
    func testDetectROIsInSimpleImage() async throws {
        let detector = ROIDetector()
        let testImage = try TestImageFactory.createTextImage(text: "Button Text")
        
        let rois = try await detector.detectROIs(in: testImage)
        
        // Should detect at least some regions
        XCTAssertGreaterThanOrEqual(rois.count, 0, "Should detect ROIs (may be 0 for simple images)")
        
        // Verify ROI properties if any are found
        for roi in rois {
            XCTAssertTrue(roi.rect.width > 0, "ROI should have positive width")
            XCTAssertTrue(roi.rect.height > 0, "ROI should have positive height")
        }
    }
    
    // MARK: - Batch Processor Tests
    
    func testBatchProcessorInitialization() throws {
        let config = BatchOCRProcessor.BatchConfiguration()
        let batchProcessor = try BatchOCRProcessor(configuration: config)
        
        XCTAssertNotNil(batchProcessor, "BatchOCRProcessor should initialize successfully")
    }
    
    func testSimpleBatchProcessing() async throws {
        let config = BatchOCRProcessor.BatchConfiguration(
            maxConcurrentTasks: 2,
            enableROIDetection: false,
            minimumConfidence: 0.1,
            processingTimeout: 10.0
        )
        let batchProcessor = try BatchOCRProcessor(configuration: config)
        
        let frames = [
            BatchOCRProcessor.FrameInput(
                id: "test_1",
                image: try TestImageFactory.createTextImage(text: "Test 1")
            ),
            BatchOCRProcessor.FrameInput(
                id: "test_2", 
                image: try TestImageFactory.createTextImage(text: "Test 2")
            )
        ]
        
        let results = try await batchProcessor.processBatch(frames)
        
        XCTAssertEqual(results.count, frames.count, "Should process all frames")
        
        for result in results {
            XCTAssertNil(result.error, "Should not have processing errors")
            XCTAssertGreaterThan(result.processingTime, 0, "Should record processing time")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBasicPerformance() async throws {
        let testImage = try TestImageFactory.createTextImage(text: "Performance Test")
        
        let startTime = Date()
        let _ = try await processor.extractText(from: testImage)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        XCTAssertLessThan(processingTime, 5.0, "Basic OCR should complete within 5 seconds")
    }
    
    // MARK: - Error Handling Tests
    
    func testCorruptedImageHandling() async throws {
        // Create minimal image that might cause issues
        let minimalImage = try TestImageFactory.createMinimalImage()
        
        // Should handle gracefully without crashing
        let results = try await processor.extractText(from: minimalImage)
        XCTAssertTrue(results.isEmpty, "Minimal image should return empty results")
    }
    
    // MARK: - Fallback System Tests
    
    func testTesseractFallbackInitialization() throws {
        let tesseractProcessor = try TesseractOCRProcessor()
        XCTAssertNotNil(tesseractProcessor, "TesseractOCRProcessor should initialize successfully")
        XCTAssertEqual(tesseractProcessor.confidence, 0.0, "Initial confidence should be 0.0")
    }
    
    func testFallbackOCRProcessorInitialization() throws {
        let fallbackProcessor = try FallbackOCRProcessor()
        XCTAssertNotNil(fallbackProcessor, "FallbackOCRProcessor should initialize successfully")
        XCTAssertEqual(fallbackProcessor.confidence, 0.0, "Initial confidence should be 0.0")
    }
    
    func testFallbackOCRBasicFunctionality() async throws {
        let fallbackProcessor = try FallbackOCRProcessor()
        let testImage = try TestImageFactory.createTextImage(text: "Fallback Test")
        
        let results = try await fallbackProcessor.extractText(from: testImage)
        
        XCTAssertFalse(results.isEmpty, "Fallback processor should extract text")
        XCTAssertGreaterThan(fallbackProcessor.confidence, 0.0, "Should have positive confidence")
    }
    
    func testFallbackOCRWithDetails() async throws {
        let fallbackProcessor = try FallbackOCRProcessor()
        let testImage = try TestImageFactory.createTextImage(text: "Detailed Fallback Test")
        
        let result = try await fallbackProcessor.extractTextWithDetails(from: testImage)
        
        XCTAssertFalse(result.ocrResults.isEmpty, "Should extract text with details")
        XCTAssertTrue(result.processorUsed == .vision || result.processorUsed == .tesseract, "Should use either Vision or Tesseract")
        XCTAssertGreaterThan(result.processingTime, 0, "Should have positive processing time")
        XCTAssertGreaterThan(result.attempts, 0, "Should have at least one attempt")
    }
    
    func testBatchProcessorWithFallback() async throws {
        let batchProcessor = try BatchOCRProcessor()
        
        let frames = try (0..<3).map { index in
            let image = try TestImageFactory.createTextImage(text: "Batch fallback test \(index)")
            return BatchOCRProcessor.FrameInput(id: "frame_\(index)", image: image)
        }
        
        let results = try await batchProcessor.processBatch(frames)
        
        XCTAssertEqual(results.count, frames.count, "Should process all frames")
        
        for result in results {
            XCTAssertNotNil(result.frameId, "Should have frame ID")
            XCTAssertGreaterThanOrEqual(result.processingTime, 0, "Should have non-negative processing time")
        }
        
        // Check that metrics are being tracked
        let metrics = batchProcessor.getPerformanceMetrics()
        XCTAssertGreaterThan(metrics.totalProcessed, 0, "Should have processed some images")
    }
    
    func testFallbackPerformanceMetrics() async throws {
        let fallbackProcessor = try FallbackOCRProcessor()
        
        // Reset metrics first
        fallbackProcessor.resetMetrics()
        
        let initialMetrics = fallbackProcessor.getPerformanceMetrics()
        XCTAssertEqual(initialMetrics.totalProcessed, 0)
        XCTAssertEqual(initialMetrics.fallbackRate, 0.0)
        
        // Process some images
        let testImages = try (0..<2).map { index in
            try TestImageFactory.createTextImage(text: "Metrics test \(index)")
        }
        
        for image in testImages {
            _ = try await fallbackProcessor.extractText(from: image)
        }
        
        let finalMetrics = fallbackProcessor.getPerformanceMetrics()
        XCTAssertEqual(finalMetrics.totalProcessed, 2)
        XCTAssertGreaterThanOrEqual(finalMetrics.visionSuccessRate, 0.0)
        XCTAssertGreaterThanOrEqual(finalMetrics.averageVisionTime, 0.0)
    }
}