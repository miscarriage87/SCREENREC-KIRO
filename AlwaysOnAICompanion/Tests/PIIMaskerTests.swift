import XCTest
@testable import Shared

class PIIMaskerTests: XCTestCase {
    var masker: PIIMasker!
    var detector: PIIDetector!
    
    override func setUp() {
        super.setUp()
        detector = PIIDetector()
        masker = PIIMasker(detector: detector)
    }
    
    override func tearDown() {
        masker = nil
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Basic Masking Tests
    
    func testEmailMasking() {
        let text = "Contact me at john.doe@company.com for details"
        let result = masker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedCount > 0)
        XCTAssertTrue(result.maskingMap[.email] ?? 0 > 0)
        XCTAssertFalse(result.maskedText.contains("john.doe@company.com"))
        XCTAssertTrue(result.maskedText.contains("@"))  // Partial masking should preserve @
    }
    
    func testPhoneMasking() {
        let text = "Call me at (555) 123-4567"
        let result = masker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedCount > 0)
        XCTAssertTrue(result.maskingMap[.phone] ?? 0 > 0)
        XCTAssertFalse(result.maskedText.contains("(555) 123-4567"))
        // Should preserve last 4 digits in partial masking
        XCTAssertTrue(result.maskedText.contains("4567"))
    }
    
    func testSSNMasking() {
        let text = "SSN: 123-45-6789"
        let result = masker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedCount > 0)
        XCTAssertTrue(result.maskingMap[.ssn] ?? 0 > 0)
        XCTAssertFalse(result.maskedText.contains("123-45-6789"))
        XCTAssertTrue(result.maskedText.contains("[REDACTED]"))
    }
    
    func testCreditCardMasking() {
        let text = "Card number: 4111111111111111"
        let result = masker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedCount > 0)
        XCTAssertTrue(result.maskingMap[.creditCard] ?? 0 > 0)
        XCTAssertFalse(result.maskedText.contains("4111111111111111"))
        // Should preserve last 4 digits
        XCTAssertTrue(result.maskedText.contains("1111"))
    }
    
    // MARK: - Masking Strategy Tests
    
    func testRedactStrategy() {
        let config = PIIMaskingConfig(strategies: [.email: .redact])
        let customMasker = PIIMasker(config: config, detector: detector)
        
        let text = "Email: test@example.com"
        let result = customMasker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedText.contains("[REDACTED]"))
        XCTAssertFalse(result.maskedText.contains("test@example.com"))
    }
    
    func testAsteriskStrategy() {
        let config = PIIMaskingConfig(strategies: [.ipAddress: .asterisk])
        let customMasker = PIIMasker(config: config, detector: detector)
        
        let text = "Server: 192.168.1.1"
        let result = customMasker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedText.contains("*"))
        XCTAssertFalse(result.maskedText.contains("192.168.1.1"))
    }
    
    func testHashStrategy() {
        let config = PIIMaskingConfig(strategies: [.email: .hash])
        let customMasker = PIIMasker(config: config, detector: detector)
        
        let text = "Email: test@example.com"
        let result = customMasker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedText.contains("[HASH:"))
        XCTAssertFalse(result.maskedText.contains("test@example.com"))
    }
    
    func testPlaceholderStrategy() {
        let config = PIIMaskingConfig(strategies: [.phone: .placeholder])
        let customMasker = PIIMasker(config: config, detector: detector)
        
        let text = "Phone: 555-123-4567"
        let result = customMasker.maskPII(in: text)
        
        XCTAssertTrue(result.maskedText.contains("[PHONE]"))
        XCTAssertFalse(result.maskedText.contains("555-123-4567"))
    }
    
    func testRemoveStrategy() {
        let config = PIIMaskingConfig(strategies: [.email: .remove])
        let customMasker = PIIMasker(config: config, detector: detector)
        
        let text = "Contact test@example.com for info"
        let result = customMasker.maskPII(in: text)
        
        XCTAssertEqual(result.maskedText, "Contact  for info")
        XCTAssertFalse(result.maskedText.contains("test@example.com"))
    }
    
    // MARK: - Multiple PII Masking Tests
    
    func testMultiplePIIMasking() {
        let text = """
        Contact Information:
        Email: john.doe@company.com
        Phone: (555) 123-4567
        SSN: 123-45-6789
        """
        
        let result = masker.maskPII(in: text)
        
        XCTAssertEqual(result.maskedCount, 3)
        XCTAssertEqual(result.maskingMap[.email], 1)
        XCTAssertEqual(result.maskingMap[.phone], 1)
        XCTAssertEqual(result.maskingMap[.ssn], 1)
        
        XCTAssertFalse(result.maskedText.contains("john.doe@company.com"))
        XCTAssertFalse(result.maskedText.contains("(555) 123-4567"))
        XCTAssertFalse(result.maskedText.contains("123-45-6789"))
    }
    
    func testOverlappingPIIMasking() {
        // Test case where PII might overlap or be adjacent
        let text = "Email:test@domain.com,Phone:555-1234"
        let result = masker.maskPII(in: text)
        
        XCTAssertGreaterThan(result.maskedCount, 0)
        XCTAssertFalse(result.maskedText.contains("test@domain.com"))
        XCTAssertFalse(result.maskedText.contains("555-1234"))
    }
    
    // MARK: - Configuration Tests
    
    func testPreserveLengthConfiguration() {
        let preserveConfig = PIIMaskingConfig(preserveLength: true)
        let noPreserveConfig = PIIMaskingConfig(preserveLength: false)
        
        let preserveMasker = PIIMasker(config: preserveConfig, detector: detector)
        let noPreserveMasker = PIIMasker(config: noPreserveConfig, detector: detector)
        
        let text = "IP: 192.168.1.1"
        
        let preserveResult = preserveMasker.maskPII(in: text)
        let noPreserveResult = noPreserveMasker.maskPII(in: text)
        
        // Length preservation might affect the masking output
        XCTAssertNotEqual(preserveResult.maskedText, noPreserveResult.maskedText)
    }
    
    func testPartialMaskingRatio() {
        let config = PIIMaskingConfig(
            strategies: [.email: .partial],
            partialMaskingRatio: 0.8
        )
        let customMasker = PIIMasker(config: config, detector: detector)
        
        let text = "Email: verylongemailaddress@domain.com"
        let result = customMasker.maskPII(in: text)
        
        // Should have more masking with higher ratio
        let asteriskCount = result.maskedText.filter { $0 == "*" }.count
        XCTAssertGreaterThan(asteriskCount, 0)
    }
    
    // MARK: - Edge Cases
    
    func testNoMaskingNeeded() {
        let text = "This text contains no PII at all."
        let result = masker.maskPII(in: text)
        
        XCTAssertEqual(result.maskedCount, 0)
        XCTAssertTrue(result.maskingMap.isEmpty)
        XCTAssertEqual(result.maskedText, text)
    }
    
    func testEmptyText() {
        let result = masker.maskPII(in: "")
        
        XCTAssertEqual(result.maskedCount, 0)
        XCTAssertTrue(result.maskingMap.isEmpty)
        XCTAssertEqual(result.maskedText, "")
    }
    
    func testWhitespaceOnlyText() {
        let text = "   \n\t  "
        let result = masker.maskPII(in: text)
        
        XCTAssertEqual(result.maskedCount, 0)
        XCTAssertEqual(result.maskedText, text)
    }
    
    // MARK: - Masking Preview Tests
    
    func testMaskingPreview() {
        let text = "Email: test@example.com, Phone: 555-1234"
        let preview = masker.previewMasking(for: text)
        
        XCTAssertGreaterThan(preview.count, 0)
        
        for (match, maskedValue) in preview {
            XCTAssertNotEqual(match.text, maskedValue)
            XCTAssertFalse(maskedValue.isEmpty)
        }
    }
    
    // MARK: - Consistency Tests
    
    func testMaskingConsistency() {
        let text = "Same email: test@example.com appears twice: test@example.com"
        
        let config = PIIMaskingConfig(strategies: [.email: .hash])
        let customMasker = PIIMasker(config: config, detector: detector)
        
        let result1 = customMasker.maskPII(in: text)
        let result2 = customMasker.maskPII(in: text)
        
        // Hash strategy should produce consistent results
        XCTAssertEqual(result1.maskedText, result2.maskedText)
    }
    
    // MARK: - Performance Tests
    
    func testMaskingPerformance() {
        let text = """
        Large document with multiple PII instances:
        Emails: user1@domain.com, user2@company.org, admin@test.net
        Phones: (555) 123-4567, 555-987-6543, +1-555-111-2222
        SSNs: 123-45-6789, 987-65-4321
        Cards: 4111111111111111, 5555555555554444
        """
        
        measure {
            for _ in 0..<50 {
                _ = masker.maskPII(in: text)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testNeedsMaskingCheck() {
        let piiText = "Email: test@example.com"
        let cleanText = "No PII here"
        
        XCTAssertTrue(masker.needsMasking(piiText))
        XCTAssertFalse(masker.needsMasking(cleanText))
    }
    
    func testComplexDocumentMasking() {
        let document = """
        CONFIDENTIAL EMPLOYEE RECORD
        
        Name: John Smith
        Email: john.smith@company.com
        Phone: (555) 123-4567
        SSN: 123-45-6789
        
        Emergency Contact:
        Name: Jane Smith
        Phone: (555) 987-6543
        Email: jane.smith@email.com
        
        Banking Information:
        Account: 1234567890
        Routing: 987654321
        Card: 4111111111111111
        
        Notes: Employee started on 01/15/2023
        """
        
        let result = masker.maskPII(in: document)
        
        XCTAssertGreaterThan(result.maskedCount, 5)
        XCTAssertFalse(result.maskedText.contains("john.smith@company.com"))
        XCTAssertFalse(result.maskedText.contains("123-45-6789"))
        XCTAssertFalse(result.maskedText.contains("4111111111111111"))
        
        // Should preserve document structure
        XCTAssertTrue(result.maskedText.contains("CONFIDENTIAL"))
        XCTAssertTrue(result.maskedText.contains("Emergency Contact"))
        XCTAssertTrue(result.maskedText.contains("Banking Information"))
    }
}