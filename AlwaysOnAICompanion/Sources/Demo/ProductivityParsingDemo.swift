import Foundation
import CoreGraphics

/// Demo showcasing enhanced productivity tool parsing capabilities
public class ProductivityParsingDemo {
    
    private let plugin: ProductivityParsingPlugin
    
    public init() {
        self.plugin = ProductivityParsingPlugin()
        
        // Initialize plugin with demo configuration
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProductivityParsingDemo")
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        try? plugin.initialize(configuration: config)
    }
    
    // MARK: - Demo Methods
    
    /// Demonstrates Jira ticket management and workflow tracking
    public func demonstrateJiraWorkflowTracking() async {
        print("🎯 Jira Workflow Tracking Demo")
        print("=" * 50)
        
        // Simulate Jira board view with workflow transitions
        let jiraResults = [
            OCRResult(text: "PROJ-123", boundingBox: CGRect(x: 10, y: 10, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "Bug: Login fails on mobile", boundingBox: CGRect(x: 100, y: 10, width: 200, height: 20), confidence: 0.9),
            OCRResult(text: "To Do", boundingBox: CGRect(x: 10, y: 50, width: 60, height: 25), confidence: 0.9),
            OCRResult(text: "In Progress", boundingBox: CGRect(x: 80, y: 50, width: 90, height: 25), confidence: 0.9),
            OCRResult(text: "Code Review", boundingBox: CGRect(x: 180, y: 50, width: 100, height: 25), confidence: 0.9),
            OCRResult(text: "Done", boundingBox: CGRect(x: 290, y: 50, width: 50, height: 25), confidence: 0.95),
            OCRResult(text: "Start Progress", boundingBox: CGRect(x: 10, y: 90, width: 100, height: 30), confidence: 0.9),
            OCRResult(text: "Epic: Mobile App Improvements", boundingBox: CGRect(x: 10, y: 130, width: 220, height: 20), confidence: 0.9),
            OCRResult(text: "Story Points: 5", boundingBox: CGRect(x: 10, y: 160, width: 100, height: 20), confidence: 0.9),
            OCRResult(text: "Sprint 23", boundingBox: CGRect(x: 10, y: 190, width: 70, height: 20), confidence: 0.9)
        ]
        
        let jiraContext = ApplicationContext(
            bundleID: "com.atlassian.jira",
            applicationName: "Jira",
            windowTitle: "PROJ - Kanban Board",
            processID: 1234
        )
        
        await demonstrateParsingResults(
            results: jiraResults,
            context: jiraContext,
            title: "Jira Issue and Workflow Detection"
        )
    }
    
    /// Demonstrates Salesforce CRM data and process flow parsing
    public func demonstrateSalesforceWorkflowParsing() async {
        print("\n💼 Salesforce CRM Workflow Demo")
        print("=" * 50)
        
        // Simulate Salesforce opportunity pipeline
        let salesforceResults = [
            OCRResult(text: "0063000000ABC123", boundingBox: CGRect(x: 10, y: 10, width: 120, height: 20), confidence: 0.95),
            OCRResult(text: "Acme Corp - Q4 Deal", boundingBox: CGRect(x: 140, y: 10, width: 150, height: 20), confidence: 0.9),
            OCRResult(text: "Prospecting", boundingBox: CGRect(x: 10, y: 50, width: 90, height: 25), confidence: 0.9),
            OCRResult(text: "Qualification", boundingBox: CGRect(x: 110, y: 50, width: 100, height: 25), confidence: 0.9),
            OCRResult(text: "Proposal", boundingBox: CGRect(x: 220, y: 50, width: 80, height: 25), confidence: 0.9),
            OCRResult(text: "Closed Won", boundingBox: CGRect(x: 310, y: 50, width: 80, height: 25), confidence: 0.95),
            OCRResult(text: "$50,000", boundingBox: CGRect(x: 10, y: 90, width: 70, height: 20), confidence: 0.95),
            OCRResult(text: "Pending Approval", boundingBox: CGRect(x: 10, y: 120, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "Territory: West Coast", boundingBox: CGRect(x: 10, y: 150, width: 140, height: 20), confidence: 0.9),
            OCRResult(text: "Lead Source: Website", boundingBox: CGRect(x: 10, y: 180, width: 130, height: 20), confidence: 0.9)
        ]
        
        let salesforceContext = ApplicationContext(
            bundleID: "com.salesforce.lightning",
            applicationName: "Salesforce",
            windowTitle: "Opportunity Pipeline - Lightning Experience",
            processID: 5678
        )
        
        await demonstrateParsingResults(
            results: salesforceResults,
            context: salesforceContext,
            title: "Salesforce Opportunity and Workflow Detection"
        )
    }
    
    /// Demonstrates Slack communication and collaboration parsing
    public func demonstrateSlackCollaborationParsing() async {
        print("\n💬 Slack Collaboration Demo")
        print("=" * 50)
        
        // Simulate Slack workspace with channels and mentions
        let slackResults = [
            OCRResult(text: "#general", boundingBox: CGRect(x: 10, y: 10, width: 70, height: 20), confidence: 0.95),
            OCRResult(text: "#dev-team", boundingBox: CGRect(x: 10, y: 40, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "🔒 #leadership", boundingBox: CGRect(x: 10, y: 70, width: 100, height: 20), confidence: 0.9),
            OCRResult(text: "@john.doe can you review this?", boundingBox: CGRect(x: 10, y: 110, width: 200, height: 20), confidence: 0.9),
            OCRResult(text: "@channel meeting in 5 minutes", boundingBox: CGRect(x: 10, y: 140, width: 180, height: 20), confidence: 0.9),
            OCRResult(text: "3 replies", boundingBox: CGRect(x: 10, y: 170, width: 70, height: 20), confidence: 0.9),
            OCRResult(text: "Started a thread", boundingBox: CGRect(x: 10, y: 200, width: 110, height: 20), confidence: 0.9)
        ]
        
        let slackContext = ApplicationContext(
            bundleID: "com.tinyspeck.slackmacgap",
            applicationName: "Slack",
            windowTitle: "Slack - Engineering Team",
            processID: 9012
        )
        
        await demonstrateParsingResults(
            results: slackResults,
            context: slackContext,
            title: "Slack Channel and Communication Detection"
        )
    }
    
    /// Demonstrates Notion knowledge management parsing
    public func demonstrateNotionKnowledgeManagement() async {
        print("\n📝 Notion Knowledge Management Demo")
        print("=" * 50)
        
        // Simulate Notion database and page hierarchy
        let notionResults = [
            OCRResult(text: "▶ Project Documentation", boundingBox: CGRect(x: 10, y: 10, width: 180, height: 20), confidence: 0.9),
            OCRResult(text: "  ├ Requirements", boundingBox: CGRect(x: 30, y: 40, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "  ├ Design Specs", boundingBox: CGRect(x: 30, y: 70, width: 110, height: 20), confidence: 0.9),
            OCRResult(text: "  └ Implementation", boundingBox: CGRect(x: 30, y: 100, width: 130, height: 20), confidence: 0.9),
            OCRResult(text: "Status", boundingBox: CGRect(x: 10, y: 140, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "In Progress", boundingBox: CGRect(x: 70, y: 140, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "Assignee", boundingBox: CGRect(x: 10, y: 170, width: 70, height: 20), confidence: 0.9),
            OCRResult(text: "John Smith", boundingBox: CGRect(x: 90, y: 170, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "Due Date", boundingBox: CGRect(x: 10, y: 200, width: 70, height: 20), confidence: 0.9),
            OCRResult(text: "Dec 15, 2024", boundingBox: CGRect(x: 90, y: 200, width: 90, height: 20), confidence: 0.9)
        ]
        
        let notionContext = ApplicationContext(
            bundleID: "notion.id",
            applicationName: "Notion",
            windowTitle: "Project Database - Notion",
            processID: 3456
        )
        
        await demonstrateParsingResults(
            results: notionResults,
            context: notionContext,
            title: "Notion Database and Hierarchy Detection"
        )
    }
    
    /// Demonstrates Asana project management parsing
    public func demonstrateAsanaProjectManagement() async {
        print("\n📋 Asana Project Management Demo")
        print("=" * 50)
        
        // Simulate Asana project board with tasks and dependencies
        let asanaResults = [
            OCRResult(text: "TO DO", boundingBox: CGRect(x: 10, y: 10, width: 60, height: 25), confidence: 0.9),
            OCRResult(text: "IN PROGRESS", boundingBox: CGRect(x: 80, y: 10, width: 100, height: 25), confidence: 0.9),
            OCRResult(text: "REVIEW", boundingBox: CGRect(x: 190, y: 10, width: 60, height: 25), confidence: 0.9),
            OCRResult(text: "DONE", boundingBox: CGRect(x: 260, y: 10, width: 50, height: 25), confidence: 0.95),
            OCRResult(text: "Design new homepage", boundingBox: CGRect(x: 10, y: 50, width: 150, height: 20), confidence: 0.9),
            OCRResult(text: "Depends on: User research", boundingBox: CGRect(x: 10, y: 80, width: 170, height: 20), confidence: 0.9),
            OCRResult(text: "Blocked by: Legal approval", boundingBox: CGRect(x: 10, y: 110, width: 180, height: 20), confidence: 0.9),
            OCRResult(text: "Priority: High", boundingBox: CGRect(x: 10, y: 140, width: 100, height: 20), confidence: 0.9),
            OCRResult(text: "Effort: 8 points", boundingBox: CGRect(x: 10, y: 170, width: 110, height: 20), confidence: 0.9),
            OCRResult(text: "Due: Tomorrow", boundingBox: CGRect(x: 10, y: 200, width: 100, height: 20), confidence: 0.9)
        ]
        
        let asanaContext = ApplicationContext(
            bundleID: "com.asana.desktop",
            applicationName: "Asana",
            windowTitle: "Website Redesign Project - Asana",
            processID: 7890
        )
        
        await demonstrateParsingResults(
            results: asanaResults,
            context: asanaContext,
            title: "Asana Task and Dependency Detection"
        )
    }
    
    /// Demonstrates advanced workflow pattern recognition
    public func demonstrateWorkflowPatternRecognition() async {
        print("\n🔄 Workflow Pattern Recognition Demo")
        print("=" * 50)
        
        // Simulate a complex approval workflow
        let workflowResults = [
            OCRResult(text: "1. Submit request", boundingBox: CGRect(x: 10, y: 10, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "2. Manager review", boundingBox: CGRect(x: 10, y: 40, width: 130, height: 20), confidence: 0.9),
            OCRResult(text: "3. Finance approval", boundingBox: CGRect(x: 10, y: 70, width: 140, height: 20), confidence: 0.9),
            OCRResult(text: "4. Legal review", boundingBox: CGRect(x: 10, y: 100, width: 110, height: 20), confidence: 0.9),
            OCRResult(text: "5. Final approval", boundingBox: CGRect(x: 10, y: 130, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "6. Implementation", boundingBox: CGRect(x: 10, y: 160, width: 130, height: 20), confidence: 0.9),
            OCRResult(text: "Progress: 60%", boundingBox: CGRect(x: 10, y: 200, width: 90, height: 20), confidence: 0.95),
            OCRResult(text: "🏁 Milestone: Legal Review Complete", boundingBox: CGRect(x: 10, y: 230, width: 250, height: 20), confidence: 0.9),
            OCRResult(text: "⚠️ Overdue by 2 days", boundingBox: CGRect(x: 10, y: 260, width: 140, height: 20), confidence: 0.9)
        ]
        
        let workflowContext = ApplicationContext(
            bundleID: "com.example.workflow",
            applicationName: "Workflow Manager",
            windowTitle: "Approval Process Dashboard",
            processID: 2468
        )
        
        await demonstrateParsingResults(
            results: workflowResults,
            context: workflowContext,
            title: "Advanced Workflow Pattern and Progress Detection"
        )
    }
    
    /// Demonstrates form-based productivity application parsing
    public func demonstrateFormBasedApplicationParsing() async {
        print("\n📋 Form-Based Application Demo")
        print("=" * 50)
        
        // Simulate a complex form with validation and required fields
        let formResults = [
            OCRResult(text: "Customer Information", boundingBox: CGRect(x: 10, y: 10, width: 150, height: 25), confidence: 0.9),
            OCRResult(text: "Company Name *", boundingBox: CGRect(x: 10, y: 50, width: 110, height: 20), confidence: 0.9),
            OCRResult(text: "Acme Corporation", boundingBox: CGRect(x: 130, y: 50, width: 120, height: 20), confidence: 0.95),
            OCRResult(text: "Email Address *", boundingBox: CGRect(x: 10, y: 80, width: 110, height: 20), confidence: 0.9),
            OCRResult(text: "john@acme.com", boundingBox: CGRect(x: 130, y: 80, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "Industry", boundingBox: CGRect(x: 10, y: 110, width: 70, height: 20), confidence: 0.9),
            OCRResult(text: "Select industry ▼", boundingBox: CGRect(x: 90, y: 110, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "Annual Revenue", boundingBox: CGRect(x: 10, y: 140, width: 110, height: 20), confidence: 0.9),
            OCRResult(text: "$1M - $10M", boundingBox: CGRect(x: 130, y: 140, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "✓ This field is required", boundingBox: CGRect(x: 10, y: 170, width: 150, height: 20), confidence: 0.9),
            OCRResult(text: "❌ Invalid email format", boundingBox: CGRect(x: 10, y: 200, width: 140, height: 20), confidence: 0.9),
            OCRResult(text: "Save", boundingBox: CGRect(x: 10, y: 240, width: 50, height: 30), confidence: 0.95),
            OCRResult(text: "Cancel", boundingBox: CGRect(x: 70, y: 240, width: 60, height: 30), confidence: 0.9)
        ]
        
        let formContext = ApplicationContext(
            bundleID: "com.example.crm",
            applicationName: "CRM System",
            windowTitle: "New Customer Form",
            processID: 1357
        )
        
        await demonstrateParsingResults(
            results: formResults,
            context: formContext,
            title: "Form Field and Validation Detection"
        )
    }
    
    // MARK: - Helper Methods
    
    private func demonstrateParsingResults(
        results: [OCRResult],
        context: ApplicationContext,
        title: String
    ) async {
        print("\n📊 \(title)")
        print("-" * title.count)
        
        do {
            // Create test image
            let image = createTestImage()
            
            // Get enhanced OCR results
            let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
            
            // Get structured data
            let structuredData = try await plugin.extractStructuredData(from: results, context: context)
            
            // Display enhanced results
            print("\n🔍 Enhanced OCR Results:")
            for result in enhanced {
                print("  • \(result.semanticType): '\(result.originalResult.text)'")
                if !result.structuredData.isEmpty {
                    for (key, value) in result.structuredData {
                        print("    - \(key): \(value)")
                    }
                }
            }
            
            // Display structured data
            print("\n📋 Structured Data Elements:")
            for element in structuredData {
                print("  • \(element.type): '\(element.value)'")
                if !element.metadata.isEmpty {
                    for (key, value) in element.metadata {
                        print("    - \(key): \(value)")
                    }
                }
            }
            
            // Display summary statistics
            let semanticTypes = Set(enhanced.map { $0.semanticType })
            let dataTypes = Set(structuredData.map { $0.type })
            
            print("\n📈 Summary:")
            print("  • Enhanced results: \(enhanced.count)")
            print("  • Semantic types: \(semanticTypes.count) (\(semanticTypes.sorted().joined(separator: ", ")))")
            print("  • Structured elements: \(structuredData.count)")
            print("  • Data types: \(dataTypes.count) (\(dataTypes.sorted().joined(separator: ", ")))")
            
        } catch {
            print("❌ Error during parsing: \(error)")
        }
    }
    
    private func createTestImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: 400,
            height: 300,
            bitsPerComponent: 8,
            bytesPerRow: 1600,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let image = context.makeImage() else {
            fatalError("Failed to create test image")
        }
        
        return image
    }
    
    /// Runs all productivity parsing demonstrations
    public func runAllDemonstrations() async {
        print("🚀 Productivity Tool Parsing Plugin - Enhanced Demo")
        print("=" * 60)
        print("Demonstrating advanced parsing capabilities for:")
        print("• Jira ticket management and workflow tracking")
        print("• Salesforce CRM data and process flows")
        print("• Slack communication and collaboration")
        print("• Notion knowledge management")
        print("• Asana project management")
        print("• Advanced workflow pattern recognition")
        print("• Form-based productivity applications")
        print("")
        
        await demonstrateJiraWorkflowTracking()
        await demonstrateSalesforceWorkflowParsing()
        await demonstrateSlackCollaborationParsing()
        await demonstrateNotionKnowledgeManagement()
        await demonstrateAsanaProjectManagement()
        await demonstrateWorkflowPatternRecognition()
        await demonstrateFormBasedApplicationParsing()
        
        print("\n✅ All demonstrations completed successfully!")
        print("The enhanced productivity parsing plugin can now:")
        print("• Detect and classify workflow states and transitions")
        print("• Recognize application-specific UI elements and data")
        print("• Extract structured information from complex forms")
        print("• Identify workflow patterns and process flows")
        print("• Track progress indicators and milestones")
        print("• Parse collaboration and communication elements")
    }
}

// MARK: - String Extension for Demo Formatting

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}