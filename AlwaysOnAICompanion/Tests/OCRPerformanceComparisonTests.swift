import XCTest
import CoreGraphics
import AppKit
@testable import Shared

final class OCRPerformanceComparisonTests: XCTestCase {
    
    var visionProcessor: VisionOCRProcessor!
    var tesseractProcessor: TesseractOCRProcessor!
    var fallbackProcessor: FallbackOCRProcessor!
    
    override func setUp() async throws {
        try await super.setUp()
        visionProcessor = VisionOCRProcessor()
        tesseractProcessor = try TesseractOCRProcessor()
        fallbackProcessor = try FallbackOCRProcessor()
    }
    
    override func tearDown() async throws {
        visionProcessor = nil
        tesseractProcessor = nil
        fallbackProcessor = nil
        try await super.tearDown()
    }
    
    // MARK: - Performance Comparison Tests
    
    func testProcessingSpeedComparison() async throws {
        let testImage = try createStandardTestImage("Performance comparison test with multiple lines of text")
        
        // Measure Vision processing time
        let visionStartTime = Date()
        let visionResults = try await visionProcessor.extractText(from: testImage)
        let visionTime = Date().timeIntervalSince(visionStartTime)
        
        // Measure Tesseract processing time
        let tesseractStartTime = Date()
        let tesseractResults = try await tesseractProcessor.extractText(from: testImage)
        let tesseractTime = Date().timeIntervalSince(tesseractStartTime)
        
        // Measure Fallback processing time
        let fallbackStartTime = Date()
        let fallbackResults = try await fallbackProcessor.extractText(from: testImage)
        let fallbackTime = Date().timeIntervalSince(fallbackStartTime)
        
        print("Performance Comparison:")
        print("Vision: \(visionTime)s, Results: \(visionResults.count)")
        print("Tesseract: \(tesseractTime)s, Results: \(tesseractResults.count)")
        print("Fallback: \(fallbackTime)s, Results: \(fallbackResults.count)")
        
        // Vision should generally be faster
        XCTAssertLessThan(visionTime, 5.0, "Vision should complete within 5 seconds")
        XCTAssertLessThan(tesseractTime, 10.0, "Tesseract should complete within 10 seconds")
        XCTAssertLessThan(fallbackTime, 10.0, "Fallback should complete within 10 seconds")
        
        // All should produce some results
        XCTAssertFalse(visionResults.isEmpty, "Vision should extract text")
        XCTAssertFalse(tesseractResults.isEmpty, "Tesseract should extract text")
        XCTAssertFalse(fallbackResults.isEmpty, "Fallback should extract text")
    }
    
    func testAccuracyComparison() async throws {
        let testCases = [
            "Simple text",
            "Text with numbers 123456",
            "Mixed Case Text",
            "Special characters: @#$%",
            "Multi-line\ntext content"
        ]
        
        for testText in testCases {
            let testImage = try createStandardTestImage(testText)
            
            let visionResults = try await visionProcessor.extractText(from: testImage)
            let tesseractResults = try await tesseractProcessor.extractText(from: testImage)
            
            let visionText = visionResults.map { $0.text }.joined(separator: " ")
            let tesseractText = tesseractResults.map { $0.text }.joined(separator: " ")
            
            let visionAccuracy = calculateTextSimilarity(original: testText, extracted: visionText)
            let tesseractAccuracy = calculateTextSimilarity(original: testText, extracted: tesseractText)
            
            print("Text: '\(testText)'")
            print("Vision accuracy: \(visionAccuracy), Tesseract accuracy: \(tesseractAccuracy)")
            
            // Both should have reasonable accuracy
            XCTAssertGreaterThan(visionAccuracy, 0.5, "Vision should have reasonable accuracy for '\(testText)'")
            XCTAssertGreaterThan(tesseractAccuracy, 0.3, "Tesseract should have reasonable accuracy for '\(testText)'")
        }
    }
    
    func testConfidenceScoreComparison() async throws {
        let testImage = try createStandardTestImage("Confidence test text")
        
        let visionResults = try await visionProcessor.extractText(from: testImage)
        let tesseractResults = try await tesseractProcessor.extractText(from: testImage)
        
        let visionConfidence = visionProcessor.confidence
        let tesseractConfidence = tesseractProcessor.confidence
        
        print("Confidence Comparison:")
        print("Vision: \(visionConfidence)")
        print("Tesseract: \(tesseractConfidence)")
        
        // Both should provide confidence scores
        XCTAssertGreaterThan(visionConfidence, 0.0, "Vision should provide confidence score")
        XCTAssertGreaterThan(tesseractConfidence, 0.0, "Tesseract should provide confidence score")
        XCTAssertLessThanOrEqual(visionConfidence, 1.0, "Vision confidence should not exceed 1.0")
        XCTAssertLessThanOrEqual(tesseractConfidence, 1.0, "Tesseract confidence should not exceed 1.0")
    }
    
    // MARK: - Batch Processing Performance Tests
    
    func testBatchProcessingPerformance() async throws {
        let batchSize = 5
        let testImages = try (0..<batchSize).map { index in
            try createStandardTestImage("Batch test image \(index)")
        }
        
        // Test Vision batch processing
        let visionStartTime = Date()
        let visionBatchResults = try await visionProcessor.processBatch(testImages)
        let visionBatchTime = Date().timeIntervalSince(visionStartTime)
        
        // Test Tesseract batch processing
        let tesseractStartTime = Date()
        let tesseractBatchResults = try await tesseractProcessor.processBatchWithLanguageOptimization(testImages)
        let tesseractBatchTime = Date().timeIntervalSince(tesseractStartTime)
        
        print("Batch Processing Performance:")
        print("Vision: \(visionBatchTime)s for \(batchSize) images")
        print("Tesseract: \(tesseractBatchTime)s for \(batchSize) images")
        
        XCTAssertEqual(visionBatchResults.count, batchSize, "Vision should process all images")
        XCTAssertEqual(tesseractBatchResults.count, batchSize, "Tesseract should process all images")
        
        // Batch processing should be reasonably efficient
        XCTAssertLessThan(visionBatchTime, 15.0, "Vision batch processing should complete within 15 seconds")
        XCTAssertLessThan(tesseractBatchTime, 30.0, "Tesseract batch processing should complete within 30 seconds")
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsage() async throws {
        let initialMemory = getMemoryUsage()
        
        // Process multiple images to test memory usage
        for i in 0..<10 {
            let testImage = try createStandardTestImage("Memory test \(i)")
            
            _ = try await visionProcessor.extractText(from: testImage)
            _ = try await tesseractProcessor.extractText(from: testImage)
            _ = try await fallbackProcessor.extractText(from: testImage)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("Memory usage increase: \(memoryIncrease) MB")
        
        // Memory increase should be reasonable (less than 100MB for this test)
        XCTAssertLessThan(memoryIncrease, 100.0, "Memory usage should not increase excessively")
    }
    
    // MARK: - Fallback Performance Tests
    
    func testFallbackOverhead() async throws {
        let testImage = try createStandardTestImage("Fallback overhead test")
        
        // Measure direct Vision processing
        let visionStartTime = Date()
        _ = try await visionProcessor.extractText(from: testImage)
        let visionTime = Date().timeIntervalSince(visionStartTime)
        
        // Measure fallback processing (should use Vision primarily)
        let fallbackStartTime = Date()
        let fallbackResult = try await fallbackProcessor.extractTextWithDetails(from: testImage)
        let fallbackTime = Date().timeIntervalSince(fallbackStartTime)
        
        print("Fallback Overhead:")
        print("Direct Vision: \(visionTime)s")
        print("Fallback (used \(fallbackResult.processorUsed)): \(fallbackTime)s")
        
        // Fallback overhead should be minimal when using Vision
        if fallbackResult.processorUsed == .vision {
            let overhead = fallbackTime - visionTime
            XCTAssertLessThan(overhead, 0.5, "Fallback overhead should be minimal when using Vision")
        }
    }
    
    func testFallbackMetricsAccuracy() async throws {
        fallbackProcessor.resetMetrics()
        
        let testImages = try (0..<5).map { index in
            try createStandardTestImage("Metrics test \(index)")
        }
        
        var visionCount = 0
        var tesseractCount = 0
        
        for image in testImages {
            let result = try await fallbackProcessor.extractTextWithDetails(from: image)
            
            switch result.processorUsed {
            case .vision:
                visionCount += 1
            case .tesseract:
                tesseractCount += 1
            case .hybrid:
                // Count as both for this test
                visionCount += 1
                tesseractCount += 1
            }
        }
        
        let metrics = fallbackProcessor.getPerformanceMetrics()
        
        XCTAssertEqual(metrics.totalProcessed, testImages.count, "Should track correct total processed count")
        XCTAssertGreaterThanOrEqual(metrics.visionSuccessRate, 0.0, "Vision success rate should be non-negative")
        XCTAssertLessThanOrEqual(metrics.visionSuccessRate, 1.0, "Vision success rate should not exceed 1.0")
        XCTAssertGreaterThanOrEqual(metrics.averageVisionTime, 0.0, "Average Vision time should be non-negative")
    }
    
    // MARK: - Stress Tests
    
    func testHighVolumeProcessing() async throws {
        let imageCount = 20
        let testImages = try (0..<imageCount).map { index in
            try createVariedTestImage(index)
        }
        
        let startTime = Date()
        
        // Process all images with fallback processor
        var successCount = 0
        for image in testImages {
            do {
                let results = try await fallbackProcessor.extractText(from: image)
                if !results.isEmpty {
                    successCount += 1
                }
            } catch {
                print("Failed to process image: \(error)")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(imageCount)
        
        print("High Volume Processing:")
        print("Processed \(imageCount) images in \(totalTime)s")
        print("Average time per image: \(averageTime)s")
        print("Success rate: \(Double(successCount) / Double(imageCount) * 100)%")
        
        XCTAssertGreaterThan(Double(successCount) / Double(imageCount), 0.8, "Should have high success rate")
        XCTAssertLessThan(averageTime, 2.0, "Average processing time should be reasonable")
    }
    
    // MARK: - Helper Methods
    
    private func createStandardTestImage(_ text: String) throws -> CGImage {
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
            .font: NSFont.systemFont(ofSize: 20),
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
    
    private func createVariedTestImage(_ index: Int) throws -> CGImage {
        let texts = [
            "Simple text",
            "Numbers: 123456789",
            "Special chars: @#$%^&*()",
            "Mixed Case Text",
            "lowercase text",
            "UPPERCASE TEXT",
            "Multi-word sentence here",
            "Short",
            "This is a longer sentence with more words to test",
            "Punctuation! Question? Period."
        ]
        
        let text = texts[index % texts.count]
        return try createStandardTestImage(text)
    }
    
    private func calculateTextSimilarity(original: String, extracted: String) -> Double {
        let originalWords = original.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let extractedWords = extracted.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        if originalWords.isEmpty && extractedWords.isEmpty {
            return 1.0
        }
        
        if originalWords.isEmpty || extractedWords.isEmpty {
            return 0.0
        }
        
        let matchingWords = originalWords.filter { word in
            extractedWords.contains { extractedWord in
                // Allow for some OCR errors by checking if words are similar
                let similarity = stringSimilarity(word, extractedWord)
                return similarity > 0.7
            }
        }
        
        return Double(matchingWords.count) / Double(originalWords.count)
    }
    
    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        if longer.isEmpty {
            return 1.0
        }
        
        let editDistance = levenshteinDistance(str1, str2)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        if str1Count == 0 { return str2Count }
        if str2Count == 0 { return str1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count {
            matrix[i][0] = i
        }
        
        for j in 0...str2Count {
            matrix[0][j] = j
        }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }
    
    enum TestError: Error {
        case imageCreationFailed
    }
}