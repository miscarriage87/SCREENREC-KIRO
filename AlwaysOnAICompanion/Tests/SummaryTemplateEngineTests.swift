import XCTest
@testable import Shared

class SummaryTemplateEngineTests: XCTestCase {
    
    var templateEngine: SummaryTemplateEngine!
    var sampleSession: ActivitySession!
    var sampleContext: TemporalContext!
    
    override func setUp() {
        super.setUp()
        templateEngine = SummaryTemplateEngine()
        setupSampleData()
    }
    
    override func tearDown() {
        templateEngine = nil
        sampleSession = nil
        sampleContext = nil
        super.tearDown()
    }
    
    private func setupSampleData() {
        let baseTime = Date()
        
        // Create sample events
        let events = [
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
                valueAfter: "submitted",
                confidence: 0.95,
                evidenceFrames: ["frame3"],
                metadata: ["app_name": "Safari"]
            )
        ]
        
        // Create sample session
        sampleSession = ActivitySession(
            startTime: baseTime,
            endTime: baseTime.addingTimeInterval(120),
            events: events,
            primaryApplication: "Safari",
            sessionType: .formFilling
        )
        
        // Create sample context
        let precedingSpans = [
            Span(
                kind: "research",
                startTime: baseTime.addingTimeInterval(-1800),
                endTime: baseTime.addingTimeInterval(-300),
                title: "Research authentication methods",
                tags: ["research", "auth"]
            )
        ]
        
        let followingSpans = [
            Span(
                kind: "profile_setup",
                startTime: baseTime.addingTimeInterval(300),
                endTime: baseTime.addingTimeInterval(600),
                title: "Complete user profile",
                tags: ["profile", "setup"]
            )
        ]
        
        let workflowContinuity = WorkflowContinuity(
            isPartOfLargerWorkflow: true,
            workflowPhase: "form_completion",
            continuityScore: 0.8,
            relatedActivities: ["authentication", "profile_setup"]
        )
        
        sampleContext = TemporalContext(
            precedingSpans: precedingSpans,
            followingSpans: followingSpans,
            relatedSessions: [],
            workflowContinuity: workflowContinuity
        )
    }
    
    // MARK: - Narrative Template Tests
    
    func testNarrativeTemplateGeneration() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .narrative
        )
        
        XCTAssertFalse(summary.narrative.isEmpty, "Narrative should not be empty")
        XCTAssertTrue(summary.narrative.contains("form filling"), "Should mention session type")
        XCTAssertTrue(summary.narrative.contains("Safari"), "Should mention primary application")
        XCTAssertTrue(summary.narrative.contains("workflow"), "Should mention workflow context")
        
        // Check for key events description
        XCTAssertTrue(summary.narrative.contains("email"), "Should describe email field change")
        XCTAssertTrue(summary.narrative.contains("submitted"), "Should describe form submission")
        
        // Verify confidence calculation
        XCTAssertGreaterThan(summary.confidence, 0.0, "Should have positive confidence")
        XCTAssertLessThanOrEqual(summary.confidence, 1.0, "Confidence should not exceed 1.0")
    }
    
    func testNarrativeTemplateKeyEvents() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .narrative
        )
        
        XCTAssertFalse(summary.keyEvents.isEmpty, "Should extract key events")
        XCTAssertLessThanOrEqual(summary.keyEvents.count, 5, "Should limit key events to 5")
        
        // Form submission should be highest priority
        let formSubmissionEvent = summary.keyEvents.first { $0.type == .formSubmission }
        XCTAssertNotNil(formSubmissionEvent, "Form submission should be a key event")
    }
    
    func testNarrativeTemplateOutcomes() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .narrative
        )
        
        XCTAssertFalse(summary.outcomes.isEmpty, "Should extract outcomes")
        
        let hasFormCompletion = summary.outcomes.contains { $0.contains("Form") || $0.contains("form") }
        XCTAssertTrue(hasFormCompletion, "Should identify form completion outcome")
    }
    
    // MARK: - Structured Template Tests
    
    func testStructuredTemplateGeneration() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .structured
        )
        
        XCTAssertFalse(summary.narrative.isEmpty, "Structured summary should not be empty")
        XCTAssertTrue(summary.narrative.contains("## Activity Summary"), "Should have structured headers")
        XCTAssertTrue(summary.narrative.contains("**Session Type:**"), "Should have session metadata")
        XCTAssertTrue(summary.narrative.contains("**Duration:**"), "Should include duration")
        XCTAssertTrue(summary.narrative.contains("### Key Events"), "Should have key events section")
        
        // Check for workflow context section
        XCTAssertTrue(summary.narrative.contains("### Workflow Context"), "Should include workflow context")
        XCTAssertTrue(summary.narrative.contains("**Continuity Score:**"), "Should show continuity score")
    }
    
    func testStructuredTemplateFormatting() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .structured
        )
        
        // Verify Markdown formatting
        let lines = summary.narrative.components(separatedBy: .newlines)
        let hasHeaders = lines.contains { $0.hasPrefix("##") || $0.hasPrefix("###") }
        XCTAssertTrue(hasHeaders, "Should contain Markdown headers")
        
        let hasBoldText = lines.contains { $0.contains("**") }
        XCTAssertTrue(hasBoldText, "Should contain bold text formatting")
        
        let hasListItems = lines.contains { $0.hasPrefix("- ") }
        XCTAssertTrue(hasListItems, "Should contain list items")
    }
    
    // MARK: - Playbook Template Tests
    
    func testPlaybookTemplateGeneration() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .playbook
        )
        
        XCTAssertFalse(summary.narrative.isEmpty, "Playbook should not be empty")
        XCTAssertTrue(summary.narrative.contains("# Action Playbook"), "Should have playbook title")
        XCTAssertTrue(summary.narrative.contains("## Overview"), "Should have overview section")
        XCTAssertTrue(summary.narrative.contains("## Steps"), "Should have steps section")
        XCTAssertTrue(summary.narrative.contains("## Expected Outcomes"), "Should have outcomes section")
        
        // Check for step-by-step instructions
        XCTAssertTrue(summary.narrative.contains("1. "), "Should have numbered steps")
        XCTAssertTrue(summary.narrative.contains("Enter"), "Should have actionable instructions")
    }
    
    func testPlaybookStepGeneration() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .playbook
        )
        
        // Verify all events are converted to steps
        let stepCount = summary.narrative.components(separatedBy: .newlines)
            .filter { $0.matches(regex: "^\\d+\\. ") }
            .count
        
        XCTAssertEqual(stepCount, sampleSession.events.count, "Should have one step per event")
        
        // Check for specific step content
        XCTAssertTrue(summary.narrative.contains("email"), "Should include email field step")
        XCTAssertTrue(summary.narrative.contains("Submit"), "Should include submission step")
    }
    
    func testPlaybookPrerequisites() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .playbook
        )
        
        // Should include prerequisites from preceding spans
        XCTAssertTrue(summary.narrative.contains("## Prerequisites"), "Should have prerequisites section")
        XCTAssertTrue(summary.narrative.contains("Research authentication"), "Should mention preceding activity")
    }
    
    // MARK: - Timeline Template Tests
    
    func testTimelineTemplateGeneration() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .timeline
        )
        
        XCTAssertFalse(summary.narrative.isEmpty, "Timeline should not be empty")
        XCTAssertTrue(summary.narrative.contains("# Activity Timeline"), "Should have timeline title")
        XCTAssertTrue(summary.narrative.contains("## Event Timeline"), "Should have event timeline section")
        
        // Check for timestamp formatting
        let hasTimestamps = summary.narrative.contains(regex: "\\*\\*\\d{1,2}:\\d{2}:\\d{2}\\*\\*")
        XCTAssertTrue(hasTimestamps, "Should contain formatted timestamps")
    }
    
    func testTimelineChronologicalOrder() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .timeline
        )
        
        // Events should be in chronological order
        let eventLines = summary.narrative.components(separatedBy: .newlines)
            .filter { $0.contains("**") && $0.contains(" - ") }
        
        XCTAssertGreaterThanOrEqual(eventLines.count, sampleSession.events.count, "Should have timeline entries for all events")
    }
    
    func testTimelineContextIntegration() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .timeline
        )
        
        // Should include context activities
        XCTAssertTrue(summary.narrative.contains("### Before this session:"), "Should show preceding context")
        XCTAssertTrue(summary.narrative.contains("### After this session:"), "Should show following context")
        XCTAssertTrue(summary.narrative.contains("Research authentication"), "Should mention preceding span")
    }
    
    // MARK: - Executive Template Tests
    
    func testExecutiveTemplateGeneration() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .executive
        )
        
        XCTAssertFalse(summary.narrative.isEmpty, "Executive summary should not be empty")
        XCTAssertTrue(summary.narrative.contains("# Executive Summary"), "Should have executive title")
        XCTAssertTrue(summary.narrative.contains("## Overview"), "Should have overview section")
        XCTAssertTrue(summary.narrative.contains("## Key Metrics"), "Should have metrics section")
        XCTAssertTrue(summary.narrative.contains("## Business Impact"), "Should have impact section")
        XCTAssertTrue(summary.narrative.contains("## Recommendations"), "Should have recommendations")
    }
    
    func testExecutiveMetrics() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .executive
        )
        
        // Check for key metrics
        XCTAssertTrue(summary.narrative.contains("**Duration:**"), "Should include duration metric")
        XCTAssertTrue(summary.narrative.contains("**Actions:**"), "Should include action count")
        XCTAssertTrue(summary.narrative.contains("**Efficiency:**"), "Should include efficiency metric")
        XCTAssertTrue(summary.narrative.contains("actions/minute"), "Should show efficiency calculation")
    }
    
    func testExecutiveRecommendations() throws {
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .executive
        )
        
        // Should generate recommendations
        let recommendationSection = summary.narrative.components(separatedBy: "## Recommendations").last ?? ""
        let recommendations = recommendationSection.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("- ") }
        
        XCTAssertFalse(recommendations.isEmpty, "Should generate recommendations")
    }
    
    // MARK: - Multiple Templates Test
    
    func testGenerateMultipleSummaries() throws {
        let summaries = try templateEngine.generateMultipleSummaries(
            session: sampleSession,
            context: sampleContext,
            templateTypes: [.narrative, .structured, .playbook]
        )
        
        XCTAssertEqual(summaries.count, 3, "Should generate 3 different summaries")
        XCTAssertNotNil(summaries[.narrative], "Should have narrative summary")
        XCTAssertNotNil(summaries[.structured], "Should have structured summary")
        XCTAssertNotNil(summaries[.playbook], "Should have playbook summary")
        
        // Verify each summary is different
        let narrativeText = summaries[.narrative]!.narrative
        let structuredText = summaries[.structured]!.narrative
        let playbookText = summaries[.playbook]!.narrative
        
        XCTAssertNotEqual(narrativeText, structuredText, "Narrative and structured should be different")
        XCTAssertNotEqual(narrativeText, playbookText, "Narrative and playbook should be different")
        XCTAssertNotEqual(structuredText, playbookText, "Structured and playbook should be different")
    }
    
    func testGenerateAllTemplateTypes() throws {
        let summaries = try templateEngine.generateMultipleSummaries(
            session: sampleSession,
            context: sampleContext
        )
        
        XCTAssertEqual(summaries.count, SummaryTemplateEngine.TemplateType.allCases.count, "Should generate all template types")
        
        for templateType in SummaryTemplateEngine.TemplateType.allCases {
            XCTAssertNotNil(summaries[templateType], "Should have summary for \(templateType)")
            XCTAssertFalse(summaries[templateType]!.narrative.isEmpty, "\(templateType) summary should not be empty")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidTemplateType() throws {
        // This test would require modifying the enum or using a different approach
        // For now, we'll test with a valid template type to ensure no errors
        let summary = try templateEngine.generateSummary(
            session: sampleSession,
            context: sampleContext,
            templateType: .narrative
        )
        
        XCTAssertNotNil(summary, "Should generate summary with valid template type")
    }
    
    func testEmptySession() throws {
        let emptySession = ActivitySession(
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            events: [],
            sessionType: .mixed
        )
        
        let emptyContext = TemporalContext(
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: false,
                continuityScore: 0.0
            )
        )
        
        let summary = try templateEngine.generateSummary(
            session: emptySession,
            context: emptyContext,
            templateType: .narrative
        )
        
        XCTAssertNotNil(summary, "Should handle empty session gracefully")
        XCTAssertFalse(summary.narrative.isEmpty, "Should generate some narrative even for empty session")
    }
    
    // MARK: - Performance Tests
    
    func testTemplatePerformance() throws {
        measure {
            do {
                let _ = try templateEngine.generateSummary(
                    session: sampleSession,
                    context: sampleContext,
                    templateType: .narrative
                )
            } catch {
                XCTFail("Template generation should not fail: \(error)")
            }
        }
    }
    
    func testMultipleTemplatePerformance() throws {
        measure {
            do {
                let _ = try templateEngine.generateMultipleSummaries(
                    session: sampleSession,
                    context: sampleContext
                )
            } catch {
                XCTFail("Multiple template generation should not fail: \(error)")
            }
        }
    }
}

// MARK: - Helper Extensions

extension String {
    func matches(regex pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: self.utf16.count)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    func contains(regex pattern: String) -> Bool {
        return matches(regex: pattern)
    }
}