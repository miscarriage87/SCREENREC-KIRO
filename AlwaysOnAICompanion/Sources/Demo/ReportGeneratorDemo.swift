import Foundation
import Shared

/// Demo application showcasing the ReportGenerator and PlaybookCreator functionality
public class ReportGeneratorDemo {
    
    private let reportGenerator: ReportGenerator
    private let playbookCreator: PlaybookCreator
    
    public init() {
        // Configure report generator with comprehensive settings
        let reportConfig = ReportGenerator.Configuration(
            includeEvidence: true,
            maxEventsInReport: 50,
            includeConfidenceScores: true,
            dateFormat: "yyyy-MM-dd HH:mm:ss",
            includeMetadata: true
        )
        
        // Configure playbook creator with detailed settings
        let playbookConfig = PlaybookCreator.Configuration(
            minEventsForPlaybook: 3,
            maxStepsInPlaybook: 25,
            includeTiming: true,
            includeConfidence: true,
            groupSimilarActions: true
        )
        
        self.reportGenerator = ReportGenerator(configuration: reportConfig)
        self.playbookCreator = PlaybookCreator(configuration: playbookConfig)
    }
    
    /// Run the complete demo showcasing all report generation features
    public func runDemo() {
        print("🚀 Report Generator Demo")
        print("=" * 50)
        
        do {
            // Create sample data
            let sampleReport = createSampleActivityReport()
            
            // Demonstrate different report formats
            try demonstrateMarkdownReports(sampleReport)
            try demonstrateCSVReports(sampleReport)
            try demonstrateJSONReports(sampleReport)
            try demonstrateHTMLReports(sampleReport)
            
            // Demonstrate playbook generation
            try demonstratePlaybookGeneration(sampleReport.summaries)
            
            // Demonstrate multi-format generation
            try demonstrateMultiFormatGeneration(sampleReport)
            
            // Demonstrate customization options
            try demonstrateCustomization()
            
            print("\n✅ Demo completed successfully!")
            
        } catch {
            print("❌ Demo failed with error: \(error)")
        }
    }
    
    // MARK: - Report Format Demonstrations
    
    private func demonstrateMarkdownReports(_ report: ActivityReport) throws {
        print("\n📝 Markdown Report Generation")
        print("-" * 30)
        
        // Generate narrative markdown report
        let narrativeMarkdown = try reportGenerator.generateReport(
            report,
            format: .markdown,
            templateType: .narrative
        )
        
        print("Narrative Markdown Report (first 500 chars):")
        print(String(narrativeMarkdown.prefix(500)) + "...")
        
        // Generate structured markdown report
        let structuredMarkdown = try reportGenerator.generateReport(
            report,
            format: .markdown,
            templateType: .structured
        )
        
        print("\nStructured Markdown Report (first 300 chars):")
        print(String(structuredMarkdown.prefix(300)) + "...")
        
        // Generate executive summary
        let executiveMarkdown = try reportGenerator.generateReport(
            report,
            format: .markdown,
            templateType: .executive
        )
        
        print("\nExecutive Summary (first 300 chars):")
        print(String(executiveMarkdown.prefix(300)) + "...")
    }
    
    private func demonstrateCSVReports(_ report: ActivityReport) throws {
        print("\n📊 CSV Report Generation")
        print("-" * 30)
        
        let csv = try reportGenerator.generateReport(report, format: .csv)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        print("CSV Report (\(lines.count) rows):")
        print("Header: \(lines.first ?? "No header")")
        
        if lines.count > 1 {
            print("Sample data row: \(lines[1])")
        }
        
        if lines.count > 2 {
            print("... and \(lines.count - 2) more rows")
        }
    }
    
    private func demonstrateJSONReports(_ report: ActivityReport) throws {
        print("\n🔧 JSON Report Generation")
        print("-" * 30)
        
        let json = try reportGenerator.generateReport(report, format: .json)
        
        // Parse and display structure
        if let jsonData = json.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            print("JSON Report Structure:")
            print("- Metadata keys: \((parsed["metadata"] as? [String: Any])?.keys.joined(separator: ", ") ?? "none")")
            
            if let summaries = parsed["summaries"] as? [[String: Any]] {
                print("- Summaries count: \(summaries.count)")
                if let firstSummary = summaries.first {
                    print("- Summary keys: \(firstSummary.keys.joined(separator: ", "))")
                }
            }
        }
        
        print("JSON size: \(json.count) characters")
    }
    
    private func demonstrateHTMLReports(_ report: ActivityReport) throws {
        print("\n🌐 HTML Report Generation")
        print("-" * 30)
        
        let html = try reportGenerator.generateReport(report, format: .html)
        
        print("HTML Report generated:")
        print("- Size: \(html.count) characters")
        print("- Contains DOCTYPE: \(html.contains("<!DOCTYPE html>"))")
        print("- Contains CSS: \(html.contains("<style>"))")
        print("- Contains JavaScript: \(html.contains("<script>"))")
        
        // Extract title
        if let titleRange = html.range(of: "<title>"),
           let titleEndRange = html.range(of: "</title>", range: titleRange.upperBound..<html.endIndex) {
            let title = String(html[titleRange.upperBound..<titleEndRange.lowerBound])
            print("- Title: \(title)")
        }
    }
    
    // MARK: - Playbook Demonstrations
    
    private func demonstratePlaybookGeneration(_ summaries: [ActivitySummary]) throws {
        print("\n📋 Playbook Generation")
        print("-" * 30)
        
        // Generate comprehensive playbook
        let playbook = try playbookCreator.createPlaybook(from: summaries)
        
        print("Generated Playbook:")
        print("- Title: \(playbook.title)")
        print("- Type: \(playbook.type.rawValue)")
        print("- Difficulty: \(playbook.difficulty.rawValue)")
        print("- Steps: \(playbook.steps.count)")
        print("- Prerequisites: \(playbook.prerequisites.count)")
        print("- Expected Outcomes: \(playbook.expectedOutcomes.count)")
        print("- Estimated Duration: \(formatDuration(playbook.estimatedDuration))")
        
        // Show first few steps
        print("\nFirst 3 steps:")
        for (index, step) in playbook.steps.prefix(3).enumerated() {
            print("\(index + 1). \(step.action)")
            if let target = step.target {
                print("   Target: \(target)")
            }
            if let value = step.expectedValue {
                print("   Expected: \(value)")
            }
        }
        
        // Demonstrate different playbook formats
        try demonstratePlaybookFormats(playbook)
    }
    
    private func demonstratePlaybookFormats(_ playbook: Playbook) throws {
        print("\n📄 Playbook Format Demonstrations")
        print("-" * 30)
        
        // Markdown format
        let markdown = try playbookCreator.formatAsMarkdown(playbook)
        print("Markdown Playbook (first 200 chars):")
        print(String(markdown.prefix(200)) + "...")
        
        // JSON format
        let json = try playbookCreator.formatAsJSON(playbook)
        print("\nJSON Playbook size: \(json.count) characters")
        
        // CSV format
        let csv = try playbookCreator.formatAsCSV(playbook)
        let csvLines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        print("CSV Playbook: \(csvLines.count) rows")
        
        // HTML format
        let html = try playbookCreator.formatAsHTML(playbook)
        print("HTML Playbook size: \(html.count) characters")
    }
    
    // MARK: - Multi-Format and Customization Demonstrations
    
    private func demonstrateMultiFormatGeneration(_ report: ActivityReport) throws {
        print("\n🔄 Multi-Format Generation")
        print("-" * 30)
        
        let formats: [ReportGenerator.ReportFormat] = [.markdown, .csv, .json, .html]
        let results = try reportGenerator.generateMultipleFormats(
            report,
            formats: formats,
            templateType: .narrative
        )
        
        print("Generated \(results.count) formats simultaneously:")
        for (format, content) in results {
            print("- \(format.rawValue): \(content.count) characters")
        }
        
        // Demonstrate playbook multi-format
        let playbookMarkdown = try reportGenerator.generatePlaybook(
            summaries: report.summaries,
            format: .markdown
        )
        
        let playbookJSON = try reportGenerator.generatePlaybook(
            summaries: report.summaries,
            format: .json
        )
        
        print("\nPlaybook formats:")
        print("- Markdown: \(playbookMarkdown.count) characters")
        print("- JSON: \(playbookJSON.count) characters")
    }
    
    private func demonstrateCustomization() throws {
        print("\n⚙️ Customization Options")
        print("-" * 30)
        
        // Create custom configurations
        let minimalConfig = ReportGenerator.Configuration(
            includeEvidence: false,
            maxEventsInReport: 10,
            includeConfidenceScores: false,
            dateFormat: "MM/dd/yyyy",
            includeMetadata: false
        )
        
        let detailedConfig = ReportGenerator.Configuration(
            includeEvidence: true,
            maxEventsInReport: 100,
            includeConfidenceScores: true,
            dateFormat: "yyyy-MM-dd HH:mm:ss.SSS",
            includeMetadata: true
        )
        
        let sampleReport = createSampleActivityReport()
        
        // Generate reports with different configurations
        let minimalGenerator = ReportGenerator(configuration: minimalConfig)
        let detailedGenerator = ReportGenerator(configuration: detailedConfig)
        
        let minimalMarkdown = try minimalGenerator.generateReport(sampleReport, format: .markdown)
        let detailedMarkdown = try detailedGenerator.generateReport(sampleReport, format: .markdown)
        
        print("Configuration comparison:")
        print("- Minimal config report: \(minimalMarkdown.count) characters")
        print("- Detailed config report: \(detailedMarkdown.count) characters")
        print("- Size difference: \(detailedMarkdown.count - minimalMarkdown.count) characters")
        
        // Demonstrate playbook customization
        let quickPlaybookConfig = PlaybookCreator.Configuration(
            minEventsForPlaybook: 2,
            maxStepsInPlaybook: 5,
            includeTiming: false,
            includeConfidence: false,
            groupSimilarActions: true
        )
        
        let quickPlaybookCreator = PlaybookCreator(configuration: quickPlaybookConfig)
        let quickPlaybook = try quickPlaybookCreator.createPlaybook(from: sampleReport.summaries)
        
        print("\nPlaybook customization:")
        print("- Standard playbook steps: \(try playbookCreator.createPlaybook(from: sampleReport.summaries).steps.count)")
        print("- Quick playbook steps: \(quickPlaybook.steps.count)")
    }
    
    // MARK: - Sample Data Creation
    
    private func createSampleActivityReport() -> ActivityReport {
        let summaries = createSampleSummaries()
        let totalEvents = summaries.reduce(0) { $0 + $1.session.events.count }
        let totalDuration = summaries.reduce(0) { $0 + $1.session.duration }
        
        return ActivityReport(
            timeRange: DateInterval(start: Date().addingTimeInterval(-7200), duration: 7200),
            reportType: .daily,
            summaries: summaries,
            totalEvents: totalEvents,
            totalDuration: totalDuration,
            generatedAt: Date()
        )
    }
    
    private func createSampleSummaries() -> [ActivitySummary] {
        // Create a comprehensive set of sample summaries for demonstration
        
        // Summary 1: Form filling workflow
        let formEvents = [
            ActivityEvent(
                id: "form_1",
                timestamp: Date().addingTimeInterval(-7200),
                type: .fieldChange,
                target: "customer_name",
                valueBefore: "",
                valueAfter: "John Smith",
                confidence: 0.95,
                evidenceFrames: ["frame_001", "frame_002"],
                metadata: ["field_type": "text", "form_section": "personal_info"]
            ),
            ActivityEvent(
                id: "form_2",
                timestamp: Date().addingTimeInterval(-7150),
                type: .fieldChange,
                target: "email_address",
                valueBefore: "",
                valueAfter: "john.smith@company.com",
                confidence: 0.92,
                evidenceFrames: ["frame_003"],
                metadata: ["field_type": "email", "validation": "passed"]
            ),
            ActivityEvent(
                id: "form_3",
                timestamp: Date().addingTimeInterval(-7100),
                type: .fieldChange,
                target: "phone_number",
                valueBefore: "",
                valueAfter: "(555) 123-4567",
                confidence: 0.88,
                evidenceFrames: ["frame_004"],
                metadata: ["field_type": "phone", "format": "us"]
            ),
            ActivityEvent(
                id: "form_4",
                timestamp: Date().addingTimeInterval(-7050),
                type: .formSubmission,
                target: "customer_form",
                confidence: 0.97,
                evidenceFrames: ["frame_005"],
                metadata: ["form_id": "cust_001", "validation": "success"]
            )
        ]
        
        let formSession = ActivitySession(
            id: "session_form",
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-7000),
            events: formEvents,
            primaryApplication: "Salesforce",
            sessionType: .formFilling
        )
        
        let formContext = TemporalContext(
            precedingSpans: [
                Span(
                    spanId: "span_prep",
                    kind: "preparation",
                    startTime: Date().addingTimeInterval(-7500),
                    endTime: Date().addingTimeInterval(-7200),
                    title: "Customer data preparation",
                    summaryMarkdown: "Gathered customer information from various sources"
                )
            ],
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: true,
                workflowPhase: "data_entry",
                continuityScore: 0.89,
                relatedActivities: ["customer_onboarding", "data_validation"]
            )
        )
        
        let formSummary = ActivitySummary(
            id: "summary_form",
            session: formSession,
            narrative: "Completed customer information form in Salesforce by entering personal details including name, email, and phone number, then successfully submitted the form for processing.",
            keyEvents: formEvents,
            outcomes: [
                "Customer record created successfully",
                "All required fields completed",
                "Form validation passed"
            ],
            context: formContext,
            confidence: 0.93
        )
        
        // Summary 2: Navigation and research workflow
        let navEvents = [
            ActivityEvent(
                id: "nav_1",
                timestamp: Date().addingTimeInterval(-6800),
                type: .navigation,
                target: "customer_dashboard",
                confidence: 0.94,
                evidenceFrames: ["frame_006"],
                metadata: ["page_type": "dashboard", "load_time": "2.3s"]
            ),
            ActivityEvent(
                id: "nav_2",
                timestamp: Date().addingTimeInterval(-6750),
                type: .click,
                target: "search_button",
                confidence: 0.91,
                evidenceFrames: ["frame_007"],
                metadata: ["element_type": "button", "action": "search"]
            ),
            ActivityEvent(
                id: "nav_3",
                timestamp: Date().addingTimeInterval(-6700),
                type: .dataEntry,
                target: "search_field",
                valueAfter: "John Smith",
                confidence: 0.89,
                evidenceFrames: ["frame_008"],
                metadata: ["search_type": "customer_name"]
            ),
            ActivityEvent(
                id: "nav_4",
                timestamp: Date().addingTimeInterval(-6650),
                type: .click,
                target: "customer_record_link",
                confidence: 0.96,
                evidenceFrames: ["frame_009"],
                metadata: ["record_id": "cust_001", "action": "view_details"]
            )
        ]
        
        let navSession = ActivitySession(
            id: "session_nav",
            startTime: Date().addingTimeInterval(-6800),
            endTime: Date().addingTimeInterval(-6600),
            events: navEvents,
            primaryApplication: "Salesforce",
            sessionType: .research
        )
        
        let navContext = TemporalContext(
            precedingSpans: [formSummary.session].map { session in
                Span(
                    spanId: session.id,
                    kind: "form_filling",
                    startTime: session.startTime,
                    endTime: session.endTime,
                    title: "Customer form completion"
                )
            },
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: true,
                workflowPhase: "verification",
                continuityScore: 0.92,
                relatedActivities: ["customer_lookup", "data_verification"]
            )
        )
        
        let navSummary = ActivitySummary(
            id: "summary_nav",
            session: navSession,
            narrative: "Navigated to customer dashboard and performed search to locate the newly created customer record, then accessed the detailed customer information page for verification.",
            keyEvents: navEvents,
            outcomes: [
                "Successfully located customer record",
                "Verified data accuracy",
                "Accessed detailed customer view"
            ],
            context: navContext,
            confidence: 0.92
        )
        
        // Summary 3: Error handling and resolution
        let errorEvents = [
            ActivityEvent(
                id: "error_1",
                timestamp: Date().addingTimeInterval(-6400),
                type: .errorDisplay,
                target: "validation_error",
                valueAfter: "Phone number format invalid",
                confidence: 0.97,
                evidenceFrames: ["frame_010"],
                metadata: ["error_type": "validation", "field": "phone_number"]
            ),
            ActivityEvent(
                id: "error_2",
                timestamp: Date().addingTimeInterval(-6350),
                type: .click,
                target: "edit_button",
                confidence: 0.93,
                evidenceFrames: ["frame_011"],
                metadata: ["action": "edit_record"]
            ),
            ActivityEvent(
                id: "error_3",
                timestamp: Date().addingTimeInterval(-6300),
                type: .fieldChange,
                target: "phone_number",
                valueBefore: "(555) 123-4567",
                valueAfter: "+1-555-123-4567",
                confidence: 0.91,
                evidenceFrames: ["frame_012"],
                metadata: ["correction": "format_update"]
            ),
            ActivityEvent(
                id: "error_4",
                timestamp: Date().addingTimeInterval(-6250),
                type: .click,
                target: "save_button",
                confidence: 0.95,
                evidenceFrames: ["frame_013"],
                metadata: ["action": "save_changes"]
            )
        ]
        
        let errorSession = ActivitySession(
            id: "session_error",
            startTime: Date().addingTimeInterval(-6400),
            endTime: Date().addingTimeInterval(-6200),
            events: errorEvents,
            primaryApplication: "Salesforce",
            sessionType: .mixed
        )
        
        let errorContext = TemporalContext(
            precedingSpans: [navSummary.session].map { session in
                Span(
                    spanId: session.id,
                    kind: "research",
                    startTime: session.startTime,
                    endTime: session.endTime,
                    title: "Customer record lookup"
                )
            },
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: true,
                workflowPhase: "error_resolution",
                continuityScore: 0.87,
                relatedActivities: ["error_handling", "data_correction"]
            )
        )
        
        let errorSummary = ActivitySummary(
            id: "summary_error",
            session: errorSession,
            narrative: "Encountered phone number validation error during record review, accessed edit mode to correct the format from standard US format to international format, and successfully saved the updated information.",
            keyEvents: errorEvents,
            outcomes: [
                "Validation error resolved",
                "Phone number format corrected",
                "Customer record updated successfully"
            ],
            context: errorContext,
            confidence: 0.94
        )
        
        return [formSummary, navSummary, errorSummary]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - String Extension for Repetition

private extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}