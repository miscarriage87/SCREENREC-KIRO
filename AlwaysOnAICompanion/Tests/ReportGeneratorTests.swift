import XCTest
@testable import Shared

class ReportGeneratorTests: XCTestCase {
    
    var reportGenerator: ReportGenerator!
    var sampleReport: ActivityReport!
    var sampleSummaries: [ActivitySummary]!
    
    override func setUp() {
        super.setUp()
        
        reportGenerator = ReportGenerator()
        
        // Create sample data for testing
        sampleSummaries = createSampleSummaries()
        sampleReport = createSampleReport(with: sampleSummaries)
    }
    
    override func tearDown() {
        reportGenerator = nil
        sampleReport = nil
        sampleSummaries = nil
        super.tearDown()
    }
    
    // MARK: - Markdown Report Generation Tests
    
    func testGenerateMarkdownReport() throws {
        let markdown = try reportGenerator.generateReport(
            sampleReport,
            format: .markdown,
            templateType: .narrative
        )
        
        XCTAssertFalse(markdown.isEmpty, "Markdown report should not be empty")
        XCTAssertTrue(markdown.contains("# Activity Report"), "Should contain main header")
        XCTAssertTrue(markdown.contains("## Executive Summary"), "Should contain executive summary")
        XCTAssertTrue(markdown.contains("## Activity Details"), "Should contain activity details")
        XCTAssertTrue(markdown.contains("## Statistics"), "Should contain statistics")
        
        // Check for report metadata
        XCTAssertTrue(markdown.contains("**Report Type:**"), "Should contain report type")
        XCTAssertTrue(markdown.contains("**Time Range:**"), "Should contain time range")
        XCTAssertTrue(markdown.contains("**Duration:**"), "Should contain duration")
        XCTAssertTrue(markdown.contains("**Total Events:**"), "Should contain total events")
        
        // Check for session details
        XCTAssertTrue(markdown.contains("Session 1:"), "Should contain session information")
        
        print("Generated Markdown Report:")
        print(markdown)
    }
    
    func testMarkdownReportWithDifferentTemplates() throws {
        let templates: [SummaryTemplateEngine.TemplateType] = [.narrative, .structured, .timeline, .executive]
        
        for template in templates {
            let markdown = try reportGenerator.generateReport(
                sampleReport,
                format: .markdown,
                templateType: template
            )
            
            XCTAssertFalse(markdown.isEmpty, "Markdown report should not be empty for template: \(template)")
            XCTAssertTrue(markdown.contains("# Activity Report"), "Should contain main header for template: \(template)")
        }
    }
    
    // MARK: - CSV Report Generation Tests
    
    func testGenerateCSVReport() throws {
        let csv = try reportGenerator.generateReport(sampleReport, format: .csv)
        
        XCTAssertFalse(csv.isEmpty, "CSV report should not be empty")
        
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertGreaterThan(lines.count, 1, "CSV should have header and data rows")
        
        // Check header
        let header = lines.first!
        XCTAssertTrue(header.contains("session_id"), "Should contain session_id column")
        XCTAssertTrue(header.contains("session_type"), "Should contain session_type column")
        XCTAssertTrue(header.contains("start_time"), "Should contain start_time column")
        XCTAssertTrue(header.contains("duration_seconds"), "Should contain duration_seconds column")
        XCTAssertTrue(header.contains("confidence_score"), "Should contain confidence_score column")
        
        // Check data rows
        for i in 1..<lines.count {
            let row = lines[i]
            let columns = row.components(separatedBy: ",")
            XCTAssertGreaterThanOrEqual(columns.count, 7, "Each row should have at least 7 columns")
        }
        
        print("Generated CSV Report:")
        print(csv)
    }
    
    func testCSVReportWithoutConfidenceScores() throws {
        let config = ReportGenerator.Configuration(includeConfidenceScores: false)
        let generator = ReportGenerator(configuration: config)
        
        let csv = try generator.generateReport(sampleReport, format: .csv)
        
        let header = csv.components(separatedBy: "\n").first!
        XCTAssertFalse(header.contains("confidence_score"), "Should not contain confidence_score column")
    }
    
    // MARK: - JSON Report Generation Tests
    
    func testGenerateJSONReport() throws {
        let json = try reportGenerator.generateReport(sampleReport, format: .json)
        
        XCTAssertFalse(json.isEmpty, "JSON report should not be empty")
        
        // Validate JSON structure
        let jsonData = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNotNil(parsed["metadata"], "Should contain metadata")
        XCTAssertNotNil(parsed["summaries"], "Should contain summaries")
        
        let metadata = parsed["metadata"] as! [String: Any]
        XCTAssertNotNil(metadata["reportType"], "Metadata should contain reportType")
        XCTAssertNotNil(metadata["totalEvents"], "Metadata should contain totalEvents")
        XCTAssertNotNil(metadata["generatedAt"], "Metadata should contain generatedAt")
        
        let summaries = parsed["summaries"] as! [[String: Any]]
        XCTAssertEqual(summaries.count, sampleSummaries.count, "Should contain correct number of summaries")
        
        for summary in summaries {
            XCTAssertNotNil(summary["id"], "Summary should contain id")
            XCTAssertNotNil(summary["sessionType"], "Summary should contain sessionType")
            XCTAssertNotNil(summary["narrative"], "Summary should contain narrative")
            XCTAssertNotNil(summary["confidence"], "Summary should contain confidence")
        }
        
        print("Generated JSON Report:")
        print(json)
    }
    
    // MARK: - HTML Report Generation Tests
    
    func testGenerateHTMLReport() throws {
        let html = try reportGenerator.generateReport(sampleReport, format: .html)
        
        XCTAssertFalse(html.isEmpty, "HTML report should not be empty")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"), "Should be valid HTML")
        XCTAssertTrue(html.contains("<title>Activity Report</title>"), "Should contain title")
        XCTAssertTrue(html.contains("<h1>Activity Report</h1>"), "Should contain main header")
        XCTAssertTrue(html.contains("Executive Summary"), "Should contain executive summary")
        XCTAssertTrue(html.contains("Activity Details"), "Should contain activity details")
        XCTAssertTrue(html.contains("Statistics"), "Should contain statistics")
        XCTAssertTrue(html.contains("</html>"), "Should close HTML tag")
        
        // Check for CSS styling
        XCTAssertTrue(html.contains("<style>"), "Should contain CSS styles")
        XCTAssertTrue(html.contains("font-family:"), "Should contain font styling")
        
        print("Generated HTML Report (first 500 chars):")
        print(String(html.prefix(500)))
    }
    
    // MARK: - Multiple Format Generation Tests
    
    func testGenerateMultipleFormats() throws {
        let formats: [ReportGenerator.ReportFormat] = [.markdown, .csv, .json]
        let results = try reportGenerator.generateMultipleFormats(
            sampleReport,
            formats: formats
        )
        
        XCTAssertEqual(results.count, formats.count, "Should generate all requested formats")
        
        for format in formats {
            XCTAssertNotNil(results[format], "Should contain result for format: \(format)")
            XCTAssertFalse(results[format]!.isEmpty, "Result should not be empty for format: \(format)")
        }
        
        // Verify format-specific content
        XCTAssertTrue(results[.markdown]!.contains("# Activity Report"), "Markdown should contain header")
        XCTAssertTrue(results[.csv]!.contains("session_id"), "CSV should contain headers")
        XCTAssertTrue(results[.json]!.contains("\"metadata\""), "JSON should contain metadata")
    }
    
    // MARK: - Playbook Generation Tests
    
    func testGeneratePlaybook() throws {
        let playbook = try reportGenerator.generatePlaybook(
            summaries: sampleSummaries,
            format: .markdown
        )
        
        XCTAssertFalse(playbook.isEmpty, "Playbook should not be empty")
        XCTAssertTrue(playbook.contains("# "), "Should contain playbook title")
        XCTAssertTrue(playbook.contains("## Prerequisites"), "Should contain prerequisites section")
        XCTAssertTrue(playbook.contains("## Steps"), "Should contain steps section")
        XCTAssertTrue(playbook.contains("## Expected Outcomes"), "Should contain outcomes section")
        
        // Check for step numbering
        XCTAssertTrue(playbook.contains("1. "), "Should contain numbered steps")
        
        print("Generated Playbook:")
        print(playbook)
    }
    
    func testGeneratePlaybookJSON() throws {
        let playbookJSON = try reportGenerator.generatePlaybook(
            summaries: sampleSummaries,
            format: .json
        )
        
        XCTAssertFalse(playbookJSON.isEmpty, "Playbook JSON should not be empty")
        
        // Validate JSON structure
        let jsonData = playbookJSON.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertNotNil(parsed["title"], "Should contain title")
        XCTAssertNotNil(parsed["steps"], "Should contain steps")
        XCTAssertNotNil(parsed["prerequisites"], "Should contain prerequisites")
        XCTAssertNotNil(parsed["expectedOutcomes"], "Should contain expectedOutcomes")
        
        let steps = parsed["steps"] as! [[String: Any]]
        XCTAssertGreaterThan(steps.count, 0, "Should contain steps")
        
        for step in steps {
            XCTAssertNotNil(step["action"], "Step should contain action")
            XCTAssertNotNil(step["confidence"], "Step should contain confidence")
        }
    }
    
    // MARK: - Configuration Tests
    
    func testReportGenerationWithCustomConfiguration() throws {
        let config = ReportGenerator.Configuration(
            includeEvidence: false,
            maxEventsInReport: 5,
            includeConfidenceScores: false,
            dateFormat: "MM/dd/yyyy HH:mm",
            includeMetadata: false
        )
        
        let generator = ReportGenerator(configuration: config)
        
        let markdown = try generator.generateReport(sampleReport, format: .markdown)
        let csv = try generator.generateReport(sampleReport, format: .csv)
        
        // Check that evidence is not included
        XCTAssertFalse(markdown.contains("#### Evidence"), "Should not contain evidence section")
        
        // Check that confidence scores are not included in CSV
        let csvHeader = csv.components(separatedBy: "\n").first!
        XCTAssertFalse(csvHeader.contains("confidence_score"), "CSV should not contain confidence column")
        
        // Check custom date format in CSV
        let csvLines = csv.components(separatedBy: "\n")
        if csvLines.count > 1 {
            let dataRow = csvLines[1]
            // Should contain date in MM/dd/yyyy format (contains slashes)
            XCTAssertTrue(dataRow.contains("/"), "Should use custom date format with slashes")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testReportGenerationWithEmptyData() throws {
        let emptyReport = ActivityReport(
            timeRange: DateInterval(start: Date(), duration: 3600),
            reportType: .daily,
            summaries: [],
            totalEvents: 0,
            totalDuration: 0,
            generatedAt: Date()
        )
        
        let markdown = try reportGenerator.generateReport(emptyReport, format: .markdown)
        
        XCTAssertFalse(markdown.isEmpty, "Should generate report even with empty data")
        XCTAssertTrue(markdown.contains("# Activity Report"), "Should contain header")
        XCTAssertTrue(markdown.contains("0"), "Should show zero values")
    }
    
    func testPlaybookGenerationWithInsufficientData() {
        // Create summaries with very few events
        let insufficientSummaries = sampleSummaries.map { summary in
            let session = ActivitySession(
                id: summary.session.id,
                startTime: summary.session.startTime,
                endTime: summary.session.endTime,
                events: Array(summary.session.events.prefix(1)), // Only 1 event
                primaryApplication: summary.session.primaryApplication,
                sessionType: summary.session.sessionType
            )
            
            return ActivitySummary(
                id: summary.id,
                session: session,
                narrative: summary.narrative,
                keyEvents: summary.keyEvents,
                outcomes: summary.outcomes,
                context: summary.context,
                confidence: summary.confidence
            )
        }
        
        XCTAssertThrowsError(try reportGenerator.generatePlaybook(summaries: insufficientSummaries)) { error in
            XCTAssertTrue(error is PlaybookCreationError, "Should throw PlaybookCreationError")
        }
    }
    
    // MARK: - Performance Tests
    
    func testReportGenerationPerformance() {
        // Create larger dataset
        let largeReport = createLargeReport()
        
        measure {
            do {
                _ = try reportGenerator.generateReport(largeReport, format: .markdown)
            } catch {
                XCTFail("Report generation should not fail: \(error)")
            }
        }
    }
    
    func testMultipleFormatGenerationPerformance() {
        measure {
            do {
                _ = try reportGenerator.generateMultipleFormats(sampleReport)
            } catch {
                XCTFail("Multiple format generation should not fail: \(error)")
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
                target: "username",
                valueBefore: "",
                valueAfter: "john.doe",
                confidence: 0.95,
                evidenceFrames: ["frame1", "frame2"]
            ),
            ActivityEvent(
                id: "event2",
                timestamp: Date().addingTimeInterval(-3550),
                type: .fieldChange,
                target: "password",
                valueBefore: "",
                valueAfter: "********",
                confidence: 0.90,
                evidenceFrames: ["frame3"]
            ),
            ActivityEvent(
                id: "event3",
                timestamp: Date().addingTimeInterval(-3500),
                type: .formSubmission,
                target: "login_form",
                confidence: 0.98,
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
                relatedActivities: ["login", "authentication"]
            )
        )
        
        let summary1 = ActivitySummary(
            id: "summary1",
            session: session1,
            narrative: "User completed login form by entering username and password, then submitted the form.",
            keyEvents: events1,
            outcomes: ["Successfully logged in", "Authentication completed"],
            context: context1,
            confidence: 0.94
        )
        
        // Create second summary
        let events2 = [
            ActivityEvent(
                id: "event4",
                timestamp: Date().addingTimeInterval(-3300),
                type: .navigation,
                target: "dashboard",
                confidence: 0.92,
                evidenceFrames: ["frame5"]
            ),
            ActivityEvent(
                id: "event5",
                timestamp: Date().addingTimeInterval(-3200),
                type: .click,
                target: "settings_button",
                confidence: 0.88,
                evidenceFrames: ["frame6"]
            )
        ]
        
        let session2 = ActivitySession(
            id: "session2",
            startTime: Date().addingTimeInterval(-3300),
            endTime: Date().addingTimeInterval(-3100),
            events: events2,
            primaryApplication: "Safari",
            sessionType: .navigation
        )
        
        let context2 = TemporalContext(
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: true,
                workflowPhase: "navigation",
                continuityScore: 0.75,
                relatedActivities: ["dashboard", "settings"]
            )
        )
        
        let summary2 = ActivitySummary(
            id: "summary2",
            session: session2,
            narrative: "User navigated to dashboard and accessed settings.",
            keyEvents: events2,
            outcomes: ["Reached dashboard", "Accessed settings"],
            context: context2,
            confidence: 0.90
        )
        
        return [summary1, summary2]
    }
    
    private func createSampleReport(with summaries: [ActivitySummary]) -> ActivityReport {
        let totalEvents = summaries.reduce(0) { $0 + $1.session.events.count }
        let totalDuration = summaries.reduce(0) { $0 + $1.session.duration }
        
        return ActivityReport(
            timeRange: DateInterval(start: Date().addingTimeInterval(-3600), duration: 3600),
            reportType: .daily,
            summaries: summaries,
            totalEvents: totalEvents,
            totalDuration: totalDuration,
            generatedAt: Date()
        )
    }
    
    private func createLargeReport() -> ActivityReport {
        var largeSummaries: [ActivitySummary] = []
        
        for i in 0..<20 {
            let events = (0..<10).map { j in
                ActivityEvent(
                    id: "event_\(i)_\(j)",
                    timestamp: Date().addingTimeInterval(TimeInterval(-3600 + i * 60 + j * 5)),
                    type: ActivityEventType.allCases.randomElement()!,
                    target: "target_\(j)",
                    valueBefore: "before_\(j)",
                    valueAfter: "after_\(j)",
                    confidence: Float.random(in: 0.7...0.99),
                    evidenceFrames: ["frame_\(i)_\(j)"]
                )
            }
            
            let session = ActivitySession(
                id: "session_\(i)",
                startTime: Date().addingTimeInterval(TimeInterval(-3600 + i * 60)),
                endTime: Date().addingTimeInterval(TimeInterval(-3600 + i * 60 + 300)),
                events: events,
                primaryApplication: "TestApp",
                sessionType: ActivitySessionType.allCases.randomElement()!
            )
            
            let context = TemporalContext(
                workflowContinuity: WorkflowContinuity(
                    isPartOfLargerWorkflow: true,
                    continuityScore: Float.random(in: 0.5...0.95)
                )
            )
            
            let summary = ActivitySummary(
                id: "summary_\(i)",
                session: session,
                narrative: "Test narrative for session \(i)",
                keyEvents: Array(events.prefix(3)),
                outcomes: ["Outcome \(i)"],
                context: context,
                confidence: Float.random(in: 0.8...0.98)
            )
            
            largeSummaries.append(summary)
        }
        
        let totalEvents = largeSummaries.reduce(0) { $0 + $1.session.events.count }
        let totalDuration = largeSummaries.reduce(0) { $0 + $1.session.duration }
        
        return ActivityReport(
            timeRange: DateInterval(start: Date().addingTimeInterval(-3600), duration: 3600),
            reportType: .daily,
            summaries: largeSummaries,
            totalEvents: totalEvents,
            totalDuration: totalDuration,
            generatedAt: Date()
        )
    }
}