import XCTest
@testable import Shared

class PlaybookCreatorTests: XCTestCase {
    
    var playbookCreator: PlaybookCreator!
    var sampleSummaries: [ActivitySummary]!
    
    override func setUp() {
        super.setUp()
        
        playbookCreator = PlaybookCreator()
        sampleSummaries = createSampleSummaries()
    }
    
    override func tearDown() {
        playbookCreator = nil
        sampleSummaries = nil
        super.tearDown()
    }
    
    // MARK: - Playbook Creation Tests
    
    func testCreatePlaybookFromMultipleSummaries() throws {
        let playbook = try playbookCreator.createPlaybook(from: sampleSummaries)
        
        XCTAssertFalse(playbook.title.isEmpty, "Playbook should have a title")
        XCTAssertFalse(playbook.description.isEmpty, "Playbook should have a description")
        XCTAssertGreaterThan(playbook.steps.count, 0, "Playbook should have steps")
        XCTAssertNotNil(playbook.type, "Playbook should have a type")
        XCTAssertGreaterThan(playbook.estimatedDuration, 0, "Playbook should have estimated duration")
        
        // Verify steps are properly ordered
        for i in 1..<playbook.steps.count {
            // Steps should maintain some logical order (not necessarily strict chronological)
            XCTAssertFalse(playbook.steps[i].action.isEmpty, "Each step should have an action")
        }
        
        print("Created Playbook:")
        print("Title: \(playbook.title)")
        print("Type: \(playbook.type)")
        print("Steps: \(playbook.steps.count)")
        print("Duration: \(playbook.estimatedDuration)")
    }
    
    func testCreateSingleSessionPlaybook() throws {
        let singleSummary = sampleSummaries.first!
        let playbook = try playbookCreator.createSingleSessionPlaybook(from: singleSummary)
        
        XCTAssertFalse(playbook.title.isEmpty, "Single session playbook should have a title")
        XCTAssertGreaterThan(playbook.steps.count, 0, "Single session playbook should have steps")
        XCTAssertEqual(playbook.sourceSummaries.count, 1, "Should reference only one summary")
        XCTAssertEqual(playbook.sourceSummaries.first, singleSummary.id, "Should reference the correct summary")
    }
    
    func testPlaybookTypeDetection() throws {
        // Test form filling detection
        let formSummaries = createFormFillingSummaries()
        let formPlaybook = try playbookCreator.createPlaybook(from: formSummaries)
        XCTAssertEqual(formPlaybook.type, .formWorkflow, "Should detect form workflow type")
        
        // Test data entry detection
        let dataEntrySummaries = createDataEntrySummaries()
        let dataPlaybook = try playbookCreator.createPlaybook(from: dataEntrySummaries)
        XCTAssertEqual(dataPlaybook.type, .dataEntry, "Should detect data entry type")
        
        // Test navigation detection
        let navigationSummaries = createNavigationSummaries()
        let navPlaybook = try playbookCreator.createPlaybook(from: navigationSummaries)
        XCTAssertEqual(navPlaybook.type, .navigation, "Should detect navigation type")
    }
    
    func testPlaybookDifficultyAssessment() throws {
        // Test beginner difficulty (few events, short duration)
        let beginnerSummaries = createBeginnerSummaries()
        let beginnerPlaybook = try playbookCreator.createPlaybook(from: beginnerSummaries)
        XCTAssertEqual(beginnerPlaybook.difficulty, .beginner, "Should assess as beginner difficulty")
        
        // Test advanced difficulty (many events, long duration)
        let advancedSummaries = createAdvancedSummaries()
        let advancedPlaybook = try playbookCreator.createPlaybook(from: advancedSummaries)
        XCTAssertEqual(advancedPlaybook.difficulty, .advanced, "Should assess as advanced difficulty")
    }
    
    // MARK: - Step Generation Tests
    
    func testStepGenerationFromEvents() throws {
        let playbook = try playbookCreator.createPlaybook(from: sampleSummaries)
        
        // Verify step content
        let steps = playbook.steps
        XCTAssertGreaterThan(steps.count, 0, "Should generate steps from events")
        
        for step in steps {
            XCTAssertFalse(step.action.isEmpty, "Each step should have an action")
            XCTAssertGreaterThan(step.confidence, 0, "Each step should have confidence > 0")
            XCTAssertLessThanOrEqual(step.confidence, 1, "Each step should have confidence <= 1")
        }
        
        // Check for different types of steps
        let actionTypes = Set(steps.map { $0.action })
        XCTAssertGreaterThan(actionTypes.count, 1, "Should generate different types of actions")
        
        print("Generated Steps:")
        for (index, step) in steps.enumerated() {
            print("\(index + 1). \(step.action)")
            if let target = step.target {
                print("   Target: \(target)")
            }
            if let value = step.expectedValue {
                print("   Value: \(value)")
            }
        }
    }
    
    func testStepGrouping() throws {
        let config = PlaybookCreator.Configuration(groupSimilarActions: true)
        let creator = PlaybookCreator(configuration: config)
        
        let summariesWithSimilarSteps = createSummariesWithSimilarSteps()
        let playbook = try creator.createPlaybook(from: summariesWithSimilarSteps)
        
        // Should have fewer steps due to grouping
        let originalEventCount = summariesWithSimilarSteps.reduce(0) { $0 + $1.session.events.count }
        XCTAssertLessThan(playbook.steps.count, originalEventCount, "Should group similar steps")
        
        // Check for grouped step indicators
        let groupedSteps = playbook.steps.filter { $0.notes.contains { $0.contains("Grouped") } }
        XCTAssertGreaterThan(groupedSteps.count, 0, "Should have grouped steps")
    }
    
    // MARK: - Format Output Tests
    
    func testFormatAsMarkdown() throws {
        let playbook = try playbookCreator.createPlaybook(from: sampleSummaries)
        let markdown = try playbookCreator.formatAsMarkdown(playbook)
        
        XCTAssertFalse(markdown.isEmpty, "Markdown output should not be empty")
        XCTAssertTrue(markdown.contains("# "), "Should contain main title")
        XCTAssertTrue(markdown.contains("## Playbook Information"), "Should contain information section")
        XCTAssertTrue(markdown.contains("## Steps"), "Should contain steps section")
        XCTAssertTrue(markdown.contains("1. "), "Should contain numbered steps")
        
        // Check for metadata table
        XCTAssertTrue(markdown.contains("| Property | Value |"), "Should contain metadata table")
        XCTAssertTrue(markdown.contains("| Type |"), "Should contain type information")
        XCTAssertTrue(markdown.contains("| Estimated Duration |"), "Should contain duration information")
        
        // Check for step details
        XCTAssertTrue(markdown.contains("Target:") || markdown.contains("Expected Value:"), "Should contain step details")
        
        print("Markdown Playbook:")
        print(markdown)
    }
    
    func testFormatAsJSON() throws {
        let playbook = try playbookCreator.createPlaybook(from: sampleSummaries)
        let json = try playbookCreator.formatAsJSON(playbook)
        
        XCTAssertFalse(json.isEmpty, "JSON output should not be empty")
        
        // Validate JSON structure
        let jsonData = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNotNil(parsed["id"], "Should contain id")
        XCTAssertNotNil(parsed["title"], "Should contain title")
        XCTAssertNotNil(parsed["description"], "Should contain description")
        XCTAssertNotNil(parsed["type"], "Should contain type")
        XCTAssertNotNil(parsed["steps"], "Should contain steps")
        XCTAssertNotNil(parsed["prerequisites"], "Should contain prerequisites")
        XCTAssertNotNil(parsed["expectedOutcomes"], "Should contain expectedOutcomes")
        XCTAssertNotNil(parsed["estimatedDuration"], "Should contain estimatedDuration")
        XCTAssertNotNil(parsed["difficulty"], "Should contain difficulty")
        
        let steps = parsed["steps"] as! [[String: Any]]
        XCTAssertGreaterThan(steps.count, 0, "Should contain steps array")
        
        for step in steps {
            XCTAssertNotNil(step["id"], "Step should contain id")
            XCTAssertNotNil(step["action"], "Step should contain action")
            XCTAssertNotNil(step["confidence"], "Step should contain confidence")
        }
        
        print("JSON Playbook (first 500 chars):")
        print(String(json.prefix(500)))
    }
    
    func testFormatAsCSV() throws {
        let playbook = try playbookCreator.createPlaybook(from: sampleSummaries)
        let csv = try playbookCreator.formatAsCSV(playbook)
        
        XCTAssertFalse(csv.isEmpty, "CSV output should not be empty")
        
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertGreaterThan(lines.count, 1, "CSV should have header and data rows")
        
        // Check header
        let header = lines.first!
        XCTAssertTrue(header.contains("step_number"), "Should contain step_number column")
        XCTAssertTrue(header.contains("action"), "Should contain action column")
        XCTAssertTrue(header.contains("target"), "Should contain target column")
        XCTAssertTrue(header.contains("expected_value"), "Should contain expected_value column")
        
        // Check data rows
        for i in 1..<lines.count {
            let row = lines[i]
            let columns = row.components(separatedBy: ",")
            XCTAssertGreaterThanOrEqual(columns.count, 5, "Each row should have at least 5 columns")
            
            // First column should be step number
            XCTAssertEqual(columns[0], String(i), "First column should be step number")
        }
        
        print("CSV Playbook:")
        print(csv)
    }
    
    func testFormatAsHTML() throws {
        let playbook = try playbookCreator.createPlaybook(from: sampleSummaries)
        let html = try playbookCreator.formatAsHTML(playbook)
        
        XCTAssertFalse(html.isEmpty, "HTML output should not be empty")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"), "Should be valid HTML")
        XCTAssertTrue(html.contains("<title>"), "Should contain title tag")
        XCTAssertTrue(html.contains("<h1>"), "Should contain main header")
        XCTAssertTrue(html.contains("<h2>Steps</h2>"), "Should contain steps section")
        XCTAssertTrue(html.contains("</html>"), "Should close HTML tag")
        
        // Check for CSS styling
        XCTAssertTrue(html.contains("<style>"), "Should contain CSS styles")
        XCTAssertTrue(html.contains("font-family:"), "Should contain font styling")
        
        // Check for step structure
        XCTAssertTrue(html.contains("class=\"step\""), "Should contain step styling")
        XCTAssertTrue(html.contains("Step 1"), "Should contain step numbering")
        
        print("HTML Playbook (first 1000 chars):")
        print(String(html.prefix(1000)))
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationOptions() throws {
        let config = PlaybookCreator.Configuration(
            minEventsForPlaybook: 5,
            maxStepsInPlaybook: 10,
            includeTiming: false,
            includeConfidence: false,
            groupSimilarActions: false
        )
        
        let creator = PlaybookCreator(configuration: config)
        let playbook = try creator.createPlaybook(from: sampleSummaries)
        
        // Should respect max steps limit
        XCTAssertLessThanOrEqual(playbook.steps.count, 10, "Should respect max steps limit")
        
        // Test markdown output without timing and confidence
        let markdown = try creator.formatAsMarkdown(playbook)
        XCTAssertFalse(markdown.contains("Duration:"), "Should not include timing when disabled")
        XCTAssertFalse(markdown.contains("Confidence:"), "Should not include confidence when disabled")
        
        // Test CSV output without timing and confidence
        let csv = try creator.formatAsCSV(playbook)
        let header = csv.components(separatedBy: "\n").first!
        XCTAssertFalse(header.contains("estimated_duration"), "CSV should not include duration column")
        XCTAssertFalse(header.contains("confidence"), "CSV should not include confidence column")
    }
    
    // MARK: - Error Handling Tests
    
    func testInsufficientDataError() {
        let insufficientSummaries = createInsufficientSummaries()
        
        XCTAssertThrowsError(try playbookCreator.createPlaybook(from: insufficientSummaries)) { error in
            XCTAssertTrue(error is PlaybookCreationError, "Should throw PlaybookCreationError")
            if case PlaybookCreationError.insufficientData(let message) = error {
                XCTAssertTrue(message.contains("enough events"), "Error message should mention insufficient events")
            } else {
                XCTFail("Should throw insufficientData error")
            }
        }
    }
    
    func testEmptyDataError() {
        XCTAssertThrowsError(try playbookCreator.createPlaybook(from: [])) { error in
            XCTAssertTrue(error is PlaybookCreationError, "Should throw PlaybookCreationError")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPlaybookCreationPerformance() {
        let largeSummaries = createLargeSummaries()
        
        measure {
            do {
                _ = try playbookCreator.createPlaybook(from: largeSummaries)
            } catch {
                XCTFail("Playbook creation should not fail: \(error)")
            }
        }
    }
    
    func testMarkdownFormattingPerformance() throws {
        let playbook = try playbookCreator.createPlaybook(from: sampleSummaries)
        
        measure {
            do {
                _ = try playbookCreator.formatAsMarkdown(playbook)
            } catch {
                XCTFail("Markdown formatting should not fail: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSampleSummaries() -> [ActivitySummary] {
        let events1 = [
            ActivityEvent(
                id: "event1",
                timestamp: Date().addingTimeInterval(-3600),
                type: .fieldChange,
                target: "email_field",
                valueBefore: "",
                valueAfter: "user@example.com",
                confidence: 0.95,
                evidenceFrames: ["frame1"]
            ),
            ActivityEvent(
                id: "event2",
                timestamp: Date().addingTimeInterval(-3550),
                type: .fieldChange,
                target: "password_field",
                valueBefore: "",
                valueAfter: "********",
                confidence: 0.90,
                evidenceFrames: ["frame2"]
            ),
            ActivityEvent(
                id: "event3",
                timestamp: Date().addingTimeInterval(-3500),
                type: .click,
                target: "login_button",
                confidence: 0.98,
                evidenceFrames: ["frame3"]
            ),
            ActivityEvent(
                id: "event4",
                timestamp: Date().addingTimeInterval(-3450),
                type: .formSubmission,
                target: "login_form",
                confidence: 0.97,
                evidenceFrames: ["frame4"]
            )
        ]
        
        let session1 = ActivitySession(
            id: "session1",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-3400),
            events: events1,
            primaryApplication: "Safari",
            sessionType: .formFilling
        )
        
        let context1 = TemporalContext(
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: true,
                workflowPhase: "authentication",
                continuityScore: 0.85,
                relatedActivities: ["login"]
            )
        )
        
        let summary1 = ActivitySummary(
            id: "summary1",
            session: session1,
            narrative: "User completed login process",
            keyEvents: events1,
            outcomes: ["Successfully logged in"],
            context: context1,
            confidence: 0.94
        )
        
        return [summary1]
    }
    
    private func createFormFillingSummaries() -> [ActivitySummary] {
        let events = [
            ActivityEvent(id: "e1", timestamp: Date(), type: .fieldChange, target: "name", valueAfter: "John", confidence: 0.9),
            ActivityEvent(id: "e2", timestamp: Date(), type: .fieldChange, target: "email", valueAfter: "john@test.com", confidence: 0.9),
            ActivityEvent(id: "e3", timestamp: Date(), type: .formSubmission, target: "form", confidence: 0.95)
        ]
        
        let session = ActivitySession(
            id: "form_session",
            startTime: Date(),
            endTime: Date().addingTimeInterval(300),
            events: events,
            primaryApplication: "Safari",
            sessionType: .formFilling
        )
        
        return [ActivitySummary(
            session: session,
            narrative: "Form filling",
            keyEvents: events,
            context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: false, continuityScore: 0.8)),
            confidence: 0.9
        )]
    }
    
    private func createDataEntrySummaries() -> [ActivitySummary] {
        let events = [
            ActivityEvent(id: "e1", timestamp: Date(), type: .dataEntry, target: "field1", valueAfter: "data1", confidence: 0.9),
            ActivityEvent(id: "e2", timestamp: Date(), type: .dataEntry, target: "field2", valueAfter: "data2", confidence: 0.9),
            ActivityEvent(id: "e3", timestamp: Date(), type: .dataEntry, target: "field3", valueAfter: "data3", confidence: 0.9)
        ]
        
        let session = ActivitySession(
            id: "data_session",
            startTime: Date(),
            endTime: Date().addingTimeInterval(300),
            events: events,
            primaryApplication: "Excel",
            sessionType: .dataEntry
        )
        
        return [ActivitySummary(
            session: session,
            narrative: "Data entry",
            keyEvents: events,
            context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: false, continuityScore: 0.8)),
            confidence: 0.9
        )]
    }
    
    private func createNavigationSummaries() -> [ActivitySummary] {
        let events = [
            ActivityEvent(id: "e1", timestamp: Date(), type: .navigation, target: "page1", confidence: 0.9),
            ActivityEvent(id: "e2", timestamp: Date(), type: .navigation, target: "page2", confidence: 0.9),
            ActivityEvent(id: "e3", timestamp: Date(), type: .click, target: "menu", confidence: 0.9)
        ]
        
        let session = ActivitySession(
            id: "nav_session",
            startTime: Date(),
            endTime: Date().addingTimeInterval(300),
            events: events,
            primaryApplication: "Safari",
            sessionType: .navigation
        )
        
        return [ActivitySummary(
            session: session,
            narrative: "Navigation",
            keyEvents: events,
            context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: false, continuityScore: 0.8)),
            confidence: 0.9
        )]
    }
    
    private func createBeginnerSummaries() -> [ActivitySummary] {
        let events = [
            ActivityEvent(id: "e1", timestamp: Date(), type: .click, target: "button1", confidence: 0.9),
            ActivityEvent(id: "e2", timestamp: Date(), type: .click, target: "button2", confidence: 0.9),
            ActivityEvent(id: "e3", timestamp: Date(), type: .click, target: "button3", confidence: 0.9)
        ]
        
        let session = ActivitySession(
            id: "beginner_session",
            startTime: Date(),
            endTime: Date().addingTimeInterval(120), // 2 minutes
            events: events,
            primaryApplication: "TestApp",
            sessionType: .navigation
        )
        
        return [ActivitySummary(
            session: session,
            narrative: "Simple navigation",
            keyEvents: events,
            context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: false, continuityScore: 0.8)),
            confidence: 0.9
        )]
    }
    
    private func createAdvancedSummaries() -> [ActivitySummary] {
        let events = (0..<30).map { i in
            ActivityEvent(
                id: "event_\(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i * 10)),
                type: ActivityEventType.allCases.randomElement()!,
                target: "target_\(i)",
                valueAfter: "value_\(i)",
                confidence: 0.9
            )
        }
        
        let session = ActivitySession(
            id: "advanced_session",
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800), // 30 minutes
            events: events,
            primaryApplication: "ComplexApp",
            sessionType: .development
        )
        
        return [ActivitySummary(
            session: session,
            narrative: "Complex workflow",
            keyEvents: Array(events.prefix(10)),
            context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: true, continuityScore: 0.9)),
            confidence: 0.9
        )]
    }
    
    private func createSummariesWithSimilarSteps() -> [ActivitySummary] {
        let events = [
            ActivityEvent(id: "e1", timestamp: Date(), type: .dataEntry, target: "field1", valueAfter: "data1", confidence: 0.9),
            ActivityEvent(id: "e2", timestamp: Date(), type: .dataEntry, target: "field2", valueAfter: "data2", confidence: 0.9),
            ActivityEvent(id: "e3", timestamp: Date(), type: .dataEntry, target: "field3", valueAfter: "data3", confidence: 0.9),
            ActivityEvent(id: "e4", timestamp: Date(), type: .dataEntry, target: "field4", valueAfter: "data4", confidence: 0.9),
            ActivityEvent(id: "e5", timestamp: Date(), type: .formSubmission, target: "form", confidence: 0.95)
        ]
        
        let session = ActivitySession(
            id: "similar_session",
            startTime: Date(),
            endTime: Date().addingTimeInterval(300),
            events: events,
            primaryApplication: "TestApp",
            sessionType: .dataEntry
        )
        
        return [ActivitySummary(
            session: session,
            narrative: "Data entry with similar steps",
            keyEvents: events,
            context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: false, continuityScore: 0.8)),
            confidence: 0.9
        )]
    }
    
    private func createInsufficientSummaries() -> [ActivitySummary] {
        let events = [
            ActivityEvent(id: "e1", timestamp: Date(), type: .click, target: "button", confidence: 0.9)
        ]
        
        let session = ActivitySession(
            id: "insufficient_session",
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            events: events,
            primaryApplication: "TestApp",
            sessionType: .navigation
        )
        
        return [ActivitySummary(
            session: session,
            narrative: "Insufficient data",
            keyEvents: events,
            context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: false, continuityScore: 0.8)),
            confidence: 0.9
        )]
    }
    
    private func createLargeSummaries() -> [ActivitySummary] {
        var summaries: [ActivitySummary] = []
        
        for i in 0..<10 {
            let events = (0..<15).map { j in
                ActivityEvent(
                    id: "event_\(i)_\(j)",
                    timestamp: Date().addingTimeInterval(TimeInterval(i * 300 + j * 10)),
                    type: ActivityEventType.allCases.randomElement()!,
                    target: "target_\(j)",
                    valueAfter: "value_\(j)",
                    confidence: Float.random(in: 0.8...0.99)
                )
            }
            
            let session = ActivitySession(
                id: "session_\(i)",
                startTime: Date().addingTimeInterval(TimeInterval(i * 300)),
                endTime: Date().addingTimeInterval(TimeInterval(i * 300 + 300)),
                events: events,
                primaryApplication: "TestApp",
                sessionType: ActivitySessionType.allCases.randomElement()!
            )
            
            let summary = ActivitySummary(
                session: session,
                narrative: "Large summary \(i)",
                keyEvents: Array(events.prefix(5)),
                context: TemporalContext(workflowContinuity: WorkflowContinuity(isPartOfLargerWorkflow: true, continuityScore: 0.8)),
                confidence: 0.9
            )
            
            summaries.append(summary)
        }
        
        return summaries
    }
}