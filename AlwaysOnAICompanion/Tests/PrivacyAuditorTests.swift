import XCTest
@testable import Shared

class PrivacyAuditorTests: XCTestCase {
    var auditor: PrivacyAuditor!
    var tempDatabaseURL: URL!
    
    override func setUp() {
        super.setUp()
        tempDatabaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_privacy_audit_\(UUID().uuidString).db")
        auditor = PrivacyAuditor(databasePath: tempDatabaseURL)
    }
    
    override func tearDown() {
        auditor = nil
        try? FileManager.default.removeItem(at: tempDatabaseURL)
        super.tearDown()
    }
    
    // MARK: - Basic Event Logging Tests
    
    func testBasicEventLogging() {
        let event = PrivacyAuditEvent(
            eventType: .piiDetected,
            piiTypes: [.email],
            context: "Test PII detection",
            sourceComponent: "TestComponent"
        )
        
        auditor.logEvent(event)
        
        let recentEvents = auditor.getRecentEvents(limit: 10)
        XCTAssertGreaterThan(recentEvents.count, 0)
        
        let loggedEvent = recentEvents.first!
        XCTAssertEqual(loggedEvent.eventType, .piiDetected)
        XCTAssertTrue(loggedEvent.piiTypes.contains(.email))
        XCTAssertEqual(loggedEvent.context, "Test PII detection")
        XCTAssertEqual(loggedEvent.sourceComponent, "TestComponent")
    }
    
    func testMultipleEventLogging() {
        let events = [
            PrivacyAuditEvent(eventType: .piiDetected, piiTypes: [.email], context: "Email detected", sourceComponent: "OCR"),
            PrivacyAuditEvent(eventType: .piiMasked, piiTypes: [.phone], context: "Phone masked", sourceComponent: "Filter"),
            PrivacyAuditEvent(eventType: .configChanged, context: "Config updated", sourceComponent: "Settings")
        ]
        
        for event in events {
            auditor.logEvent(event)
        }
        
        let recentEvents = auditor.getRecentEvents(limit: 10)
        XCTAssertGreaterThanOrEqual(recentEvents.count, 3)
    }
    
    // MARK: - Convenience Logging Methods Tests
    
    func testPIIDetectionLogging() {
        let piiTypes: Set<PIIType> = [.email, .phone]
        auditor.logPIIDetection(piiTypes: piiTypes, context: "OCR processing", source: "VisionOCR")
        
        let events = auditor.getEvents(ofType: .piiDetected, limit: 5)
        XCTAssertGreaterThan(events.count, 0)
        
        let event = events.first!
        XCTAssertEqual(event.eventType, .piiDetected)
        XCTAssertTrue(event.piiTypes.contains(.email))
        XCTAssertTrue(event.piiTypes.contains(.phone))
        XCTAssertEqual(event.sourceComponent, "VisionOCR")
    }
    
    func testPIIMaskingLogging() {
        let maskingResult = MaskingResult(
            maskedText: "Email: ***@***.com",
            maskedCount: 1,
            maskingMap: [.email: 1],
            preservedRanges: []
        )
        
        auditor.logPIIMasking(piiTypes: [.email], maskingResult: maskingResult, source: "PIIMasker")
        
        let events = auditor.getEvents(ofType: .piiMasked, limit: 5)
        XCTAssertGreaterThan(events.count, 0)
        
        let event = events.first!
        XCTAssertEqual(event.eventType, .piiMasked)
        XCTAssertTrue(event.piiTypes.contains(.email))
        XCTAssertEqual(event.metadata["masked_count"], "1")
    }
    
    func testConfigChangeLogging() {
        let changes = [
            "enableRealTimeFiltering": "true",
            "preventPIIStorage": "false",
            "allowedPIITypes": "email,phone"
        ]
        
        auditor.logConfigChange(component: "PIIFilter", changes: changes)
        
        let events = auditor.getEvents(ofType: .configChanged, limit: 5)
        XCTAssertGreaterThan(events.count, 0)
        
        let event = events.first!
        XCTAssertEqual(event.eventType, .configChanged)
        XCTAssertEqual(event.sourceComponent, "PIIFilter")
        XCTAssertEqual(event.metadata["enableRealTimeFiltering"], "true")
    }
    
    // MARK: - Event Filtering Tests
    
    func testEventTypeFiltering() {
        // Log different types of events
        auditor.logEvent(PrivacyAuditEvent(eventType: .piiDetected, context: "Test 1", sourceComponent: "Test"))
        auditor.logEvent(PrivacyAuditEvent(eventType: .piiMasked, context: "Test 2", sourceComponent: "Test"))
        auditor.logEvent(PrivacyAuditEvent(eventType: .configChanged, context: "Test 3", sourceComponent: "Test"))
        
        let detectedEvents = auditor.getEvents(ofType: .piiDetected, limit: 10)
        let maskedEvents = auditor.getEvents(ofType: .piiMasked, limit: 10)
        let configEvents = auditor.getEvents(ofType: .configChanged, limit: 10)
        
        XCTAssertGreaterThan(detectedEvents.count, 0)
        XCTAssertGreaterThan(maskedEvents.count, 0)
        XCTAssertGreaterThan(configEvents.count, 0)
        
        XCTAssertTrue(detectedEvents.allSatisfy { $0.eventType == .piiDetected })
        XCTAssertTrue(maskedEvents.allSatisfy { $0.eventType == .piiMasked })
        XCTAssertTrue(configEvents.allSatisfy { $0.eventType == .configChanged })
    }
    
    func testSeverityFiltering() {
        let config = PrivacyAuditConfig(minimumSeverity: .medium)
        let filteredAuditor = PrivacyAuditor(config: config, databasePath: tempDatabaseURL)
        
        // Log events with different severities
        filteredAuditor.logEvent(PrivacyAuditEvent(eventType: .piiDetected, context: "Low severity", sourceComponent: "Test", severity: .low))
        filteredAuditor.logEvent(PrivacyAuditEvent(eventType: .piiDetected, context: "Medium severity", sourceComponent: "Test", severity: .medium))
        filteredAuditor.logEvent(PrivacyAuditEvent(eventType: .piiDetected, context: "High severity", sourceComponent: "Test", severity: .high))
        
        let events = filteredAuditor.getRecentEvents(limit: 10)
        
        // Should only log medium and high severity events
        XCTAssertTrue(events.allSatisfy { $0.severity.rawValue >= PrivacySeverity.medium.rawValue })
    }
    
    // MARK: - Statistics Tests
    
    func testAuditStatistics() {
        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()
        
        // Log various events
        auditor.logPIIDetection(piiTypes: [.email], context: "Test", source: "OCR1")
        auditor.logPIIDetection(piiTypes: [.phone, .ssn], context: "Test", source: "OCR2")
        auditor.logPIIMasking(piiTypes: [.email], maskingResult: MaskingResult(maskedText: "", maskedCount: 1, maskingMap: [.email: 1], preservedRanges: []), source: "Masker")
        
        let stats = auditor.getAuditStats(from: startDate, to: endDate)
        XCTAssertNotNil(stats)
        
        if let stats = stats {
            XCTAssertGreaterThan(stats.totalEvents, 0)
            XCTAssertGreaterThan(stats.eventsByType.count, 0)
            XCTAssertGreaterThan(stats.piiTypeFrequency.count, 0)
            XCTAssertTrue(stats.piiTypeFrequency[.email] ?? 0 > 0)
        }
    }
    
    // MARK: - Report Generation Tests
    
    func testAuditReportGeneration() {
        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()
        
        // Log some events for the report
        auditor.logPIIDetection(piiTypes: [.email, .phone], context: "Form processing", source: "OCR")
        auditor.logPIIMasking(piiTypes: [.ssn], maskingResult: MaskingResult(maskedText: "", maskedCount: 1, maskingMap: [.ssn: 1], preservedRanges: []), source: "Filter")
        
        let report = auditor.generateAuditReport(from: startDate, to: endDate)
        
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("Privacy Audit Report"))
        XCTAssertTrue(report.contains("Total Events"))
        XCTAssertTrue(report.contains("Events by Type"))
        XCTAssertTrue(report.contains("PII Types Detected"))
    }
    
    // MARK: - Data Retention Tests
    
    func testDataRetention() {
        // Create an event with old timestamp
        let oldEvent = PrivacyAuditEvent(
            timestamp: Date().addingTimeInterval(-100 * 24 * 60 * 60), // 100 days ago
            eventType: .piiDetected,
            context: "Old event",
            sourceComponent: "Test"
        )
        
        auditor.logEvent(oldEvent)
        
        // Verify event was logged
        let allEvents = auditor.getRecentEvents(limit: 100)
        XCTAssertTrue(allEvents.contains { $0.context == "Old event" })
        
        // Trigger cleanup
        auditor.cleanupOldRecords()
        
        // Give some time for cleanup to complete
        let expectation = XCTestExpectation(description: "Cleanup completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Verify old event was removed (assuming default retention of 90 days)
        let remainingEvents = auditor.getRecentEvents(limit: 100)
        XCTAssertFalse(remainingEvents.contains { $0.context == "Old event" })
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() {
        let config = PrivacyAuditConfig(
            retentionDays: 30,
            enabledEventTypes: [.piiDetected, .piiMasked],
            minimumSeverity: .high,
            maxEventsPerHour: 100
        )
        
        let customAuditor = PrivacyAuditor(config: config, databasePath: tempDatabaseURL)
        
        // Log events that should be filtered out
        customAuditor.logEvent(PrivacyAuditEvent(eventType: .configChanged, context: "Should be filtered", sourceComponent: "Test"))
        customAuditor.logEvent(PrivacyAuditEvent(eventType: .piiDetected, context: "Should be filtered", sourceComponent: "Test", severity: .low))
        
        // Log event that should be included
        customAuditor.logEvent(PrivacyAuditEvent(eventType: .piiDetected, context: "Should be included", sourceComponent: "Test", severity: .high))
        
        let events = customAuditor.getRecentEvents(limit: 10)
        
        // Should only contain the high severity PII detection event
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.context, "Should be included")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDatabase() {
        let emptyStats = auditor.getAuditStats(from: Date().addingTimeInterval(-3600), to: Date())
        XCTAssertNotNil(emptyStats)
        
        if let stats = emptyStats {
            XCTAssertEqual(stats.totalEvents, 0)
            XCTAssertTrue(stats.eventsByType.isEmpty)
            XCTAssertTrue(stats.piiTypeFrequency.isEmpty)
        }
        
        let emptyEvents = auditor.getRecentEvents(limit: 10)
        XCTAssertTrue(emptyEvents.isEmpty)
    }
    
    func testLargeMetadata() {
        let largeMetadata = (0..<100).reduce(into: [String: String]()) { dict, i in
            dict["key\(i)"] = String(repeating: "value", count: 100)
        }
        
        let event = PrivacyAuditEvent(
            eventType: .piiDetected,
            context: "Large metadata test",
            sourceComponent: "Test",
            metadata: largeMetadata
        )
        
        auditor.logEvent(event)
        
        let events = auditor.getRecentEvents(limit: 1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.metadata.count, largeMetadata.count)
    }
    
    // MARK: - Performance Tests
    
    func testLoggingPerformance() {
        measure {
            for i in 0..<100 {
                let event = PrivacyAuditEvent(
                    eventType: .piiDetected,
                    piiTypes: [.email],
                    context: "Performance test \(i)",
                    sourceComponent: "PerformanceTest"
                )
                auditor.logEvent(event)
            }
        }
    }
    
    func testQueryPerformance() {
        // Pre-populate with events
        for i in 0..<1000 {
            let event = PrivacyAuditEvent(
                eventType: i % 2 == 0 ? .piiDetected : .piiMasked,
                piiTypes: [.email],
                context: "Query test \(i)",
                sourceComponent: "QueryTest"
            )
            auditor.logEvent(event)
        }
        
        measure {
            _ = auditor.getRecentEvents(limit: 100)
            _ = auditor.getEvents(ofType: .piiDetected, limit: 50)
            _ = auditor.getAuditStats(from: Date().addingTimeInterval(-3600), to: Date())
        }
    }
    
    // MARK: - Integration Tests
    
    func testRealWorldScenario() {
        // Simulate a day of PII processing
        let scenarios = [
            (PIIType.email, "Email processing in OCR", PrivacySeverity.medium),
            (PIIType.ssn, "SSN detected in form", PrivacySeverity.critical),
            (PIIType.phone, "Phone number in contact list", PrivacySeverity.low),
            (PIIType.creditCard, "Credit card in receipt", PrivacySeverity.high)
        ]
        
        for (piiType, context, severity) in scenarios {
            // Detection
            auditor.logPIIDetection(piiTypes: [piiType], context: context, source: "OCR")
            
            // Masking
            let maskingResult = MaskingResult(maskedText: "masked", maskedCount: 1, maskingMap: [piiType: 1], preservedRanges: [])
            auditor.logPIIMasking(piiTypes: [piiType], maskingResult: maskingResult, source: "Filter")
        }
        
        // Configuration change
        auditor.logConfigChange(component: "PIIFilter", changes: ["setting": "updated"])
        
        let stats = auditor.getAuditStats(from: Date().addingTimeInterval(-3600), to: Date())
        XCTAssertNotNil(stats)
        
        if let stats = stats {
            XCTAssertGreaterThan(stats.totalEvents, 8) // At least detection + masking for each scenario + config change
            XCTAssertGreaterThan(stats.eventsByType[.piiDetected] ?? 0, 0)
            XCTAssertGreaterThan(stats.eventsByType[.piiMasked] ?? 0, 0)
            XCTAssertGreaterThan(stats.eventsByType[.configChanged] ?? 0, 0)
        }
        
        let report = auditor.generateAuditReport(from: Date().addingTimeInterval(-3600), to: Date())
        XCTAssertTrue(report.contains("Email Address"))
        XCTAssertTrue(report.contains("Social Security Number"))
        XCTAssertTrue(report.contains("Credit Card Number"))
    }
}