import XCTest
@testable import MenuBarApp
@testable import Shared

/// Tests for the documentation and help system
class DocumentationSystemTests: XCTestCase {
    
    var helpSystem: HelpSystem!
    
    override func setUp() {
        super.setUp()
        helpSystem = HelpSystem.shared
    }
    
    override func tearDown() {
        helpSystem.hideHelp()
        super.tearDown()
    }
    
    // MARK: - Help System Tests
    
    func testHelpSystemInitialization() {
        XCTAssertNotNil(helpSystem)
        XCTAssertFalse(helpSystem.isHelpVisible)
        XCTAssertEqual(helpSystem.currentContext, .general)
        XCTAssertTrue(helpSystem.searchQuery.isEmpty)
    }
    
    func testShowHelpForContext() {
        // Test showing help for different contexts
        let contexts: [HelpContext] = [.general, .installation, .recording, .privacy]
        
        for context in contexts {
            helpSystem.showHelp(for: context)
            
            XCTAssertTrue(helpSystem.isHelpVisible)
            XCTAssertEqual(helpSystem.currentContext, context)
        }
    }
    
    func testHideHelp() {
        helpSystem.showHelp(for: .general)
        XCTAssertTrue(helpSystem.isHelpVisible)
        
        helpSystem.hideHelp()
        XCTAssertFalse(helpSystem.isHelpVisible)
        XCTAssertTrue(helpSystem.searchQuery.isEmpty)
    }
    
    func testSearchHelp() {
        let searchQuery = "recording"
        helpSystem.searchHelp(searchQuery)
        
        XCTAssertEqual(helpSystem.searchQuery, searchQuery)
    }
    
    func testGetContextualHelp() {
        helpSystem.showHelp(for: .recording)
        let helpItems = helpSystem.getContextualHelp()
        
        XCTAssertFalse(helpItems.isEmpty)
        
        // Verify help items are relevant to recording context
        let recordingRelatedItems = helpItems.filter { item in
            item.keywords.contains { keyword in
                keyword.localizedCaseInsensitiveContains("record") ||
                keyword.localizedCaseInsensitiveContains("capture")
            }
        }
        
        XCTAssertFalse(recordingRelatedItems.isEmpty)
    }
    
    func testSearchFilteringHelpItems() {
        helpSystem.showHelp(for: .general)
        helpSystem.searchHelp("installation")
        
        let filteredItems = helpSystem.getContextualHelp()
        
        // All returned items should contain the search term
        for item in filteredItems {
            let containsSearchTerm = item.title.localizedCaseInsensitiveContains("installation") ||
                                   item.content.localizedCaseInsensitiveContains("installation") ||
                                   item.keywords.contains { $0.localizedCaseInsensitiveContains("installation") }
            
            XCTAssertTrue(containsSearchTerm, "Item '\(item.title)' should contain search term 'installation'")
        }
    }
    
    func testGetQuickTips() {
        let contexts: [HelpContext] = [.general, .recording, .privacy]
        
        for context in contexts {
            helpSystem.showHelp(for: context)
            let quickTips = helpSystem.getQuickTips()
            
            // Should have at least some quick tips for major contexts
            if [.general, .recording, .privacy].contains(context) {
                XCTAssertFalse(quickTips.isEmpty, "Context \(context) should have quick tips")
            }
        }
    }
    
    func testGetTroubleshootingSteps() {
        let contexts: [HelpContext] = [.recording, .performance]
        
        for context in contexts {
            helpSystem.showHelp(for: context)
            let troubleshootingSteps = helpSystem.getTroubleshootingSteps()
            
            // Recording and performance contexts should have troubleshooting steps
            XCTAssertFalse(troubleshootingSteps.isEmpty, "Context \(context) should have troubleshooting steps")
            
            // Verify troubleshooting steps have required properties
            for step in troubleshootingSteps {
                XCTAssertFalse(step.problem.isEmpty)
                XCTAssertFalse(step.steps.isEmpty)
                XCTAssertTrue(step.steps.count > 0)
            }
        }
    }
    
    // MARK: - Help Context Tests
    
    func testHelpContextProperties() {
        for context in HelpContext.allCases {
            XCTAssertFalse(context.displayName.isEmpty)
            XCTAssertFalse(context.icon.isEmpty)
            XCTAssertFalse(context.rawValue.isEmpty)
        }
    }
    
    func testHelpContextUniqueness() {
        let rawValues = HelpContext.allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        
        XCTAssertEqual(rawValues.count, uniqueRawValues.count, "All help contexts should have unique raw values")
    }
    
    // MARK: - Help Content Manager Tests
    
    func testHelpContentManagerInitialization() {
        let contentManager = HelpContentManager()
        
        // Test that content is loaded for major contexts
        let majorContexts: [HelpContext] = [.general, .installation, .recording, .privacy]
        
        for context in majorContexts {
            let helpItems = contentManager.getHelpItems(for: context)
            XCTAssertFalse(helpItems.isEmpty, "Context \(context) should have help items")
        }
    }
    
    func testHelpItemsHaveRequiredProperties() {
        let contentManager = HelpContentManager()
        
        for context in HelpContext.allCases {
            let helpItems = contentManager.getHelpItems(for: context)
            
            for item in helpItems {
                XCTAssertFalse(item.id.isEmpty, "Help item should have non-empty ID")
                XCTAssertFalse(item.title.isEmpty, "Help item should have non-empty title")
                XCTAssertFalse(item.content.isEmpty, "Help item should have non-empty content")
                // Keywords can be empty, but if present should be valid
                for keyword in item.keywords {
                    XCTAssertFalse(keyword.isEmpty, "Keywords should not be empty strings")
                }
            }
        }
    }
    
    func testSearchFunctionality() {
        let contentManager = HelpContentManager()
        let searchQuery = "permission"
        
        let allItems = contentManager.getHelpItems(for: .installation)
        let filteredItems = contentManager.getHelpItems(for: .installation, searchQuery: searchQuery)
        
        // Filtered results should be subset of all items
        XCTAssertLessThanOrEqual(filteredItems.count, allItems.count)
        
        // All filtered items should match search query
        for item in filteredItems {
            let matchesSearch = item.title.localizedCaseInsensitiveContains(searchQuery) ||
                              item.content.localizedCaseInsensitiveContains(searchQuery) ||
                              item.keywords.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            
            XCTAssertTrue(matchesSearch, "Filtered item should match search query")
        }
    }
    
    // MARK: - Help Analytics Tests
    
    func testHelpAnalyticsTracking() {
        let analytics = HelpAnalytics()
        
        // Track help access
        analytics.trackHelpAccess(context: .recording)
        analytics.trackHelpAccess(context: .recording)
        analytics.trackHelpAccess(context: .privacy)
        
        let mostAccessed = analytics.getMostAccessedContexts()
        
        // Recording should be first (accessed twice)
        XCTAssertEqual(mostAccessed.first, .recording)
    }
    
    func testHelpSearchTracking() {
        let analytics = HelpAnalytics()
        
        // Track some searches
        analytics.trackHelpSearch("installation")
        analytics.trackHelpSearch("recording")
        analytics.trackHelpSearch("privacy")
        
        // Verify searches are tracked (implementation detail, but we can test it doesn't crash)
        XCTAssertNoThrow(analytics.trackHelpSearch("test"))
    }
    
    // MARK: - Documentation File Tests
    
    func testDocumentationFilesExist() {
        let bundle = Bundle.main
        
        // Test that main documentation files exist
        let documentationFiles = [
            "USER_GUIDE.md",
            "DEVELOPER_GUIDE.md",
            "TROUBLESHOOTING.md",
            "VIDEO_TUTORIALS.md",
            "README.md"
        ]
        
        for filename in documentationFiles {
            let fileURL = bundle.url(forResource: filename.replacingOccurrences(of: ".md", with: ""), 
                                   withExtension: "md", 
                                   subdirectory: "Documentation")
            
            XCTAssertNotNil(fileURL, "Documentation file \(filename) should exist")
            
            if let url = fileURL {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), 
                            "Documentation file should exist at path: \(url.path)")
            }
        }
    }
    
    func testDocumentationFileContent() {
        let bundle = Bundle.main
        
        // Test that documentation files have content
        if let userGuideURL = bundle.url(forResource: "USER_GUIDE", withExtension: "md", subdirectory: "Documentation") {
            do {
                let content = try String(contentsOf: userGuideURL)
                XCTAssertFalse(content.isEmpty, "User guide should have content")
                XCTAssertTrue(content.contains("Always-On AI Companion"), "User guide should mention the product name")
                XCTAssertTrue(content.contains("Installation"), "User guide should have installation section")
            } catch {
                XCTFail("Failed to read user guide content: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testMenuBarControllerHelpIntegration() {
        let menuBarController = MenuBarController()
        
        // Test that help can be opened without crashing
        XCTAssertNoThrow(menuBarController.openHelp())
        XCTAssertNoThrow(menuBarController.showContextualHelp(for: .recording))
        XCTAssertNoThrow(menuBarController.showContextualHelp(for: .privacy))
    }
    
    func testHelpSystemStateManagement() {
        // Test help system state transitions
        XCTAssertFalse(helpSystem.isHelpVisible)
        
        helpSystem.showHelp(for: .general)
        XCTAssertTrue(helpSystem.isHelpVisible)
        XCTAssertEqual(helpSystem.currentContext, .general)
        
        helpSystem.showHelp(for: .recording)
        XCTAssertTrue(helpSystem.isHelpVisible)
        XCTAssertEqual(helpSystem.currentContext, .recording)
        
        helpSystem.hideHelp()
        XCTAssertFalse(helpSystem.isHelpVisible)
    }
    
    // MARK: - Performance Tests
    
    func testHelpSystemPerformance() {
        measure {
            // Test performance of help content loading
            for context in HelpContext.allCases {
                helpSystem.showHelp(for: context)
                let _ = helpSystem.getContextualHelp()
                let _ = helpSystem.getQuickTips()
                let _ = helpSystem.getTroubleshootingSteps()
            }
        }
    }
    
    func testSearchPerformance() {
        helpSystem.showHelp(for: .general)
        
        measure {
            // Test search performance
            let searchQueries = ["installation", "recording", "privacy", "performance", "plugin"]
            
            for query in searchQueries {
                helpSystem.searchHelp(query)
                let _ = helpSystem.getContextualHelp()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testHelpSystemErrorHandling() {
        // Test that help system handles edge cases gracefully
        
        // Empty search query
        helpSystem.searchHelp("")
        XCTAssertNoThrow(helpSystem.getContextualHelp())
        
        // Very long search query
        let longQuery = String(repeating: "a", count: 1000)
        helpSystem.searchHelp(longQuery)
        XCTAssertNoThrow(helpSystem.getContextualHelp())
        
        // Special characters in search
        helpSystem.searchHelp("!@#$%^&*()")
        XCTAssertNoThrow(helpSystem.getContextualHelp())
    }
    
    func testHelpContentValidation() {
        let contentManager = HelpContentManager()
        
        // Test that all help items have valid structure
        for context in HelpContext.allCases {
            let helpItems = contentManager.getHelpItems(for: context)
            let quickTips = contentManager.getQuickTips(for: context)
            let troubleshootingSteps = contentManager.getTroubleshootingSteps(for: context)
            
            // Validate help items
            for item in helpItems {
                XCTAssertFalse(item.id.isEmpty)
                XCTAssertFalse(item.title.isEmpty)
                XCTAssertFalse(item.content.isEmpty)
            }
            
            // Validate quick tips
            for tip in quickTips {
                XCTAssertFalse(tip.id.isEmpty)
                XCTAssertFalse(tip.title.isEmpty)
                XCTAssertFalse(tip.content.isEmpty)
            }
            
            // Validate troubleshooting steps
            for step in troubleshootingSteps {
                XCTAssertFalse(step.id.isEmpty)
                XCTAssertFalse(step.problem.isEmpty)
                XCTAssertFalse(step.steps.isEmpty)
            }
        }
    }
}

// MARK: - Test Utilities

extension DocumentationSystemTests {
    
    /// Helper to create test help items
    private func createTestHelpItem(id: String = "test", title: String = "Test Title") -> HelpItem {
        return HelpItem(
            id: id,
            title: title,
            content: "Test content for \(title)",
            keywords: ["test", "example"],
            category: .overview
        )
    }
    
    /// Helper to create test quick tips
    private func createTestQuickTip(id: String = "test-tip") -> QuickTip {
        return QuickTip(
            id: id,
            title: "Test Tip",
            content: "This is a test tip"
        )
    }
    
    /// Helper to create test troubleshooting steps
    private func createTestTroubleshootingStep(id: String = "test-troubleshooting") -> TroubleshootingStep {
        return TroubleshootingStep(
            id: id,
            problem: "Test problem",
            steps: ["Step 1", "Step 2", "Step 3"],
            severity: .medium
        )
    }
}