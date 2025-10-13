import XCTest
import CoreGraphics
import AppKit
@testable import Shared

final class FallbackOCRTests: XCTestCase {
    
    var fallbackProcessor: FallbackOCRProcessor!
    
    override func setUp() async throws {
        try await super.setUp()
        fallbackProcessor = try FallbackOCRProcessor()
    }
    
    override func tearDown() async throws {
        fallbackProcessor = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Fallback Tests
    
    func testFallbackInitialization() throws {
        XCTAssertNotNil(fallbackProcessor)
        XCTAssertEqual(fallbackProcessor.confidence, 0.0)
    }
    
    func testVisionPrimarySuccess() async throws {
        let testImage = try createHighQualityTestImage("Clear Text")
        
        let result = try await fallbackProcessor.extractTextWithDetails(from: testImage)
        
        XCTAssertFalse(result.ocrResults.isEmpty, "Should extract text")
        XCTAssertEqual(result.processorUsed, .vision, "Should use Vision as primary processor")
        XCTAssertNil(result.fallbackReason, "Should not need fallback for clear text")
        XCTAssertEqual(result.attempts, 1, "Should succeed on first attempt")
    }
    
    func testFallbackToTesseract() async throws {
        // Create a configuration that forces fallback
        let config = FallbackOCRProcessor.FallbackConfiguration(
            minimumVisionConfidence: 0.9, // Very high threshold to force fallback
            enableAutomaticFallback: true,
            fallbackTimeout: 5.0,
            maxRetryAttempts: 2
        )
        
        let processor = try FallbackOCRProcessor(configuration: config)
        let testImage = try createMediumQualityTestImage("Fallback Test")
        
        let result = try await processor.extractTextWithDetails(from: testImage)
        
        // Should either use Vision (if confidence is high enough) or fallback to Tesseract
        XCTAssertFalse(result.ocrResults.isEmpty, "Should extract text with fallback")
        
        if result.processorUsed == .tesseract {
            XCTAssertNotNil(result.fallbackReason, "Should have fallback reason when using Tesseract")
            XCTAssertEqual(result.attempts, 2, "Should have attempted both processors")
        }
    }
    
    func testFallbackDisabled() async throws {
        let config = FallbackOCRProcessor.FallbackConfiguration(
            minimumVisionConfidence: 0.9,
            enableAutomaticFallback: false, // Disable fallback
            fallbackTimeout: 5.0,
            maxRetryAttempts: 1
        )
        
        let processor = try FallbackOCRProcessor(configuration: config)
        let testImage = try createMediumQualityTestImage("No Fallback Test")
        
        let result = try await processor.extractTextWithDetails(from: testImage)
        
        XCTAssertEqual(result.processorUsed, .vision, "Should only use Vision when fallback is disabled")
        XCTAssertEqual(result.attempts, 1, "Should only attempt once")
    }
    
    // MARK: - Hybrid Processing Tests
    
    func testHybridProcessing() async throws {
        let testImage = try createHighQualityTestImage("Hybrid Test Text")
        
        let result = try await fallbackProcessor.extractTextHybrid(from: testImage)
        
        XCTAssertEqual(result.processorUsed, .hybrid, "Should use hybrid processing")
        XCTAssertFalse(result.ocrResults.isEmpty, "Should extract text in hybrid mode")
        XCTAssertEqual(result.attempts, 2, "Should attempt both processors")
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetricsTracking() async throws {
        // Reset metrics first
        fallbackProcessor.resetMetrics()
        
        let initialMetrics = fallbackProcessor.getPerformanceMetrics()
        XCTAssertEqual(initialMetrics.totalProcessed, 0)
        XCTAssertEqual(initialMetrics.fallbackRate, 0.0)
        
        // Process some images
        let testImages = try (0..<3).map { index in
            try createHighQualityTestImage("Metrics Test \(index)")
        }
        
        for image in testImages {
            _ = try await fallbackProcessor.extractText(from: image)
        }
        
        let finalMetrics = fallbackProcessor.getPerformanceMetrics()
        XCTAssertEqual(finalMetrics.totalProcessed, 3)
        XCTAssertGreaterThanOrEqual(finalMetrics.visionSuccessRate, 0.0)
        XCTAssertGreaterThanOrEqual(finalMetrics.averageVisionTime, 0.0)
    }
    
    func testMetricsReset() async throws {
        // Process an image to generate metrics
        let testImage = try createHighQualityTestImage("Reset Test")
        _ = try await fallbackProcessor.extractText(from: testImage)
        
        let metricsBeforeReset = fallbackProcessor.getPerformanceMetrics()
        XCTAssertGreaterThan(metricsBeforeReset.totalProcessed, 0)
        
        // Reset metrics
        fallbackProcessor.resetMetrics()
        
        let metricsAfterReset = fallbackProcessor.getPerformanceMetrics()
        XCTAssertEqual(metricsAfterReset.totalProcessed, 0)
        XCTAssertEqual(metricsAfterReset.fallbackRate, 0.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testVisionErrorFallback() async throws {
        // This test is challenging because we can't easily force Vision to fail
        // In a real scenario, you might mock the Vision processor
        let testImage = try createCorruptedTestImage()
        
        // Should not throw even with problematic image
        let result = try await fallbackProcessor.extractTextWithDetails(from: testImage)
        
        // Should handle gracefully, either with Vision or Tesseract
        XCTAssertTrue(result.processorUsed == .vision || result.processorUsed == .tesseract)
    }
    
    func testTimeoutHandling() async throws {
        let config = FallbackOCRProcessor.FallbackConfiguration(
            minimumVisionConfidence: 0.5,
            enableAutomaticFallback: true,
            fallbackTimeout: 0.001, // Very short timeout to test timeout handling
            maxRetryAttempts: 1
        )
        
        let processor = try FallbackOCRProcessor(configuration: config)
        let testImage = try createHighQualityTestImage("Timeout Test")
        
        // This might timeout, but should handle gracefully
        do {
            let result = try await processor.extractTextWithDetails(from: testImage)
            // If it succeeds despite short timeout, that's also valid
            XCTAssertTrue(result.processorUsed == .vision || result.processorUsed == .tesseract)
        } catch {
            // Timeout is expected with such a short timeout
            XCTAssertTrue(error is FallbackTimeoutError || error.localizedDescription.contains("timeout"))
        }
    }
    
    // MARK: - Preprocessing Tests
    
    func testPreprocessingSelection() throws {
        let testImage = try createHighQualityTestImage("Preprocessing Test")
        
        let preprocessedImage = fallbackProcessor.preprocessImage(testImage)
        
        XCTAssertNotNil(preprocessedImage)
        XCTAssertEqual(preprocessedImage.width, testImage.width)
        XCTAssertEqual(preprocessedImage.height, testImage.height)
    }
    
    // MARK: - Integration Tests
    
    func testSeamlessFallbackBehavior() async throws {
        // Test that fallback is seamless from user perspective
        let testImages = try [
            createHighQualityTestImage("High Quality"),
            createMediumQualityTestImage("Medium Quality"),
            createLowQualityTestImage("Low Quality")
        ]
        
        for (index, image) in testImages.enumerated() {
            let result = try await fallbackProcessor.extractTextWithDetails(from: image)
            
            XCTAssertFalse(result.ocrResults.isEmpty, "Should extract text from image \(index)")
            XCTAssertGreaterThan(result.processingTime, 0, "Should have positive processing time")
            XCTAssertGreaterThan(result.attempts, 0, "Should have at least one attempt")
        }
    }
    
    func testBatchProcessingWithFallback() async throws {
        // Test that batch processing works with fallback system
        let batchProcessor = try BatchOCRProcessor()
        
        let frames = try (0..<3).map { index in
            let image = try createMediumQualityTestImage("Batch \(index)")
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
    
    // MARK: - Helper Methods
    
    private func createHighQualityTestImage(_ text: String) throws -> CGImage {
        return try createTestImageWithText(text, fontSize: 24, quality: .high)
    }
    
    private func createMediumQualityTestImage(_ text: String) throws -> CGImage {
        return try createTestImageWithText(text, fontSize: 16, quality: .medium)
    }
    
    private func createLowQualityTestImage(_ text: String) throws -> CGImage {
        return try createTestImageWithText(text, fontSize: 12, quality: .low)
    }
    
    private func createCorruptedTestImage() throws -> CGImage {
        // Create a minimal image that might be challenging
        let size = CGSize(width: 10, height: 10)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.imageCreationFailed
        }
        
        // Fill with random colors
        for x in 0..<Int(size.width) {
            for y in 0..<Int(size.height) {
                let color = CGColor(red: CGFloat.random(in: 0...1),
                                  green: CGFloat.random(in: 0...1),
                                  blue: CGFloat.random(in: 0...1),
                                  alpha: 1.0)
                context.setFillColor(color)
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        
        guard let cgImage = context.makeImage() else {
            throw TestError.imageCreationFailed
        }
        
        return cgImage
    }
    
    private enum ImageQuality {
        case high, medium, low
    }
    
    private func createTestImageWithText(_ text: String, fontSize: CGFloat, quality: ImageQuality) throws -> CGImage {
        let size = CGSize(width: 400, height: 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.imageCreationFailed
        }
        
        // Fill with white background
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw text with quality-dependent characteristics
        let textColor: CGColor
        let font: NSFont
        
        switch quality {
        case .high:
            textColor = CGColor.black
            font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        case .medium:
            textColor = CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        case .low:
            textColor = CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            font = NSFont.systemFont(ofSize: fontSize, weight: .light)
        }
        
        context.setFillColor(textColor)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: textColor) ?? NSColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        context.textPosition = CGPoint(x: 20, y: 40)
        CTLineDraw(line, context)
        
        // Add quality-dependent noise
        if quality == .low {
            // Add some noise for low quality
            context.setFillColor(CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.3))
            for _ in 0..<20 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                context.fillEllipse(in: CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        
        guard let cgImage = context.makeImage() else {
            throw TestError.imageCreationFailed
        }
        
        return cgImage
    }
    
    enum TestError: Error {
        case imageCreationFailed
    }
}

// Mock error for timeout testing
private struct FallbackTimeoutError: Error {
    let message = "Fallback operation timed out"
}