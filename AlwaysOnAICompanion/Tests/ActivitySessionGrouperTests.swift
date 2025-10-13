import XCTest
@testable import Shared

class ActivitySessionGrouperTests: XCTestCase {
    
    var grouper: ActivitySessionGrouper!
    var sampleEvents: [ActivityEvent]!
    
    override func setUp() {
        super.setUp()
        let config = ActivitySessionGrouper.Configuration()
        grouper = ActivitySessionGrouper(configuration: config)
        setupSampleData()
    }
    
    override func tearDown() {
        grouper = nil
        sampleEvents = nil
        super.tearDown()
    }
    
    private func setupSampleData() {
        let baseTime = Date()
        
        sampleEvents = [
            // First group - form filling session
            ActivityEvent(
                id: "event1",
                timestamp: baseTime,
                type: .fieldChange,
                target: "email_field",
                valueAfter: "user@example.com",
                confidence: 0.9,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event2",
                timestamp: baseTime.addingTimeInterval(30),
                type: .fieldChange,
                target: "password_field",
                valueAfter: "password",
                confidence: 0.85,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event3",
                timestamp: baseTime.addingTimeInterval(60),
                type: .formSubmission,
                target: "login_form",
                confidence: 0.95,
                metadata: ["app_name": "Safari"]
            ),
            
            // Gap - should create new session
            
            // Second group - navigation session
            ActivityEvent(
                id: "event4",
                timestamp: baseTime.addingTimeInterval(400), // 6+ minutes later
                type: .navigation,
                target: "dashboard",
                confidence: 0.8,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event5",
                timestamp: baseTime.addingTimeInterval(430),
                type: .click,
                target: "menu_button",
                confidence: 0.75,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event6",
                timestamp: baseTime.addingTimeInterval(460),
                type: .navigation,
                target: "settings",
                confidence: 0.8,
                metadata: ["app_name": "Safari"]
            )
        ]
    }
    
    // MARK: - Basic Grouping Tests
    
    func testBasicEventGrouping() throws {
        let sessions = try grouper.groupEventsIntoSessions(sampleEvents)
        
        XCTAssertGreaterThanOrEqual(sessions.count, 1, "Should create at least one session")
        
        // Verify sessions contain events
        for session in sessions {
            XCTAssertGreaterThanOrEqual(session.events.count, 3, "Each session should have minimum events")
            XCTAssertGreaterThanOrEqual(session.duration, 60, "Each session should meet minimum duration")
        }
    }
    
    func testTemporalGrouping() throws {
        let sessions = try grouper.groupEventsIntoSessions(sampleEvents)
        
        // Should create multiple sessions due to temporal gap
        XCTAssertGreaterThanOrEqual(sessions.count, 1, "Should handle temporal gaps")
        
        // Verify chronological ordering within sessions
        for session in sessions {
            let sortedEvents = session.events.sorted { $0.timestamp < $1.timestamp }
            XCTAssertEqual(session.events, sortedEvents, "Events within session should be chronologically ordered")
        }
    }
    
    func testEmptyEventsArray() throws {
        let sessions = try grouper.groupEventsIntoSessions([])
        XCTAssertTrue(sessions.isEmpty, "Should return empty array for no events")
    }
    
    func testSingleEvent() throws {
        let singleEvent = [sampleEvents.first!]
        let sessions = try grouper.groupEventsIntoSessions(singleEvent)
        
        // Single event should not create a session (minimum 3 events required)
        XCTAssertTrue(sessions.isEmpty, "Single event should not create a session")
    }
    
    // MARK: - Session Type Detection Tests
    
    func testFormFillingSessionDetection() throws {
        let formEvents = [
            ActivityEvent(
                id: "form1",
                timestamp: Date(),
                type: .fieldChange,
                target: "name_field",
                valueAfter: "John Doe",
                confidence: 0.9,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "form2",
                timestamp: Date().addingTimeInterval(30),
                type: .fieldChange,
                target: "email_field",
                valueAfter: "john@example.com",
                confidence: 0.9,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "form3",
                timestamp: Date().addingTimeInterval(60),
                type: .formSubmission,
                target: "contact_form",
                confidence: 0.95,
                metadata: ["app_name": "Safari"]
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(formEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should create session for form events")
        
        let session = sessions.first!
        XCTAssertEqual(session.sessionType, .formFilling, "Should detect form filling session type")
    }
    
    func testDataEntrySessionDetection() throws {
        let dataEvents = [
            ActivityEvent(
                id: "data1",
                timestamp: Date(),
                type: .dataEntry,
                target: "spreadsheet_cell_A1",
                valueAfter: "100",
                confidence: 0.9,
                metadata: ["app_name": "Excel"]
            ),
            ActivityEvent(
                id: "data2",
                timestamp: Date().addingTimeInterval(30),
                type: .dataEntry,
                target: "spreadsheet_cell_A2",
                valueAfter: "200",
                confidence: 0.9,
                metadata: ["app_name": "Excel"]
            ),
            ActivityEvent(
                id: "data3",
                timestamp: Date().addingTimeInterval(60),
                type: .dataEntry,
                target: "spreadsheet_cell_A3",
                valueAfter: "300",
                confidence: 0.9,
                metadata: ["app_name": "Excel"]
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(dataEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should create session for data entry events")
        
        let session = sessions.first!
        XCTAssertEqual(session.sessionType, .dataEntry, "Should detect data entry session type")
    }
    
    func testNavigationSessionDetection() throws {
        let navEvents = [
            ActivityEvent(
                id: "nav1",
                timestamp: Date(),
                type: .navigation,
                target: "page1",
                confidence: 0.8,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "nav2",
                timestamp: Date().addingTimeInterval(30),
                type: .navigation,
                target: "page2",
                confidence: 0.8,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "nav3",
                timestamp: Date().addingTimeInterval(60),
                type: .appSwitch,
                target: "Chrome",
                confidence: 0.75,
                metadata: ["app_name": "Chrome"]
            ),
            ActivityEvent(
                id: "nav4",
                timestamp: Date().addingTimeInterval(90),
                type: .navigation,
                target: "page3",
                confidence: 0.8,
                metadata: ["app_name": "Chrome"]
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(navEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should create session for navigation events")
        
        let session = sessions.first!
        XCTAssertEqual(session.sessionType, .navigation, "Should detect navigation session type")
    }
    
    func testResearchSessionDetection() throws {
        let researchEvents = [
            ActivityEvent(
                id: "research1",
                timestamp: Date(),
                type: .navigation,
                target: "google.com",
                confidence: 0.8,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "research2",
                timestamp: Date().addingTimeInterval(30),
                type: .click,
                target: "search_result_1",
                confidence: 0.75,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "research3",
                timestamp: Date().addingTimeInterval(60),
                type: .click,
                target: "link_1",
                confidence: 0.75,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "research4",
                timestamp: Date().addingTimeInterval(90),
                type: .navigation,
                target: "wikipedia.org",
                confidence: 0.8,
                metadata: ["app_name": "Safari"]
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(researchEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should create session for research events")
        
        let session = sessions.first!
        XCTAssertEqual(session.sessionType, .research, "Should detect research session type")
    }
    
    // MARK: - Application Detection Tests
    
    func testPrimaryApplicationDetection() throws {
        let sessions = try grouper.groupEventsIntoSessions(sampleEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should create sessions")
        
        let session = sessions.first!
        XCTAssertEqual(session.primaryApplication, "Safari", "Should detect Safari as primary application")
    }
    
    func testMixedApplicationSession() throws {
        let mixedEvents = [
            ActivityEvent(
                id: "mixed1",
                timestamp: Date(),
                type: .fieldChange,
                target: "field1",
                confidence: 0.9,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "mixed2",
                timestamp: Date().addingTimeInterval(30),
                type: .fieldChange,
                target: "field2",
                confidence: 0.9,
                metadata: ["app_name": "Chrome"]
            ),
            ActivityEvent(
                id: "mixed3",
                timestamp: Date().addingTimeInterval(60),
                type: .fieldChange,
                target: "field3",
                confidence: 0.9,
                metadata: ["app_name": "Safari"]
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(mixedEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should create session for mixed app events")
        
        let session = sessions.first!
        XCTAssertEqual(session.primaryApplication, "Safari", "Should detect most frequent app as primary")
    }
    
    // MARK: - Contextual Similarity Tests
    
    func testContextualSimilarityGrouping() throws {
        let similarEvents = [
            ActivityEvent(
                id: "similar1",
                timestamp: Date(),
                type: .fieldChange,
                target: "user_name",
                confidence: 0.9,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "similar2",
                timestamp: Date().addingTimeInterval(30),
                type: .fieldChange,
                target: "user_email",
                confidence: 0.9,
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "different1",
                timestamp: Date().addingTimeInterval(60),
                type: .navigation,
                target: "different_page",
                confidence: 0.8,
                metadata: ["app_name": "Chrome"] // Different app
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(similarEvents)
        
        // Should potentially split into multiple sessions due to context change
        XCTAssertGreaterThanOrEqual(sessions.count, 1, "Should handle contextual differences")
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() throws {
        let customConfig = ActivitySessionGrouper.Configuration(
            maxEventGap: 120, // 2 minutes
            minSessionDuration: 30, // 30 seconds
            minEventsPerSession: 2, // Only 2 events required
            maxEventsPerSession: 10,
            contextSimilarityThreshold: 0.5
        )
        
        let customGrouper = ActivitySessionGrouper(configuration: customConfig)
        
        let sessions = try customGrouper.groupEventsIntoSessions(sampleEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Custom configuration should still create sessions")
        
        // With lower thresholds, might create more sessions
        for session in sessions {
            XCTAssertGreaterThanOrEqual(session.events.count, 2, "Should respect custom minimum events")
        }
    }
    
    func testMaxEventsPerSession() throws {
        let config = ActivitySessionGrouper.Configuration(
            maxEventsPerSession: 2 // Very small limit
        )
        
        let limitedGrouper = ActivitySessionGrouper(configuration: config)
        
        // Create many closely-timed events
        let baseTime = Date()
        let manyEvents = (0..<10).map { i in
            ActivityEvent(
                id: "event_\(i)",
                timestamp: baseTime.addingTimeInterval(TimeInterval(i * 10)),
                type: .click,
                target: "button_\(i)",
                confidence: 0.8,
                metadata: ["app_name": "TestApp"]
            )
        }
        
        let sessions = try limitedGrouper.groupEventsIntoSessions(manyEvents)
        
        // Should create multiple sessions due to event limit
        XCTAssertGreaterThan(sessions.count, 1, "Should split large groups when exceeding max events")
        
        for session in sessions {
            XCTAssertLessThanOrEqual(session.events.count, 2, "Should respect max events per session")
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testVeryShortEvents() throws {
        let baseTime = Date()
        let shortEvents = [
            ActivityEvent(
                id: "short1",
                timestamp: baseTime,
                type: .click,
                target: "button1",
                confidence: 0.8
            ),
            ActivityEvent(
                id: "short2",
                timestamp: baseTime.addingTimeInterval(5),
                type: .click,
                target: "button2",
                confidence: 0.8
            ),
            ActivityEvent(
                id: "short3",
                timestamp: baseTime.addingTimeInterval(10),
                type: .click,
                target: "button3",
                confidence: 0.8
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(shortEvents)
        
        // Very short duration should not meet minimum requirements
        XCTAssertTrue(sessions.isEmpty, "Very short sessions should be filtered out")
    }
    
    func testIdenticalTimestamps() throws {
        let sameTime = Date()
        let simultaneousEvents = [
            ActivityEvent(
                id: "sim1",
                timestamp: sameTime,
                type: .click,
                target: "button1",
                confidence: 0.8
            ),
            ActivityEvent(
                id: "sim2",
                timestamp: sameTime,
                type: .click,
                target: "button2",
                confidence: 0.8
            ),
            ActivityEvent(
                id: "sim3",
                timestamp: sameTime,
                type: .click,
                target: "button3",
                confidence: 0.8
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(simultaneousEvents)
        
        // Should handle simultaneous events gracefully
        if !sessions.isEmpty {
            let session = sessions.first!
            XCTAssertEqual(session.events.count, 3, "Should include all simultaneous events")
        }
    }
    
    func testOutOfOrderEvents() throws {
        let baseTime = Date()
        let outOfOrderEvents = [
            ActivityEvent(
                id: "order3",
                timestamp: baseTime.addingTimeInterval(120), // Third chronologically
                type: .formSubmission,
                target: "form",
                confidence: 0.9
            ),
            ActivityEvent(
                id: "order1",
                timestamp: baseTime, // First chronologically
                type: .fieldChange,
                target: "field1",
                confidence: 0.9
            ),
            ActivityEvent(
                id: "order2",
                timestamp: baseTime.addingTimeInterval(60), // Second chronologically
                type: .fieldChange,
                target: "field2",
                confidence: 0.9
            )
        ]
        
        let sessions = try grouper.groupEventsIntoSessions(outOfOrderEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should handle out-of-order events")
        
        let session = sessions.first!
        let sortedEvents = session.events.sorted { $0.timestamp < $1.timestamp }
        
        // Events should be sorted chronologically in the session
        XCTAssertEqual(session.events, sortedEvents, "Events should be chronologically ordered in session")
        XCTAssertEqual(session.events.first?.id, "order1", "First event should be chronologically first")
        XCTAssertEqual(session.events.last?.id, "order3", "Last event should be chronologically last")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithManyEvents() throws {
        let baseTime = Date()
        var manyEvents: [ActivityEvent] = []
        
        // Create 100 events
        for i in 0..<100 {
            let event = ActivityEvent(
                id: "perf_event_\(i)",
                timestamp: baseTime.addingTimeInterval(TimeInterval(i * 30)),
                type: ActivityEventType.allCases.randomElement()!,
                target: "target_\(i)",
                confidence: Float.random(in: 0.7...0.95),
                metadata: ["app_name": "TestApp"]
            )
            manyEvents.append(event)
        }
        
        measure {
            do {
                let sessions = try grouper.groupEventsIntoSessions(manyEvents)
                XCTAssertFalse(sessions.isEmpty, "Should handle many events efficiently")
            } catch {
                XCTFail("Should not throw error with many events: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteGroupingWorkflow() throws {
        let sessions = try grouper.groupEventsIntoSessions(sampleEvents)
        
        XCTAssertFalse(sessions.isEmpty, "Should create sessions")
        
        for session in sessions {
            // Verify session integrity
            XCTAssertFalse(session.id.isEmpty, "Session should have ID")
            XCTAssertGreaterThan(session.duration, 0, "Session should have positive duration")
            XCTAssertFalse(session.events.isEmpty, "Session should contain events")
            XCTAssertNotEqual(session.sessionType, .mixed, "Should classify session type specifically")
            
            // Verify temporal consistency
            XCTAssertLessThanOrEqual(session.startTime, session.endTime, "Start time should be before end time")
            
            if let firstEvent = session.events.first, let lastEvent = session.events.last {
                XCTAssertEqual(session.startTime, firstEvent.timestamp, "Session start should match first event")
                XCTAssertEqual(session.endTime, lastEvent.timestamp, "Session end should match last event")
            }
            
            // Verify event ordering
            for i in 1..<session.events.count {
                let prevEvent = session.events[i-1]
                let currentEvent = session.events[i]
                XCTAssertLessThanOrEqual(prevEvent.timestamp, currentEvent.timestamp, "Events should be chronologically ordered")
            }
        }
    }
}