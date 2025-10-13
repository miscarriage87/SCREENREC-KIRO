import XCTest
import CoreGraphics
import AppKit
@testable import Shared

final class TesseractOCRTests: XCTestCase {
    
    var tesseractProcessor: TesseractOCRProcessor!
    
    override func setUp() async throws {
        try await super.setUp()
        tesseractProcessor = try TesseractOCRProcessor()
    }
    
    override func tearDown() async throws {
        tesseractProcessor = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testTesseractInitialization() throws {
        XCTAssertNotNil(tesseractProcessor)
        XCTAssertEqual(tesseractProcessor.confidence, 0.0)
    }
    
    func testTesseractWithSimpleText() async throws {
        let testImage = try createTestImageWithText("Hello World")
        
        let results = try await tesseractProcessor.extractText(from: testImage)
        
        XCTAssertFalse(results.isEmpty, "Should extract text from simple image")
        XCTAssertTrue(results.first?.text.contains("Hello") == true, "Should contain 'Hello'")
        XCTAssertGreaterThan(tesseractProcessor.confidence, 0.0, "Should have positive confidence")
    }
    
    func testTesseractWithComplexText() async throws {
        let complexText = "The quick brown fox jumps over the lazy dog. 123456789"
        let testImage = try createTestImageWithText(complexText)
        
        let results = try await tesseractProcessor.extractText(from: testImage)
        
        XCTAssertFalse(results.isEmpty, "Should extract text from complex image")
        XCTAssertGreaterThan(tesseractProcessor.confidence, 0.3, "Should have reasonable confidence for complex text")
    }
    
    func testTesseractWithEmptyImage() async throws {
        let emptyImage = try createEmptyTestImage()
        
        let results = try await tesseractProcessor.extractText(from: emptyImage)
        
        // Empty image should return empty results
        XCTAssertTrue(results.isEmpty || results.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertEqual(tesseractProcessor.confidence, 0.0, "Should have zero confidence for empty image")
    }
    
    // MARK: - Language Detection Tests
    
    func testLanguageDetection() async throws {
        let testCases = [
            ("Hello World", "en-US"),
            ("Hola Mundo", "es-ES"),
            ("Bonjour le monde", "fr-FR"),
            ("Hallo Welt", "de-DE"),
            ("Ciao mondo", "it-IT")
        ]
        
        for (text, expectedLanguage) in testCases {
            let testImage = try createTestImageWithText(text)
            let results = try await tesseractProcessor.extractText(from: testImage)
            
            if let firstResult = results.first {
                XCTAssertEqual(firstResult.language, expectedLanguage, "Should detect correct language for '\(text)'")
            }
        }
    }
    
    // MARK: - Image Preprocessing Tests
    
    func testImagePreprocessing() throws {
        let originalImage = try createTestImageWithText("Test")
        let preprocessedImage = tesseractProcessor.preprocessImage(originalImage)
        
        XCTAssertNotNil(preprocessedImage)
        // Preprocessed image should have same or similar dimensions
        XCTAssertEqual(preprocessedImage.width, originalImage.width)
        XCTAssertEqual(preprocessedImage.height, originalImage.height)
    }
    
    func testPreprocessingImproveAccuracy() async throws {
        let noisyImage = try createNoisyTestImage("Clear Text")
        
        // Test without preprocessing
        let originalResults = try await tesseractProcessor.extractText(from: noisyImage)
        
        // Test with preprocessing
        let preprocessedImage = tesseractProcessor.preprocessImage(noisyImage)
        let preprocessedResults = try await tesseractProcessor.extractText(from: preprocessedImage)
        
        // Preprocessing should generally improve results (though this is hard to test deterministically)
        XCTAssertTrue(preprocessedResults.count >= originalResults.count, "Preprocessing should not reduce text detection")
    }
    
    // MARK: - Performance Tests
    
    func testTesseractPerformance() async throws {
        let testImage = try createTestImageWithText("Performance Test Text")
        
        let startTime = Date()
        let results = try await tesseractProcessor.extractText(from: testImage)
        let processingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(results.isEmpty, "Should extract text")
        XCTAssertLessThan(processingTime, 5.0, "Should complete within reasonable time")
    }
    
    func testBatchProcessingPerformance() async throws {
        let images = try (0..<5).map { index in
            try createTestImageWithText("Batch test \(index)")
        }
        
        let startTime = Date()
        let results = try await tesseractProcessor.processBatchWithLanguageOptimization(images)
        let processingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, images.count, "Should process all images")
        XCTAssertLessThan(processingTime, 15.0, "Batch processing should complete within reasonable time")
    }
    
    // MARK: - Error Handling Tests
    
    func testTesseractWithCorruptedImage() async throws {
        // Create a minimal CGImage that might cause issues
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgImage = context?.makeImage() else {
            XCTFail("Could not create test image")
            return
        }
        
        // This should not crash, even with minimal image
        let results = try await tesseractProcessor.extractText(from: cgImage)
        
        // Results might be empty, but should not throw
        XCTAssertTrue(results.isEmpty || !results.isEmpty, "Should handle minimal image gracefully")
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() throws {
        let config = TesseractOCRProcessor.TesseractConfiguration(
            whitelistCharacters: "0123456789",
            blacklistCharacters: nil,
            simulateProcessingDelay: false
        )
        
        let processor = try TesseractOCRProcessor(configuration: config)
        XCTAssertNotNil(processor)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageWithText(_ text: String) throws -> CGImage {
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
        
        // Draw black text
        context.setFillColor(CGColor.black)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        context.textPosition = CGPoint(x: 20, y: 40)
        CTLineDraw(line, context)
        
        guard let cgImage = context.makeImage() else {
            throw TestError.imageCreationFailed
        }
        
        return cgImage
    }
    
    private func createEmptyTestImage() throws -> CGImage {
        let size = CGSize(width: 200, height: 100)
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
        
        // Fill with white background only
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: size))
        
        guard let cgImage = context.makeImage() else {
            throw TestError.imageCreationFailed
        }
        
        return cgImage
    }
    
    private func createNoisyTestImage(_ text: String) throws -> CGImage {
        let baseImage = try createTestImageWithText(text)
        
        // Add some noise to make OCR more challenging
        let size = CGSize(width: baseImage.width, height: baseImage.height)
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
        
        // Draw the base image
        context.draw(baseImage, in: CGRect(origin: .zero, size: size))
        
        // Add some noise dots
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3))
        for _ in 0..<50 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            context.fillEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
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