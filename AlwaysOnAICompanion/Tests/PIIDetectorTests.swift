import XCTest
@testable import Shared

class PIIDetectorTests: XCTestCase {
    var detector: PIIDetector!
    
    override func setUp() {
        super.setUp()
        detector = PIIDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Email Detection Tests
    
    func testEmailDetection() {
        let testCases = [
            ("Contact me at john.doe@example.com for more info", true),
            ("My email is test+tag@domain.co.uk", true),
            ("Send to user123@test-domain.org", true),
            ("Invalid email: notanemail@", false),
            ("No email here", false),
            ("Almost email but not: user@", false)
        ]
        
        for (text, shouldDetect) in testCases {
            let matches = detector.detectPII(in: text)
            let hasEmail = matches.contains { $0.type == .email }
            
            XCTAssertEqual(hasEmail, shouldDetect, "Failed for text: \(text)")
            
            if shouldDetect {
                let emailMatch = matches.first { $0.type == .email }
                XCTAssertNotNil(emailMatch)
                XCTAssertGreaterThan(emailMatch!.confidence, 0.5)
            }
        }
    }
    
    func testEmailConfidenceScoring() {
        let validEmail = "user@domain.com"
        let invalidEmail = "not@email"
        
        let validMatches = detector.detectPII(in: "Email: \(validEmail)")
        let invalidMatches = detector.detectPII(in: "Text: \(invalidEmail)")
        
        if let validMatch = validMatches.first(where: { $0.type == .email }) {
            XCTAssertGreaterThan(validMatch.confidence, 0.8)
        }
        
        if let invalidMatch = invalidMatches.first(where: { $0.type == .email }) {
            XCTAssertLessThan(invalidMatch.confidence, 0.5)
        }
    }
    
    // MARK: - Phone Number Detection Tests
    
    func testPhoneNumberDetection() {
        let testCases = [
            ("Call me at (555) 123-4567", true),
            ("Phone: 555-123-4567", true),
            ("Contact: +1-555-123-4567", true),
            ("Number: 5551234567", true),
            ("International: +44 20 7946 0958", true),
            ("Not a phone: 123", false),
            ("Invalid: 555-12-34567", false)
        ]
        
        for (text, shouldDetect) in testCases {
            let matches = detector.detectPII(in: text)
            let hasPhone = matches.contains { $0.type == .phone }
            
            XCTAssertEqual(hasPhone, shouldDetect, "Failed for text: \(text)")
        }
    }
    
    // MARK: - SSN Detection Tests
    
    func testSSNDetection() {
        let testCases = [
            ("SSN: 123-45-6789", true),
            ("Social Security: 987 65 4321", true),
            ("ID: 555-44-3333", true),
            ("Invalid SSN: 000-00-0000", false),
            ("Invalid SSN: 666-12-3456", false),
            ("Not SSN: 123-456-7890", false)
        ]
        
        for (text, shouldDetect) in testCases {
            let matches = detector.detectPII(in: text)
            let hasSSN = matches.contains { $0.type == .ssn }
            
            XCTAssertEqual(hasSSN, shouldDetect, "Failed for text: \(text)")
        }
    }
    
    // MARK: - Credit Card Detection Tests
    
    func testCreditCardDetection() {
        let testCases = [
            ("Card: 4111111111111111", true),  // Visa test number
            ("Mastercard: 5555555555554444", true),
            ("Amex: 378282246310005", true),
            ("Invalid: 1234567890123456", false),
            ("Too short: 411111111", false)
        ]
        
        for (text, shouldDetect) in testCases {
            let matches = detector.detectPII(in: text)
            let hasCard = matches.contains { $0.type == .creditCard }
            
            XCTAssertEqual(hasCard, shouldDetect, "Failed for text: \(text)")
        }
    }
    
    // MARK: - IP Address Detection Tests
    
    func testIPAddressDetection() {
        let testCases = [
            ("Server IP: 192.168.1.1", true),
            ("Connect to 10.0.0.1", true),
            ("Public IP: 8.8.8.8", true),
            ("Invalid IP: 256.1.1.1", false),
            ("Not IP: 192.168.1", false),
            ("Invalid: 192.168.1.256", false)
        ]
        
        for (text, shouldDetect) in testCases {
            let matches = detector.detectPII(in: text)
            let hasIP = matches.contains { $0.type == .ipAddress }
            
            XCTAssertEqual(hasIP, shouldDetect, "Failed for text: \(text)")
        }
    }
    
    // MARK: - Multiple PII Types Tests
    
    func testMultiplePIITypes() {
        let text = """
        Contact Information:
        Email: john.doe@company.com
        Phone: (555) 123-4567
        SSN: 123-45-6789
        Server: 192.168.1.100
        """
        
        let matches = detector.detectPII(in: text)
        let detectedTypes = Set(matches.map { $0.type })
        
        XCTAssertTrue(detectedTypes.contains(.email))
        XCTAssertTrue(detectedTypes.contains(.phone))
        XCTAssertTrue(detectedTypes.contains(.ssn))
        XCTAssertTrue(detectedTypes.contains(.ipAddress))
        XCTAssertEqual(matches.count, 4)
    }
    
    // MARK: - Context and Range Tests
    
    func testPIIContextExtraction() {
        let text = "Please send the report to john.doe@company.com by Friday."
        let matches = detector.detectPII(in: text)
        
        guard let emailMatch = matches.first(where: { $0.type == .email }) else {
            XCTFail("Should detect email")
            return
        }
        
        XCTAssertTrue(emailMatch.context.contains("report"))
        XCTAssertTrue(emailMatch.context.contains("Friday"))
        XCTAssertEqual(emailMatch.text, "john.doe@company.com")
    }
    
    func testPIIRangeAccuracy() {
        let text = "Email: test@example.com and phone: 555-1234"
        let matches = detector.detectPII(in: text)
        
        for match in matches {
            let extractedText = (text as NSString).substring(with: match.range)
            XCTAssertEqual(extractedText, match.text)
        }
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() {
        let config = PIIDetectionConfig(
            enabledTypes: [.email, .phone],
            minimumConfidence: 0.9
        )
        
        let customDetector = PIIDetector(config: config)
        let text = "Email: test@example.com, SSN: 123-45-6789"
        let matches = customDetector.detectPII(in: text)
        
        // Should only detect email (if confidence is high enough)
        let detectedTypes = Set(matches.map { $0.type })
        XCTAssertFalse(detectedTypes.contains(.ssn))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyAndWhitespaceText() {
        XCTAssertTrue(detector.detectPII(in: "").isEmpty)
        XCTAssertTrue(detector.detectPII(in: "   ").isEmpty)
        XCTAssertTrue(detector.detectPII(in: "\n\t").isEmpty)
    }
    
    func testVeryLongText() {
        let longText = String(repeating: "This is a long text without PII. ", count: 1000)
        let matches = detector.detectPII(in: longText)
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testSpecialCharacters() {
        let text = "Email: test@domain.com with special chars: !@#$%^&*()"
        let matches = detector.detectPII(in: text)
        
        let emailMatch = matches.first { $0.type == .email }
        XCTAssertNotNil(emailMatch)
        XCTAssertEqual(emailMatch?.text, "test@domain.com")
    }
    
    // MARK: - Performance Tests
    
    func testDetectionPerformance() {
        let text = """
        Large document with multiple PII instances:
        Email: user1@domain.com, user2@company.org, admin@test.net
        Phones: (555) 123-4567, 555-987-6543, +1-555-111-2222
        SSNs: 123-45-6789, 987-65-4321
        IPs: 192.168.1.1, 10.0.0.1, 172.16.0.1
        Cards: 4111111111111111, 5555555555554444
        """
        
        measure {
            for _ in 0..<100 {
                _ = detector.detectPII(in: text)
            }
        }
    }
}