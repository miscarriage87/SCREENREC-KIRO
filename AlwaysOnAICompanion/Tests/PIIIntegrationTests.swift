import XCTest
@testable import Shared

class PIIIntegrationTests: XCTestCase {
    var detector: PIIDetector!
    var masker: PIIMasker!
    var filter: PIIFilter!
    var auditor: PrivacyAuditor!
    var tempDatabaseURL: URL!
    
    override func setUp() {
        super.setUp()
        tempDatabaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_pii_integration_\(UUID().uuidString).db")
        
        auditor = PrivacyAuditor(databasePath: tempDatabaseURL)
        detector = PIIDetector()
        masker = PIIMasker(detector: detector)
        filter = PIIFilter(auditor: auditor)
    }
    
    override func tearDown() {
        detector = nil
        masker = nil
        filter = nil
        auditor = nil
        try? FileManager.default.removeItem(at: tempDatabaseURL)
        super.tearDown()
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteOCRPipeline() {
        let ocrText = """
        CONFIDENTIAL EMPLOYEE RECORD
        
        Name: John Smith
        Email: john.smith@company.com
        Phone: (555) 123-4567
        SSN: 123-45-6789
        
        Banking Information:
        Account: 1234567890
        Routing: 987654321
        Card: 4111111111111111
        """
        
        // Step 1: Detect PII
        let detectedPII = detector.detectPII(in: ocrText)
        XCTAssertGreaterThan(detectedPII.count, 0)
        
        let detectedTypes = Set(detectedPII.map { $0.type })
        XCTAssertTrue(detectedTypes.contains(.email))
        XCTAssertTrue(detectedTypes.contains(.phone))
        XCTAssertTrue(detectedTypes.contains(.ssn))
        XCTAssertTrue(detectedTypes.contains(.creditCard))
        
        // Step 2: Apply masking
        let maskingResult = masker.maskPII(in: ocrText)
        XCTAssertGreaterThan(maskingResult.maskedCount, 0)
        XCTAssertNotEqual(maskingResult.maskedText, ocrText)
        
        // Verify sensitive data is masked
        XCTAssertFalse(maskingResult.maskedText.contains("john.smith@company.com"))
        XCTAssertFalse(maskingResult.maskedText.contains("123-45-6789"))
        XCTAssertFalse(maskingResult.maskedText.contains("4111111111111111"))
        
        // Step 3: Apply filtering
        let filterResult = filter.filterOCRText(ocrText, source: "IntegrationTest")
        XCTAssertTrue(filterResult.containedPII)
        XCTAssertTrue(filterResult.maskingApplied)
        
        // Step 4: Verify audit logging
        let expectation = XCTestExpectation(description: "Audit logging")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let auditEvents = auditor.getRecentEvents(limit: 10)
        XCTAssertGreaterThan(auditEvents.count, 0)
        
        let piiEvents = auditEvents.filter { 
            $0.eventType == .piiDetected || $0.eventType == .piiMasked 
        }
        XCTAssertGreaterThan(piiEvents.count, 0)
    }
    
    func testPrivacyAwareOCRProcessor() {
        // Create a mock image (in real implementation, this would be a CGImage)
        // For testing, we'll simulate the OCR results
        let mockOCRResults = [
            OCRResult(text: "Clean text with no PII", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, language: "en"),
            OCRResult(text: "Email: test@example.com", boundingBox: CGRect(x: 0, y: 25, width: 150, height: 20), confidence: 0.8, language: "en"),
            OCRResult(text: "SSN: 123-45-6789", boundingBox: CGRect(x: 0, y: 50, width: 120, height: 20), confidence: 0.85, language: "en")
        ]
        
        // Test each result through the privacy filter
        var filteredResults: [OCRResult] = []
        
        for result in mockOCRResults {
            let filterResult = filter.filterOCRText(result.text, source: "MockOCR")
            
            if filterResult.shouldStore {
                let filteredOCRResult = OCRResult(
                    text: filterResult.filteredText,
                    boundingBox: result.boundingBox,
                    confidence: result.confidence,
                    language: result.language
                )
                filteredResults.append(filteredOCRResult)
            }
        }
        
        // Should have filtered out or masked PII content
        XCTAssertLessThanOrEqual(filteredResults.count, mockOCRResults.count)
        
        // Clean text should pass through unchanged
        let cleanResult = filteredResults.first { $0.text.contains("Clean text") }
        XCTAssertNotNil(cleanResult)
        XCTAssertEqual(cleanResult?.text, "Clean text with no PII")
        
        // PII content should be masked or blocked
        let emailResult = filteredResults.first { $0.text.contains("Email") }
        if let emailResult = emailResult {
            XCTAssertFalse(emailResult.text.contains("test@example.com"))
        }
    }
    
    // MARK: - Configuration Integration Tests
    
    func testDifferentPrivacyLevels() {
        let testText = "Contact: john@company.com, Phone: 555-1234, SSN: 123-45-6789"
        
        // Test strict privacy configuration
        let strictConfig = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: []
        )
        let strictFilter = PIIFilter(config: strictConfig, auditor: auditor)
        let strictResult = strictFilter.filterOCRText(testText, source: "StrictTest")
        
        XCTAssertFalse(strictResult.shouldStore)
        XCTAssertTrue(strictResult.filteredText.contains("BLOCKED"))
        
        // Test moderate privacy configuration
        let moderateConfig = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: [.email, .phone]
        )
        let moderateFilter = PIIFilter(config: moderateConfig, auditor: auditor)
        let moderateResult = moderateFilter.filterOCRText(testText, source: "ModerateTest")
        
        XCTAssertFalse(moderateResult.shouldStore) // SSN should block storage
        XCTAssertTrue(moderateResult.detectedTypes.contains(.ssn))
        XCTAssertTrue(moderateResult.blockedTypes.contains(.ssn))
        
        // Test permissive configuration
        let permissiveConfig = PIIFilterConfig(
            preventPIIStorage: false,
            allowedPIITypes: Set(PIIType.allCases)
        )
        let permissiveFilter = PIIFilter(config: permissiveConfig, auditor: auditor)
        let permissiveResult = permissiveFilter.filterOCRText(testText, source: "PermissiveTest")
        
        XCTAssertTrue(permissiveResult.shouldStore)
        XCTAssertTrue(permissiveResult.maskingApplied)
        XCTAssertNotEqual(permissiveResult.filteredText, testText)
    }
    
    // MARK: - Performance Integration Tests
    
    func testBatchProcessingPerformance() {
        let batchSize = 100
        let testTexts = (0..<batchSize).map { i in
            "Document \(i): Email user\(i)@domain.com, Phone: 555-000\(String(format: "%04d", i))"
        }
        
        measure {
            for text in testTexts {
                _ = filter.filterOCRText(text, source: "PerformanceTest")
            }
        }
    }
    
    func testLargeDocumentProcessing() {
        // Create a large document with scattered PII
        var largeDocument = ""
        for i in 0..<1000 {
            if i % 100 == 0 {
                largeDocument += "Email: user\(i)@company.com\n"
            } else if i % 150 == 0 {
                largeDocument += "Phone: (555) \(String(format: "%03d", i % 1000))-\(String(format: "%04d", i))\n"
            } else {
                largeDocument += "Line \(i): This is regular content without PII.\n"
            }
        }
        
        measure {
            _ = filter.filterOCRText(largeDocument, source: "LargeDocTest")
        }
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testMalformedPIIHandling() {
        let malformedTexts = [
            "Email: not-an-email@",
            "Phone: 123-45", // Too short
            "SSN: 000-00-0000", // Invalid SSN
            "Card: 1234", // Too short for credit card
            "IP: 999.999.999.999", // Invalid IP
            "Mixed: user@domain.com and invalid-phone: 12"
        ]
        
        for text in malformedTexts {
            let result = filter.filterOCRText(text, source: "MalformedTest")
            
            // Should not crash and should handle gracefully
            XCTAssertNotNil(result)
            
            // May or may not detect PII depending on patterns
            if result.containedPII {
                XCTAssertTrue(result.detectedTypes.count > 0)
            }
        }
    }
    
    // MARK: - Audit Integration Tests
    
    func testComprehensiveAuditTrail() {
        let scenarios = [
            ("Medical form with SSN", "Patient SSN: 123-45-6789", [PIIType.ssn]),
            ("Business card with contact info", "Email: john@company.com, Phone: 555-1234", [PIIType.email, PIIType.phone]),
            ("Payment form", "Card: 4111111111111111, CVV: 123", [PIIType.creditCard]),
            ("System log", "Error connecting to 192.168.1.1", [PIIType.ipAddress])
        ]
        
        for (scenario, text, expectedTypes) in scenarios {
            _ = filter.filterOCRText(text, source: scenario)
        }
        
        // Wait for async audit logging
        let expectation = XCTestExpectation(description: "Audit completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify audit trail
        let auditEvents = auditor.getRecentEvents(limit: 20)
        XCTAssertGreaterThanOrEqual(auditEvents.count, scenarios.count)
        
        // Check that all expected PII types were logged
        let allLoggedTypes = Set(auditEvents.flatMap { $0.piiTypes })
        let allExpectedTypes = Set(scenarios.flatMap { $0.2 })
        
        for expectedType in allExpectedTypes {
            XCTAssertTrue(allLoggedTypes.contains(expectedType), "Expected PII type \(expectedType) not found in audit log")
        }
        
        // Generate and verify audit report
        let report = auditor.generateAuditReport(
            from: Date().addingTimeInterval(-3600),
            to: Date()
        )
        
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("Privacy Audit Report"))
        XCTAssertTrue(report.contains("Total Events"))
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testMedicalRecordScenario() {
        let medicalRecord = """
        PATIENT RECORD - CONFIDENTIAL
        
        Patient: Mary Johnson
        DOB: 05/12/1985
        SSN: 987-65-4321
        Phone: (555) 444-3333
        Email: mary.j@email.com
        
        Insurance: Policy #ABC123456
        Provider: Dr. Smith
        
        Diagnosis: Annual checkup
        Notes: Patient reports feeling well. No concerns.
        Next appointment: 06/15/2024
        """
        
        // Medical records should have strict privacy
        let medicalConfig = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: [] // No PII allowed
        )
        let medicalFilter = PIIFilter(config: medicalConfig, auditor: auditor)
        
        let result = medicalFilter.filterOCRText(medicalRecord, source: "MedicalOCR")
        
        XCTAssertTrue(result.containedPII)
        XCTAssertFalse(result.shouldStore) // Should be blocked
        XCTAssertGreaterThan(result.detectedTypes.count, 3) // Multiple PII types
        XCTAssertTrue(result.filteredText.contains("BLOCKED"))
    }
    
    func testBusinessCardScenario() {
        let businessCard = """
        JOHN SMITH
        Senior Software Engineer
        
        📧 john.smith@techcorp.com
        📱 (555) 123-4567
        🌐 www.techcorp.com
        
        TechCorp Solutions
        123 Innovation Drive, Suite 100
        San Francisco, CA 94105
        """
        
        // Business cards might allow contact info
        let businessConfig = PIIFilterConfig(
            preventPIIStorage: false,
            allowedPIITypes: [.email, .phone, .url]
        )
        let businessFilter = PIIFilter(config: businessConfig, auditor: auditor)
        
        let result = businessFilter.filterOCRText(businessCard, source: "BusinessCardOCR")
        
        XCTAssertTrue(result.containedPII)
        XCTAssertTrue(result.shouldStore) // Should be allowed with masking
        XCTAssertTrue(result.maskingApplied)
        
        // Should preserve business context while masking PII
        XCTAssertTrue(result.filteredText.contains("TechCorp"))
        XCTAssertTrue(result.filteredText.contains("Senior Software Engineer"))
    }
    
    func testSystemLogScenario() {
        let systemLog = """
        [2024-03-15 10:30:15] INFO: Application started
        [2024-03-15 10:30:16] DEBUG: Connected to database at 192.168.1.100:5432
        [2024-03-15 10:30:17] WARN: Failed login attempt for user@domain.com
        [2024-03-15 10:30:18] ERROR: Invalid credit card format: ****1234
        [2024-03-15 10:30:19] INFO: Session cleanup completed
        """
        
        // System logs might allow IP addresses but not personal info
        let logConfig = PIIFilterConfig(
            preventPIIStorage: false,
            allowedPIITypes: [.ipAddress]
        )
        let logFilter = PIIFilter(config: logConfig, auditor: auditor)
        
        let result = logFilter.filterOCRText(systemLog, source: "SystemLogOCR")
        
        XCTAssertTrue(result.shouldStore)
        
        if result.containedPII {
            // Should mask email but preserve IP and log structure
            XCTAssertTrue(result.filteredText.contains("192.168.1.100"))
            XCTAssertTrue(result.filteredText.contains("[2024-03-15"))
            XCTAssertFalse(result.filteredText.contains("user@domain.com"))
        }
    }
}