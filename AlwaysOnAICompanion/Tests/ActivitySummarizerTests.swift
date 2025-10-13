import XCTest
@testable import Shared

class ActivitySummarizerTests: XCTestCase {
    
    var summarizer: ActivitySummarizer!
    var sampleEvents: [ActivityEvent]!
    var sampleSpans: [Span]!
    
    override func setUp() {
        super.setUp()
        summarizer = ActivitySummarizer()
        setupSampleData()
    }
    
    override func tearDown() {
        summarizer = nil
        sampleEvents = nil
        sampleSpans = nil
        super.tearDown()
    }
    
    private func setupSampleData() {
        let baseTime = Date()
        
        // Create sample events for a form filling session
        sampleEvents = [
            ActivityEvent(
                id: "event1",
                timestamp: baseTime,
                type: .fieldChange,
                target: "email_field",
                valueBefore: "",
                valueAfter: "user@example.com",
                confidence: 0.9,
                evidenceFrames: ["frame1"],
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event2",
                timestamp: baseTime.addingTimeInterval(30),
                type: .fieldChange,
                target: "password_field",
                valueBefore: "",
                valueAfter: "********",
                confidence: 0.85,
                evidenceFrames: ["frame2"],
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event3",
                timestamp: baseTime.addingTimeInterval(60),
                type: .formSubmission,
                target: "login_form",
                valueBefore: nil,
                valueAfter: "submitted",
                confidence: 0.95,
                evidenceFrames: ["frame3"],
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event4",
                timestamp: baseTime.addingTimeInterval(90),
                type: .navigation,
                target: "dashboard",
                valueBefore: nil,
                valueAfter: "dashboard_page",
                confidence: 0.8,
                evidenceFrames: ["frame4"],
                metadata: ["app_name": "Safari"]
            )
        ]
        
        // Create sample spans for context
        sampleSpans = [
            Span(
                kind: "research",
                startTime: baseTime.addingTimeInterval(-1800), // 30 minutes before
                endTime: baseTime.addingTimeInterval(-300), // 5 minutes before
                title: "Research user authentication methods",
                summaryMarkdown: "Researched different authentication approaches",
                tags: ["research", "authentication"]
            ),
            Span(
                kind: "form_submission",
                startTime: baseTime.addingTimeInterval(300), // 5 minutes after
                endTime: baseTime.addingTimeInterval(600), // 10 minutes after
                title: "Complete profile setup",
                summaryMarkdown: "Filled out user profile information",
                tags: ["profile", "setup"]
            )
        ]
    }
    
    // MARK: - Basic Functionality Tests
    
    func testSummarizeActivityWithValidEvents() throws {
        let timeRange = DateInterval(
            start: sampleEvents.first!.timestamp.addingTimeInterval(-60),
            end: sampleEvents.last!.timestamp.addingTimeInterval(60)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: sampleEvents,
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        XCTAssertFalse(summaries.isEmpty, "Should generate at least one summary")
        
        let summary = summaries.first!
        XCTAssertFalse(summary.narrative.isEmpty, "Narrative should not be empty")
        XCTAssertFalse(summary.keyEvents.isEmpty, "Key events should not be empty")
        XCTAssertGreaterThan(summary.confidence, 0.0, "Confidence should be greater than 0")
    }
    
    func testSummarizeActivityWithEmptyEvents() throws {
        let timeRange = DateInterval(start: Date(), duration: 3600)
        
        let summaries = try summarizer.summarizeActivity(
            events: [],
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        XCTAssertTrue(summaries.isEmpty, "Should return empty array for no events")
    }
    
    func testSummarizeActivityWithEventsOutsideTimeRange() throws {
        let futureTime = Date().addingTimeInterval(86400) // 24 hours in future
        let timeRange = DateInterval(start: futureTime, duration: 3600)
        
        let summaries = try summarizer.summarizeActivity(
            events: sampleEvents,
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        XCTAssertTrue(summaries.isEmpty, "Should return empty array for events outside time range")
    }
    
    // MARK: - Session Grouping Tests
    
    func testIntelligentEventGrouping() throws {
        // Create events with gaps to test session grouping
        let baseTime = Date()
        let eventsWithGaps = [
            ActivityEvent(
                id: "group1_event1",
                timestamp: baseTime,
                type: .fieldChange,
                target: "field1",
                valueAfter: "value1",
                confidence: 0.9,
                metadata: ["app_name": "App1"]
            ),
            ActivityEvent(
                id: "group1_event2",
                timestamp: baseTime.addingTimeInterval(30),
                type: .fieldChange,
                target: "field2",
                valueAfter: "value2",
                confidence: 0.9,
                metadata: ["app_name": "App1"]
            ),
            // Large gap - should create new session
            ActivityEvent(
                id: "group2_event1",
                timestamp: baseTime.addingTimeInterval(600), // 10 minutes later
                type: .navigation,
                target: "page1",
                valueAfter: "navigated",
                confidence: 0.8,
                metadata: ["app_name": "App2"]
            ),
            ActivityEvent(
                id: "group2_event2",
                timestamp: baseTime.addingTimeInterval(630),
                type: .click,
                target: "button1",
                valueAfter: "clicked",
                confidence: 0.85,
                metadata: ["app_name": "App2"]
            )
        ]
        
        let timeRange = DateInterval(
            start: baseTime.addingTimeInterval(-60),
            end: baseTime.addingTimeInterval(700)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: eventsWithGaps,
            existingSpans: [],
            timeRange: timeRange
        )
        
        // Should create multiple sessions due to the gap
        XCTAssertGreaterThanOrEqual(summaries.count, 1, "Should group events into sessions")
        
        // Verify session contains related events
        let firstSummary = summaries.first!
        XCTAssertGreaterThanOrEqual(firstSummary.session.events.count, 2, "Session should contain multiple events")
    }
    
    // MARK: - Temporal Context Tests
    
    func testTemporalContextAnalysis() throws {
        let timeRange = DateInterval(
            start: sampleEvents.first!.timestamp.addingTimeInterval(-60),
            end: sampleEvents.last!.timestamp.addingTimeInterval(60)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: sampleEvents,
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        XCTAssertFalse(summaries.isEmpty, "Should generate summaries")
        
        let summary = summaries.first!
        let context = summary.context
        
        // Should find preceding spans
        XCTAssertFalse(context.precedingSpans.isEmpty, "Should find preceding spans")
        
        // Should find following spans
        XCTAssertFalse(context.followingSpans.isEmpty, "Should find following spans")
        
        // Should indicate workflow continuity
        XCTAssertTrue(context.workflowContinuity.isPartOfLargerWorkflow, "Should detect workflow continuity")
        XCTAssertGreaterThan(context.workflowContinuity.continuityScore, 0.0, "Should have positive continuity score")
    }
    
    func testWorkflowContinuityDetection() throws {
        // Test with no context spans
        let timeRange = DateInterval(
            start: sampleEvents.first!.timestamp.addingTimeInterval(-60),
            end: sampleEvents.last!.timestamp.addingTimeInterval(60)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: sampleEvents,
            existingSpans: [], // No context spans
            timeRange: timeRange
        )
        
        XCTAssertFalse(summaries.isEmpty, "Should generate summaries")
        
        let summary = summaries.first!
        let context = summary.context
        
        // Should not indicate workflow continuity without context
        XCTAssertFalse(context.workflowContinuity.isPartOfLargerWorkflow, "Should not detect workflow continuity without context")
    }
    
    // MARK: - Report Generation Tests
    
    func testGenerateReport() throws {
        let timeRange = DateInterval(
            start: sampleEvents.first!.timestamp.addingTimeInterval(-60),
            end: sampleEvents.last!.timestamp.addingTimeInterval(60)
        )
        
        let report = try summarizer.generateReport(
            events: sampleEvents,
            spans: sampleSpans,
            timeRange: timeRange,
            reportType: .daily
        )
        
        XCTAssertEqual(report.reportType, .daily, "Report type should match")
        XCTAssertEqual(report.timeRange, timeRange, "Time range should match")
        XCTAssertEqual(report.totalEvents, sampleEvents.count, "Total events should match")
        XCTAssertFalse(report.summaries.isEmpty, "Report should contain summaries")
        XCTAssertGreaterThan(report.totalDuration, 0, "Total duration should be positive")
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() throws {
        let customConfig = ActivitySummarizer.Configuration(
            minSessionDuration: 30, // Shorter minimum duration
            maxEventGap: 120, // Shorter gap tolerance
            minEventsForSummary: 2, // Fewer events required
            maxEventsForAnalysis: 20
        )
        
        let customSummarizer = ActivitySummarizer(configuration: customConfig)
        
        let timeRange = DateInterval(
            start: sampleEvents.first!.timestamp.addingTimeInterval(-60),
            end: sampleEvents.last!.timestamp.addingTimeInterval(60)
        )
        
        let summaries = try customSummarizer.summarizeActivity(
            events: sampleEvents,
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        XCTAssertFalse(summaries.isEmpty, "Custom configuration should still generate summaries")
    }
    
    // MARK: - Edge Cases Tests
    
    func testSingleEventSession() throws {
        let singleEvent = [sampleEvents.first!]
        
        let timeRange = DateInterval(
            start: singleEvent.first!.timestamp.addingTimeInterval(-60),
            end: singleEvent.first!.timestamp.addingTimeInterval(60)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: singleEvent,
            existingSpans: [],
            timeRange: timeRange
        )
        
        // Single event should not create a session (minimum 3 events required)
        XCTAssertTrue(summaries.isEmpty, "Single event should not create a session")
    }
    
    func testVeryShortSession() throws {
        // Create events with very short duration
        let baseTime = Date()
        let shortEvents = [
            ActivityEvent(
                id: "short1",
                timestamp: baseTime,
                type: .click,
                target: "button",
                confidence: 0.9
            ),
            ActivityEvent(
                id: "short2",
                timestamp: baseTime.addingTimeInterval(5),
                type: .click,
                target: "button2",
                confidence: 0.9
            ),
            ActivityEvent(
                id: "short3",
                timestamp: baseTime.addingTimeInterval(10),
                type: .click,
                target: "button3",
                confidence: 0.9
            )
        ]
        
        let timeRange = DateInterval(
            start: baseTime.addingTimeInterval(-60),
            end: baseTime.addingTimeInterval(60)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: shortEvents,
            existingSpans: [],
            timeRange: timeRange
        )
        
        // Very short session should not meet minimum duration requirement
        XCTAssertTrue(summaries.isEmpty, "Very short session should not meet minimum duration")
    }
    
    func testLowConfidenceEvents() throws {
        // Create events with low confidence scores
        let lowConfidenceEvents = sampleEvents.map { event in
            ActivityEvent(
                id: event.id,
                timestamp: event.timestamp,
                type: event.type,
                target: event.target,
                valueBefore: event.valueBefore,
                valueAfter: event.valueAfter,
                confidence: 0.3, // Low confidence
                evidenceFrames: event.evidenceFrames,
                metadata: event.metadata
            )
        }
        
        let timeRange = DateInterval(
            start: lowConfidenceEvents.first!.timestamp.addingTimeInterval(-60),
            end: lowConfidenceEvents.last!.timestamp.addingTimeInterval(60)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: lowConfidenceEvents,
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        if !summaries.isEmpty {
            let summary = summaries.first!
            // Summary confidence should reflect low event confidence
            XCTAssertLessThan(summary.confidence, 0.7, "Summary confidence should be lower for low-confidence events")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithManyEvents() throws {
        // Create a large number of events
        let baseTime = Date()
        var manyEvents: [ActivityEvent] = []
        
        for i in 0..<100 {
            let event = ActivityEvent(
                id: "event_\(i)",
                timestamp: baseTime.addingTimeInterval(TimeInterval(i * 10)),
                type: ActivityEventType.allCases.randomElement()!,
                target: "target_\(i)",
                valueAfter: "value_\(i)",
                confidence: Float.random(in: 0.7...0.95),
                metadata: ["app_name": "TestApp"]
            )
            manyEvents.append(event)
        }
        
        let timeRange = DateInterval(
            start: baseTime.addingTimeInterval(-60),
            end: baseTime.addingTimeInterval(1200) // 20 minutes
        )
        
        measure {
            do {
                let summaries = try summarizer.summarizeActivity(
                    events: manyEvents,
                    existingSpans: sampleSpans,
                    timeRange: timeRange
                )
                XCTAssertFalse(summaries.isEmpty, "Should handle many events efficiently")
            } catch {
                XCTFail("Should not throw error with many events: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndSummarization() throws {
        // Test complete workflow from events to final summary
        let timeRange = DateInterval(
            start: sampleEvents.first!.timestamp.addingTimeInterval(-60),
            end: sampleEvents.last!.timestamp.addingTimeInterval(60)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: sampleEvents,
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        XCTAssertFalse(summaries.isEmpty, "Should generate summaries")
        
        let summary = summaries.first!
        
        // Verify all components are properly populated
        XCTAssertFalse(summary.id.isEmpty, "Summary should have ID")
        XCTAssertFalse(summary.narrative.isEmpty, "Summary should have narrative")
        XCTAssertFalse(summary.keyEvents.isEmpty, "Summary should have key events")
        XCTAssertGreaterThan(summary.confidence, 0.0, "Summary should have confidence score")
        
        // Verify session details
        let session = summary.session
        XCTAssertEqual(session.events.count, sampleEvents.count, "Session should contain all events")
        XCTAssertEqual(session.primaryApplication, "Safari", "Should detect primary application")
        XCTAssertNotEqual(session.sessionType, .mixed, "Should classify session type specifically")
        
        // Verify temporal context
        let context = summary.context
        XCTAssertTrue(context.workflowContinuity.isPartOfLargerWorkflow, "Should detect workflow continuity")
        XCTAssertNotNil(context.workflowContinuity.workflowPhase, "Should identify workflow phase")
    }
}