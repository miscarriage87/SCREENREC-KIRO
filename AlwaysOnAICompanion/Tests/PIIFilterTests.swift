import XCTest
@testable import Shared

class PIIFilterTests: XCTestCase {
    var filter: PIIFilter!
    var auditor: PrivacyAuditor!
    
    override func setUp() {
        super.setUp()
        // Use in-memory database for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_audit.db")
        auditor = PrivacyAuditor(databasePath: tempURL)
        filter = PIIFilter(auditor: auditor)
    }
    
    override func tearDown() {
        filter = nil
        auditor = nil
        super.tearDown()
    }
    
    // MARK: - Basic Filtering Tests
    
    func testCleanTextFiltering() {
        let cleanText = "This is a clean document with no PII."
        let result = filter.filterOCRText(cleanText)
        
        XCTAssertEqual(result.originalText, cleanText)
        XCTAssertEqual(result.filteredText, cleanText)
        XCTAssertFalse(result.containedPII)
        XCTAssertTrue(result.detectedTypes.isEmpty)
        XCTAssertTrue(result.blockedTypes.isEmpty)
        XCTAssertFalse(result.maskingApplied)
        XCTAssertTrue(result.shouldStore)
    }
    
    func testPIITextFiltering() {
        let piiText = "Contact me at john.doe@company.com"
        let result = filter.filterOCRText(piiText)
        
        XCTAssertEqual(result.originalText, piiText)
        XCTAssertNotEqual(result.filteredText, piiText)
        XCTAssertTrue(result.containedPII)
        XCTAssertTrue(result.detectedTypes.contains(.email))
        XCTAssertTrue(result.maskingApplied)
    }
    
    func testMultiplePIIFiltering() {
        let text = """
        Employee Info:
        Email: john@company.com
        Phone: (555) 123-4567
        SSN: 123-45-6789
        """
        
        let result = filter.filterOCRText(text)
        
        XCTAssertTrue(result.containedPII)
        XCTAssertTrue(result.detectedTypes.contains(.email))
        XCTAssertTrue(result.detectedTypes.contains(.phone))
        XCTAssertTrue(result.detectedTypes.contains(.ssn))
        XCTAssertEqual(result.detectedTypes.count, 3)
    }
    
    // MARK: - Configuration-Based Filtering Tests
    
    func testAllowedPIITypes() {
        let config = PIIFilterConfig(
            allowedPIITypes: [.email],
            preventPIIStorage: true
        )
        let customFilter = PIIFilter(config: config, auditor: auditor)
        
        let text = "Email: test@example.com and SSN: 123-45-6789"
        let result = customFilter.filterOCRText(text)
        
        XCTAssertTrue(result.containedPII)
        XCTAssertTrue(result.detectedTypes.contains(.email))
        XCTAssertTrue(result.detectedTypes.contains(.ssn))
        XCTAssertTrue(result.blockedTypes.contains(.ssn))
        XCTAssertFalse(result.blockedTypes.contains(.email))
    }
    
    func testPreventPIIStorage() {
        let config = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: []
        )
        let customFilter = PIIFilter(config: config, auditor: auditor)
        
        let text = "SSN: 123-45-6789"
        let result = customFilter.filterOCRText(text)
        
        XCTAssertTrue(result.containedPII)
        XCTAssertFalse(result.shouldStore)
        XCTAssertTrue(result.filteredText.contains("BLOCKED"))
    }
    
    func testDisabledFiltering() {
        let config = PIIFilterConfig(enableRealTimeFiltering: false)
        let customFilter = PIIFilter(config: config, auditor: auditor)
        
        let text = "Email: test@example.com"
        let result = customFilter.filterOCRText(text)
        
        XCTAssertEqual(result.originalText, result.filteredText)
        XCTAssertFalse(result.containedPII)
        XCTAssertTrue(result.shouldStore)
        XCTAssertFalse(result.maskingApplied)
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchOCRFiltering() {
        let ocrResults = [
            OCRResult(text: "Clean text", boundingBox: CGRect.zero, confidence: 0.9, language: "en"),
            OCRResult(text: "Email: test@example.com", boundingBox: CGRect.zero, confidence: 0.8, language: "en"),
            OCRResult(text: "Phone: 555-1234", boundingBox: CGRect.zero, confidence: 0.7, language: "en")
        ]
        
        let results = filter.filterOCRResults(ocrResults)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertFalse(results[0].containedPII)
        XCTAssertTrue(results[1].containedPII)
        XCTAssertTrue(results[2].containedPII)
    }
    
    // MARK: - Storage Decision Tests
    
    func testShouldBlockStorage() {
        let config = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: [.email]
        )
        let customFilter = PIIFilter(config: config, auditor: auditor)
        
        let allowedText = "Email: test@example.com"
        let blockedText = "SSN: 123-45-6789"
        let mixedText = "Email: test@example.com, SSN: 123-45-6789"
        
        XCTAssertFalse(customFilter.shouldBlockStorage(for: allowedText))
        XCTAssertTrue(customFilter.shouldBlockStorage(for: blockedText))
        XCTAssertTrue(customFilter.shouldBlockStorage(for: mixedText))
    }
    
    // MARK: - PII Analysis Tests
    
    func testPIIAnalysis() {
        let text = """
        Contact Information:
        Email: john@company.com (high confidence)
        Phone: maybe-555-1234 (lower confidence)
        SSN: 123-45-6789 (high confidence)
        """
        
        let analysis = filter.analyzePII(in: text)
        
        XCTAssertTrue(analysis.containsPII)
        XCTAssertGreaterThan(analysis.totalMatches, 0)
        XCTAssertGreaterThan(analysis.highConfidenceMatches, 0)
        XCTAssertGreaterThan(analysis.averageConfidence, 0)
        XCTAssertFalse(analysis.matches.isEmpty)
    }
    
    // MARK: - Audit Integration Tests
    
    func testAuditLogging() {
        let text = "Email: test@example.com"
        _ = filter.filterOCRText(text, source: "TestOCR")
        
        // Give some time for async logging
        let expectation = XCTestExpectation(description: "Audit logging")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let recentEvents = auditor.getRecentEvents(limit: 10)
        XCTAssertGreaterThan(recentEvents.count, 0)
        
        let piiEvents = recentEvents.filter { $0.eventType == .piiDetected || $0.eventType == .piiMasked }
        XCTAssertGreaterThan(piiEvents.count, 0)
    }
    
    func testConfigurationChangeLogging() {
        let newConfig = PIIFilterConfig(
            enableRealTimeFiltering: false,
            preventPIIStorage: false
        )
        
        filter.updateConfig(newConfig)
        
        // Give some time for async logging
        let expectation = XCTestExpectation(description: "Config change logging")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let configEvents = auditor.getEvents(ofType: .configChanged, limit: 5)
        XCTAssertGreaterThan(configEvents.count, 0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTextFiltering() {
        let result = filter.filterOCRText("")
        
        XCTAssertEqual(result.originalText, "")
        XCTAssertEqual(result.filteredText, "")
        XCTAssertFalse(result.containedPII)
        XCTAssertTrue(result.shouldStore)
    }
    
    func testVeryLongTextFiltering() {
        let longText = String(repeating: "This is safe text. ", count: 1000) + "Email: test@example.com"
        let result = filter.filterOCRText(longText)
        
        XCTAssertTrue(result.containedPII)
        XCTAssertTrue(result.detectedTypes.contains(.email))
        XCTAssertNotEqual(result.originalText, result.filteredText)
    }
    
    func testSpecialCharactersInPII() {
        let text = "Email with special chars: test+tag@domain-name.co.uk"
        let result = filter.filterOCRText(text)
        
        XCTAssertTrue(result.containedPII)
        XCTAssertTrue(result.detectedTypes.contains(.email))
    }
    
    // MARK: - Performance Tests
    
    func testFilteringPerformance() {
        let text = """
        Performance test document with multiple PII:
        Email: user@domain.com
        Phone: (555) 123-4567
        SSN: 123-45-6789
        IP: 192.168.1.1
        Card: 4111111111111111
        """
        
        measure {
            for _ in 0..<100 {
                _ = filter.filterOCRText(text)
            }
        }
    }
    
    func testBatchFilteringPerformance() {
        let ocrResults = (0..<100).map { i in
            OCRResult(
                text: "Text \(i) with email: user\(i)@domain.com",
                boundingBox: CGRect.zero,
                confidence: 0.8,
                language: "en"
            )
        }
        
        measure {
            _ = filter.filterOCRResults(ocrResults)
        }
    }
    
    // MARK: - Integration Scenarios
    
    func testRealWorldScenario() {
        // Simulate a real OCR result from a form
        let formText = """
        APPLICATION FORM
        
        Full Name: John Smith
        Email Address: john.smith@company.com
        Phone Number: (555) 123-4567
        Social Security: 123-45-6789
        
        Emergency Contact:
        Name: Jane Smith
        Phone: (555) 987-6543
        
        I certify that the information above is correct.
        Signature: [Signed]
        Date: 03/15/2024
        """
        
        let result = filter.filterOCRText(formText, source: "FormOCR")
        
        XCTAssertTrue(result.containedPII)
        XCTAssertGreaterThan(result.detectedTypes.count, 2)
        XCTAssertTrue(result.maskingApplied)
        
        // Should preserve form structure while masking PII
        XCTAssertTrue(result.filteredText.contains("APPLICATION FORM"))
        XCTAssertTrue(result.filteredText.contains("Emergency Contact"))
        XCTAssertTrue(result.filteredText.contains("Date: 03/15/2024"))
        
        // Should not contain original PII
        XCTAssertFalse(result.filteredText.contains("john.smith@company.com"))
        XCTAssertFalse(result.filteredText.contains("123-45-6789"))
    }
    
    func testMedicalRecordScenario() {
        let medicalText = """
        PATIENT RECORD
        
        Patient: Mary Johnson
        DOB: 05/12/1985
        SSN: 987-65-4321
        Phone: (555) 444-3333
        Email: mary.j@email.com
        
        Insurance: Policy #ABC123456
        
        Diagnosis: Routine checkup
        Notes: Patient reports feeling well
        """
        
        let config = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: []  // No PII allowed in medical records
        )
        let medicalFilter = PIIFilter(config: config, auditor: auditor)
        
        let result = medicalFilter.filterOCRText(medicalText, source: "MedicalOCR")
        
        XCTAssertTrue(result.containedPII)
        XCTAssertFalse(result.shouldStore)  // Should be blocked due to PII
        XCTAssertTrue(result.filteredText.contains("BLOCKED"))
    }
}