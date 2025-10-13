import XCTest
import CoreGraphics
@testable import AlwaysOnAICompanion

class ProductivityParsingPluginTests: XCTestCase {
    
    var plugin: ProductivityParsingPlugin!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProductivityParsingPluginTests")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        plugin = ProductivityParsingPlugin()
        
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        try? plugin.initialize(configuration: config)
    }
    
    override func tearDown() {
        plugin.cleanup()
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Plugin Initialization Tests
    
    func testPluginInitialization() {
        XCTAssertEqual(plugin.identifier, "com.alwayson.plugins.productivity")
        XCTAssertEqual(plugin.name, "Productivity Application Parser")
        XCTAssertEqual(plugin.version, "1.1.0")
        XCTAssertTrue(plugin.description.contains("workflow pattern recognition"))
    }
    
    func testSupportedApplications() {
        let supportedApps = plugin.supportedApplications
        
        // Test Jira support
        XCTAssertTrue(supportedApps.contains("com.atlassian.jira"))
        XCTAssertTrue(supportedApps.contains("com.atlassian.*"))
        
        // Test Salesforce support
        XCTAssertTrue(supportedApps.contains("com.salesforce.*"))
        
        // Test Slack support
        XCTAssertTrue(supportedApps.contains("com.tinyspeck.slackmacgap"))
        XCTAssertTrue(supportedApps.contains("com.slack.*"))
        
        // Test Notion support
        XCTAssertTrue(supportedApps.contains("notion.id"))
        
        // Test Asana support
        XCTAssertTrue(supportedApps.contains("com.asana.*"))
    }
    
    func testCanHandleContext() {
        let jiraContext = ApplicationContext(
            bundleID: "com.atlassian.jira",
            applicationName: "Jira",
            windowTitle: "PROJ-123 - Bug Report",
            processID: 1234
        )
        
        let slackContext = ApplicationContext(
            bundleID: "com.tinyspeck.slackmacgap",
            applicationName: "Slack",
            windowTitle: "Slack - #general",
            processID: 5678
        )
        
        let unsupportedContext = ApplicationContext(
            bundleID: "com.other.app",
            applicationName: "Other App",
            windowTitle: "Test",
            processID: 9012
        )
        
        XCTAssertTrue(plugin.canHandle(context: jiraContext))
        XCTAssertTrue(plugin.canHandle(context: slackContext))
        XCTAssertFalse(plugin.canHandle(context: unsupportedContext))
    }
    
    // MARK: - Jira Parsing Tests
    
    func testJiraIssueKeyDetection() async throws {
        let results = [
            OCRResult(text: "PROJ-123", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "Bug Report", boundingBox: CGRect(x: 90, y: 0, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "TEAM-456", boundingBox: CGRect(x: 0, y: 30, width: 80, height: 20), confidence: 0.93)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.atlassian.jira",
            applicationName: "Jira",
            windowTitle: "Jira Dashboard",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let issueKeys = enhanced.filter { $0.semanticType == "jira_issue_key" }
        XCTAssertEqual(issueKeys.count, 2)
        
        // Verify structured data
        let firstIssue = issueKeys.first!
        XCTAssertEqual(firstIssue.structuredData["project"] as? String, "PROJ")
        XCTAssertEqual(firstIssue.structuredData["issue_number"] as? Int, 123)
    }
    
    func testJiraWorkflowTransitions() async throws {
        let results = [
            OCRResult(text: "Start Progress", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 30), confidence: 0.9),
            OCRResult(text: "Done", boundingBox: CGRect(x: 110, y: 0, width: 50, height: 30), confidence: 0.95),
            OCRResult(text: "Resolve", boundingBox: CGRect(x: 170, y: 0, width: 70, height: 30), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.atlassian.jira",
            applicationName: "Jira",
            windowTitle: "Issue View",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let transitions = enhanced.filter { $0.semanticType == "jira_transition" }
        XCTAssertEqual(transitions.count, 3)
        
        // Verify transition types
        let transitionTypes = transitions.compactMap { $0.structuredData["transition_type"] as? String }
        XCTAssertTrue(transitionTypes.contains("start"))
        XCTAssertTrue(transitionTypes.contains("complete"))
        XCTAssertTrue(transitionTypes.contains("resolve"))
    }
    
    func testJiraBoardColumns() async throws {
        let results = [
            OCRResult(text: "To Do", boundingBox: CGRect(x: 0, y: 0, width: 60, height: 25), confidence: 0.9),
            OCRResult(text: "In Progress", boundingBox: CGRect(x: 70, y: 0, width: 90, height: 25), confidence: 0.9),
            OCRResult(text: "Code Review", boundingBox: CGRect(x: 170, y: 0, width: 100, height: 25), confidence: 0.9),
            OCRResult(text: "Done", boundingBox: CGRect(x: 280, y: 0, width: 50, height: 25), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.atlassian.jira",
            applicationName: "Jira",
            windowTitle: "Kanban Board",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let columns = enhanced.filter { $0.semanticType == "jira_board_column" }
        XCTAssertEqual(columns.count, 4)
        
        // Verify workflow stages
        let workflowStages = columns.compactMap { $0.structuredData["workflow_stage"] as? String }
        XCTAssertTrue(workflowStages.contains("ready"))
        XCTAssertTrue(workflowStages.contains("active"))
        XCTAssertTrue(workflowStages.contains("validation"))
        XCTAssertTrue(workflowStages.contains("complete"))
    }
    
    func testJiraStructuredDataExtraction() async throws {
        let results = [
            OCRResult(text: "PROJ-123", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "Start Progress", boundingBox: CGRect(x: 0, y: 30, width: 100, height: 30), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.atlassian.jira",
            applicationName: "Jira",
            windowTitle: "Issue View",
            processID: 1234
        )
        
        let structuredData = try await plugin.extractStructuredData(from: results, context: context)
        
        let jiraIssues = structuredData.filter { $0.type == "jira_issue" }
        let jiraTransitions = structuredData.filter { $0.type == "jira_workflow_transition" }
        
        XCTAssertEqual(jiraIssues.count, 1)
        XCTAssertEqual(jiraTransitions.count, 1)
        
        // Verify issue data
        let issue = jiraIssues.first!
        XCTAssertEqual(issue.value as? String, "PROJ-123")
        XCTAssertEqual(issue.metadata["project"] as? String, "PROJ")
        XCTAssertEqual(issue.metadata["issue_number"] as? Int, 123)
        
        // Verify transition data
        let transition = jiraTransitions.first!
        XCTAssertEqual(transition.value as? String, "Start Progress")
        XCTAssertEqual(transition.metadata["transition_type"] as? String, "start")
        XCTAssertEqual(transition.metadata["workflow_stage"] as? String, "active")
    }
    
    // MARK: - Salesforce Parsing Tests
    
    func testSalesforceRecordIdDetection() async throws {
        let results = [
            OCRResult(text: "0013000000ABC123", boundingBox: CGRect(x: 0, y: 0, width: 120, height: 20), confidence: 0.95),
            OCRResult(text: "0063000000DEF456", boundingBox: CGRect(x: 0, y: 30, width: 120, height: 20), confidence: 0.93)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.salesforce.lightning",
            applicationName: "Salesforce",
            windowTitle: "Account Details",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let recordIds = enhanced.filter { $0.semanticType == "salesforce_record_id" }
        XCTAssertEqual(recordIds.count, 2)
        
        // Verify object type inference
        let objectTypes = recordIds.compactMap { $0.structuredData["object_type"] as? String }
        XCTAssertTrue(objectTypes.contains("Contact"))
        XCTAssertTrue(objectTypes.contains("Opportunity"))
    }
    
    func testSalesforceOpportunityStages() async throws {
        let results = [
            OCRResult(text: "Prospecting", boundingBox: CGRect(x: 0, y: 0, width: 90, height: 20), confidence: 0.9),
            OCRResult(text: "Closed Won", boundingBox: CGRect(x: 0, y: 30, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "Negotiation", boundingBox: CGRect(x: 0, y: 60, width: 90, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.salesforce.lightning",
            applicationName: "Salesforce",
            windowTitle: "Opportunity Pipeline",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let stages = enhanced.filter { $0.semanticType == "salesforce_opportunity_stage" }
        XCTAssertEqual(stages.count, 3)
        
        // Verify stage categories
        let stageCategories = stages.compactMap { $0.structuredData["stage_category"] as? String }
        XCTAssertTrue(stageCategories.contains("early_stage"))
        XCTAssertTrue(stageCategories.contains("won"))
        XCTAssertTrue(stageCategories.contains("late_stage"))
    }
    
    func testSalesforceApprovalProcess() async throws {
        let results = [
            OCRResult(text: "Pending Approval", boundingBox: CGRect(x: 0, y: 0, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "Approved", boundingBox: CGRect(x: 0, y: 30, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "Rejected", boundingBox: CGRect(x: 0, y: 60, width: 70, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.salesforce.lightning",
            applicationName: "Salesforce",
            windowTitle: "Approval Process",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let approvals = enhanced.filter { $0.semanticType == "salesforce_approval_process" }
        XCTAssertEqual(approvals.count, 3)
        
        // Verify approval stages
        let approvalStages = approvals.compactMap { $0.structuredData["approval_stage"] as? String }
        XCTAssertTrue(approvalStages.contains("pending"))
        XCTAssertTrue(approvalStages.contains("approved"))
        XCTAssertTrue(approvalStages.contains("rejected"))
    }
    
    // MARK: - Slack Parsing Tests
    
    func testSlackChannelDetection() async throws {
        let results = [
            OCRResult(text: "#general", boundingBox: CGRect(x: 0, y: 0, width: 70, height: 20), confidence: 0.95),
            OCRResult(text: "#dev-team", boundingBox: CGRect(x: 0, y: 30, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "🔒 #private-channel", boundingBox: CGRect(x: 0, y: 60, width: 130, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.tinyspeck.slackmacgap",
            applicationName: "Slack",
            windowTitle: "Slack - Workspace",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let channels = enhanced.filter { $0.semanticType == "slack_channel" }
        XCTAssertEqual(channels.count, 3)
        
        // Verify channel types
        let channelTypes = channels.compactMap { $0.structuredData["channel_type"] as? String }
        XCTAssertTrue(channelTypes.contains("general"))
        XCTAssertTrue(channelTypes.contains("development"))
        
        // Verify privacy detection
        let privateChannels = channels.filter { $0.structuredData["is_private"] as? Bool == true }
        XCTAssertEqual(privateChannels.count, 1)
    }
    
    func testSlackMentions() async throws {
        let results = [
            OCRResult(text: "@john.doe", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "@channel", boundingBox: CGRect(x: 0, y: 30, width: 70, height: 20), confidence: 0.9),
            OCRResult(text: "@everyone", boundingBox: CGRect(x: 0, y: 60, width: 80, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.tinyspeck.slackmacgap",
            applicationName: "Slack",
            windowTitle: "Slack - #general",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let mentions = enhanced.filter { $0.semanticType == "slack_mention" }
        XCTAssertEqual(mentions.count, 3)
        
        // Verify mention types
        let mentionTypes = mentions.compactMap { $0.structuredData["mention_type"] as? String }
        XCTAssertTrue(mentionTypes.contains("user_mention"))
        XCTAssertTrue(mentionTypes.contains("channel_mention"))
        XCTAssertTrue(mentionTypes.contains("everyone_mention"))
        
        // Verify username extraction
        let userMention = mentions.first { $0.structuredData["mention_type"] as? String == "user_mention" }
        XCTAssertEqual(userMention?.structuredData["username"] as? String, "john.doe")
    }
    
    // MARK: - Notion Parsing Tests
    
    func testNotionPropertyDetection() async throws {
        let results = [
            OCRResult(text: "Status", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "Assignee", boundingBox: CGRect(x: 0, y: 30, width: 70, height: 20), confidence: 0.9),
            OCRResult(text: "Due Date", boundingBox: CGRect(x: 0, y: 60, width: 70, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "notion.id",
            applicationName: "Notion",
            windowTitle: "Project Database",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let properties = enhanced.filter { $0.semanticType == "notion_property" }
        XCTAssertEqual(properties.count, 3)
        
        // Verify property types
        let propertyTypes = properties.compactMap { $0.structuredData["property_type"] as? String }
        XCTAssertTrue(propertyTypes.contains("select"))
        XCTAssertTrue(propertyTypes.contains("person"))
        XCTAssertTrue(propertyTypes.contains("date"))
    }
    
    func testNotionPageHierarchy() async throws {
        let results = [
            OCRResult(text: "▶ Project Overview", boundingBox: CGRect(x: 0, y: 0, width: 130, height: 20), confidence: 0.9),
            OCRResult(text: "  ├ Task 1", boundingBox: CGRect(x: 20, y: 30, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "  └ Task 2", boundingBox: CGRect(x: 20, y: 60, width: 80, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "notion.id",
            applicationName: "Notion",
            windowTitle: "Project Page",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let hierarchies = enhanced.filter { $0.semanticType == "notion_page_hierarchy" }
        XCTAssertEqual(hierarchies.count, 3)
        
        // Verify hierarchy levels
        let hierarchyLevels = hierarchies.compactMap { $0.structuredData["hierarchy_level"] as? Int }
        XCTAssertTrue(hierarchyLevels.contains(1))
        XCTAssertTrue(hierarchyLevels.contains(2))
    }
    
    // MARK: - Asana Parsing Tests
    
    func testAsanaSectionDetection() async throws {
        let results = [
            OCRResult(text: "TO DO", boundingBox: CGRect(x: 0, y: 0, width: 60, height: 25), confidence: 0.9),
            OCRResult(text: "IN PROGRESS", boundingBox: CGRect(x: 70, y: 0, width: 100, height: 25), confidence: 0.9),
            OCRResult(text: "DONE", boundingBox: CGRect(x: 180, y: 0, width: 50, height: 25), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.asana.desktop",
            applicationName: "Asana",
            windowTitle: "Project Board",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let sections = enhanced.filter { $0.semanticType == "asana_section" }
        XCTAssertEqual(sections.count, 3)
        
        // Verify section types
        let sectionTypes = sections.compactMap { $0.structuredData["section_type"] as? String }
        XCTAssertTrue(sectionTypes.contains("todo"))
        XCTAssertTrue(sectionTypes.contains("in_progress"))
        XCTAssertTrue(sectionTypes.contains("complete"))
    }
    
    func testAsanaDependencies() async throws {
        let results = [
            OCRResult(text: "Depends on Task A", boundingBox: CGRect(x: 0, y: 0, width: 130, height: 20), confidence: 0.9),
            OCRResult(text: "Blocked by approval", boundingBox: CGRect(x: 0, y: 30, width: 140, height: 20), confidence: 0.9),
            OCRResult(text: "Waiting for review", boundingBox: CGRect(x: 0, y: 60, width: 130, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.asana.desktop",
            applicationName: "Asana",
            windowTitle: "Task Details",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let dependencies = enhanced.filter { $0.semanticType == "asana_dependency" }
        XCTAssertEqual(dependencies.count, 3)
        
        // Verify dependency types
        let dependencyTypes = dependencies.compactMap { $0.structuredData["dependency_type"] as? String }
        XCTAssertTrue(dependencyTypes.contains("dependency"))
        XCTAssertTrue(dependencyTypes.contains("blocking"))
        XCTAssertTrue(dependencyTypes.contains("waiting"))
    }
    
    // MARK: - Common Productivity Elements Tests
    
    func testWorkflowStateDetection() async throws {
        let results = [
            OCRResult(text: "To Do", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "In Progress", boundingBox: CGRect(x: 60, y: 0, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "Blocked", boundingBox: CGRect(x: 150, y: 0, width: 60, height: 20), confidence: 0.9),
            OCRResult(text: "Done", boundingBox: CGRect(x: 220, y: 0, width: 40, height: 20), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.productivity",
            applicationName: "Productivity App",
            windowTitle: "Workflow",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let workflowStates = enhanced.filter { $0.semanticType == "workflow_state" }
        XCTAssertEqual(workflowStates.count, 4)
        
        // Verify state categories
        let stateCategories = workflowStates.compactMap { $0.structuredData["state_category"] as? String }
        XCTAssertTrue(stateCategories.contains("initial"))
        XCTAssertTrue(stateCategories.contains("active"))
        XCTAssertTrue(stateCategories.contains("blocked"))
        XCTAssertTrue(stateCategories.contains("complete"))
        
        // Verify terminal state detection
        let terminalStates = workflowStates.filter { $0.structuredData["is_terminal"] as? Bool == true }
        XCTAssertEqual(terminalStates.count, 1)
    }
    
    func testPriorityIndicators() async throws {
        let results = [
            OCRResult(text: "High", boundingBox: CGRect(x: 0, y: 0, width: 40, height: 20), confidence: 0.9),
            OCRResult(text: "P1", boundingBox: CGRect(x: 50, y: 0, width: 30, height: 20), confidence: 0.95),
            OCRResult(text: "Critical", boundingBox: CGRect(x: 90, y: 0, width: 60, height: 20), confidence: 0.9),
            OCRResult(text: "Low", boundingBox: CGRect(x: 160, y: 0, width: 30, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.productivity",
            applicationName: "Productivity App",
            windowTitle: "Task List",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let priorities = enhanced.filter { $0.semanticType == "priority_indicator" }
        XCTAssertEqual(priorities.count, 4)
        
        // Verify priority levels
        let priorityLevels = priorities.compactMap { $0.structuredData["priority_level"] as? String }
        XCTAssertTrue(priorityLevels.contains("high"))
        XCTAssertTrue(priorityLevels.contains("critical"))
        XCTAssertTrue(priorityLevels.contains("low"))
        
        // Verify priority values
        let priorityValues = priorities.compactMap { $0.structuredData["priority_value"] as? Int }
        XCTAssertTrue(priorityValues.contains(4)) // Critical
        XCTAssertTrue(priorityValues.contains(3)) // High
        XCTAssertTrue(priorityValues.contains(1)) // Low
    }
    
    func testFormElementDetection() async throws {
        let results = [
            OCRResult(text: "This field is required", boundingBox: CGRect(x: 0, y: 0, width: 150, height: 20), confidence: 0.9),
            OCRResult(text: "Invalid email format", boundingBox: CGRect(x: 0, y: 30, width: 140, height: 20), confidence: 0.9),
            OCRResult(text: "Name *", boundingBox: CGRect(x: 0, y: 60, width: 60, height: 20), confidence: 0.9),
            OCRResult(text: "Select option ▼", boundingBox: CGRect(x: 0, y: 90, width: 120, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.productivity",
            applicationName: "Productivity App",
            windowTitle: "Form",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let validationMessages = enhanced.filter { $0.semanticType == "form_validation" }
        let requiredFields = enhanced.filter { $0.semanticType == "required_field" }
        let dropdownOptions = enhanced.filter { $0.semanticType == "dropdown_option" }
        
        XCTAssertEqual(validationMessages.count, 2)
        XCTAssertEqual(requiredFields.count, 1)
        XCTAssertEqual(dropdownOptions.count, 1)
        
        // Verify validation types
        let validationTypes = validationMessages.compactMap { $0.structuredData["validation_type"] as? String }
        XCTAssertTrue(validationTypes.contains("required"))
        XCTAssertTrue(validationTypes.contains("format"))
        
        // Verify error detection
        let errorValidations = validationMessages.filter { $0.structuredData["is_error"] as? Bool == true }
        XCTAssertEqual(errorValidations.count, 1)
    }
    
    func testProgressIndicators() async throws {
        let results = [
            OCRResult(text: "75%", boundingBox: CGRect(x: 0, y: 0, width: 40, height: 20), confidence: 0.95),
            OCRResult(text: "3/4 complete", boundingBox: CGRect(x: 0, y: 30, width: 90, height: 20), confidence: 0.9),
            OCRResult(text: "🏁 Milestone 1", boundingBox: CGRect(x: 0, y: 60, width: 110, height: 20), confidence: 0.9),
            OCRResult(text: "Due tomorrow", boundingBox: CGRect(x: 0, y: 90, width: 100, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.productivity",
            applicationName: "Productivity App",
            windowTitle: "Project Progress",
            processID: 1234
        )
        
        let image = createTestImage()
        let enhanced = try await plugin.enhanceOCRResults(results, context: context, frame: image)
        
        let percentages = enhanced.filter { $0.semanticType == "progress_percentage" }
        let milestones = enhanced.filter { $0.semanticType == "milestone" }
        let deadlines = enhanced.filter { $0.semanticType == "deadline" }
        
        XCTAssertEqual(percentages.count, 2)
        XCTAssertEqual(milestones.count, 1)
        XCTAssertEqual(deadlines.count, 1)
        
        // Verify percentage extraction
        let completionPercentages = percentages.compactMap { $0.structuredData["completion_percentage"] as? Int }
        XCTAssertTrue(completionPercentages.contains(75))
        XCTAssertTrue(completionPercentages.contains(75)) // 3/4 = 75%
        
        // Verify deadline urgency
        let deadline = deadlines.first!
        XCTAssertEqual(deadline.structuredData["deadline_urgency"] as? String, "high")
    }
    
    // MARK: - Workflow Pattern Recognition Tests
    
    func testWorkflowPatternExtraction() async throws {
        let results = [
            OCRResult(text: "1. Create task", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.9),
            OCRResult(text: "2. Assign reviewer", boundingBox: CGRect(x: 0, y: 30, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "3. Review and approve", boundingBox: CGRect(x: 0, y: 60, width: 140, height: 20), confidence: 0.9),
            OCRResult(text: "4. Deploy to production", boundingBox: CGRect(x: 0, y: 90, width: 150, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.productivity",
            applicationName: "Productivity App",
            windowTitle: "Workflow",
            processID: 1234
        )
        
        let structuredData = try await plugin.extractStructuredData(from: results, context: context)
        
        let workflowPatterns = structuredData.filter { $0.type == "workflow_pattern" }
        XCTAssertEqual(workflowPatterns.count, 1)
        
        let pattern = workflowPatterns.first!
        XCTAssertEqual(pattern.metadata["step_count"] as? Int, 4)
        XCTAssertEqual(pattern.metadata["pattern_type"] as? String, "deployment_workflow")
        
        let sequenceText = pattern.value as? String
        XCTAssertTrue(sequenceText?.contains("Create task → Assign reviewer → Review and approve → Deploy to production") == true)
    }
    
    func testFormGroupExtraction() async throws {
        let results = [
            OCRResult(text: "Username:", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "john.doe", boundingBox: CGRect(x: 90, y: 0, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "Password:", boundingBox: CGRect(x: 0, y: 30, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "••••••••", boundingBox: CGRect(x: 90, y: 30, width: 80, height: 20), confidence: 0.8),
            OCRResult(text: "Remember me", boundingBox: CGRect(x: 0, y: 60, width: 100, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.productivity",
            applicationName: "Productivity App",
            windowTitle: "Login",
            processID: 1234
        )
        
        let structuredData = try await plugin.extractStructuredData(from: results, context: context)
        
        let formGroups = structuredData.filter { $0.type == "form_group" }
        XCTAssertEqual(formGroups.count, 1)
        
        let formGroup = formGroups.first!
        XCTAssertEqual(formGroup.metadata["field_count"] as? Int, 2)
        XCTAssertEqual(formGroup.metadata["form_type"] as? String, "login_form")
        
        let formText = formGroup.value as? String
        XCTAssertTrue(formText?.contains("Username:") == true)
        XCTAssertTrue(formText?.contains("Password:") == true)
    }
    
    // MARK: - Helper Methods
    
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
}