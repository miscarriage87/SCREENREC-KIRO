import Foundation
import CoreGraphics
import os.log

/// Demo application showcasing the plugin architecture functionality
public class PluginSystemDemo {
    private let logger = Logger(subsystem: "AlwaysOnAICompanion", category: "PluginSystemDemo")
    
    private let pluginManager: PluginManager
    private let configManager: PluginConfigurationManager
    private let demoDirectory: URL
    
    public init() {
        // Create demo directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        demoDirectory = documentsPath.appendingPathComponent("PluginSystemDemo")
        
        try? FileManager.default.createDirectory(
            at: demoDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Initialize managers
        let pluginDirectory = demoDirectory.appendingPathComponent("plugins")
        let configDirectory = demoDirectory.appendingPathComponent("config")
        
        pluginManager = PluginManager(pluginDirectory: pluginDirectory, sandboxEnabled: false)
        configManager = PluginConfigurationManager(configurationDirectory: configDirectory)
        
        logger.info("Plugin System Demo initialized at: \(demoDirectory.path)")
    }
    
    // MARK: - Demo Scenarios
    
    /// Run all demo scenarios
    public func runAllDemos() async {
        print("🚀 Starting Plugin System Demo")
        print("=" * 50)
        
        await demoPluginConfiguration()
        await demoWebApplicationParsing()
        await demoProductivityApplicationParsing()
        await demoTerminalApplicationParsing()
        await demoEventDetection()
        await demoPluginManagement()
        
        print("=" * 50)
        print("✅ Plugin System Demo completed successfully!")
    }
    
    /// Demo plugin configuration management
    private func demoPluginConfiguration() async {
        print("\n📋 Demo: Plugin Configuration Management")
        print("-" * 40)
        
        // Show default configurations
        let allConfigs = configManager.getAllConfigurations()
        print("Default plugin configurations loaded: \(allConfigs.count)")
        
        for config in allConfigs {
            print("  • \(config.name) (\(config.identifier))")
            print("    Enabled: \(config.enabled)")
            print("    Supported Apps: \(config.supportedApplications.count)")
            print("    Memory Limit: \(config.maxMemoryUsage / (1024 * 1024))MB")
            print("    Timeout: \(config.maxExecutionTime)s")
        }
        
        // Demo configuration modification
        print("\nModifying web plugin configuration...")
        if var webConfig = configManager.getConfiguration(for: "com.alwayson.plugins.web") {
            webConfig.settings["demo_mode"] = true
            webConfig.settings["max_elements"] = 500
            configManager.updateConfiguration(webConfig)
            print("✅ Web plugin configuration updated")
        }
        
        // Demo enabling/disabling plugins
        print("\nTesting plugin enable/disable...")
        configManager.setPluginEnabled("com.alwayson.plugins.productivity", enabled: false)
        print("Productivity plugin disabled: \(!configManager.isPluginEnabled("com.alwayson.plugins.productivity"))")
        
        configManager.setPluginEnabled("com.alwayson.plugins.productivity", enabled: true)
        print("Productivity plugin re-enabled: \(configManager.isPluginEnabled("com.alwayson.plugins.productivity"))")
        
        // Demo validation
        print("\nTesting configuration validation...")
        let invalidConfig = PluginConfigurationData(
            identifier: "",
            name: "Invalid Plugin",
            version: "1.0.0",
            supportedApplications: [],
            maxMemoryUsage: -1,
            maxExecutionTime: -5.0
        )
        
        let errors = configManager.validateConfiguration(invalidConfig)
        print("Validation errors found: \(errors.count)")
        for error in errors {
            print("  ❌ \(error.localizedDescription)")
        }
    }
    
    /// Demo web application parsing capabilities
    private func demoWebApplicationParsing() async {
        print("\n🌐 Demo: Web Application Parsing")
        print("-" * 40)
        
        let webPlugin = WebParsingPlugin()
        let config = PluginConfiguration(pluginDirectory: demoDirectory)
        
        do {
            try webPlugin.initialize(configuration: config)
            print("✅ Web plugin initialized")
            
            // Create sample web form OCR results
            let webFormResults = createSampleWebFormOCRResults()
            let safariContext = ApplicationContext(
                bundleID: "com.apple.Safari",
                applicationName: "Safari",
                windowTitle: "Contact Form - Safari",
                processID: 1234,
                metadata: ["url": "https://example.com/contact"]
            )
            
            print("\nProcessing web form with \(webFormResults.count) OCR results...")
            
            // Test OCR enhancement
            let testImage = createTestImage(width: 800, height: 600)
            let enhancedResults = try await webPlugin.enhanceOCRResults(
                webFormResults,
                context: safariContext,
                frame: testImage
            )
            
            print("Enhanced OCR results: \(enhancedResults.count)")
            for result in enhancedResults {
                print("  • \(result.semanticType): \(result.originalResult.text)")
                if !result.structuredData.isEmpty {
                    print("    Data: \(result.structuredData)")
                }
            }
            
            // Test structured data extraction
            let structuredData = try await webPlugin.extractStructuredData(
                from: webFormResults,
                context: safariContext
            )
            
            print("\nExtracted structured data: \(structuredData.count) elements")
            for element in structuredData {
                print("  • \(element.type): \(element.value)")
                if let metadata = element.metadata["label"] {
                    print("    Label: \(metadata)")
                }
            }
            
            webPlugin.cleanup()
            print("✅ Web plugin demo completed")
            
        } catch {
            print("❌ Web plugin demo failed: \(error)")
        }
    }
    
    /// Demo productivity application parsing capabilities
    private func demoProductivityApplicationParsing() async {
        print("\n💼 Demo: Productivity Application Parsing")
        print("-" * 40)
        
        let productivityPlugin = ProductivityParsingPlugin()
        let config = PluginConfiguration(pluginDirectory: demoDirectory)
        
        do {
            try productivityPlugin.initialize(configuration: config)
            print("✅ Productivity plugin initialized")
            
            // Create sample Jira ticket OCR results
            let jiraResults = createSampleJiraOCRResults()
            let jiraContext = ApplicationContext(
                bundleID: "com.atlassian.jira",
                applicationName: "Jira",
                windowTitle: "PROJ-123: Implement new feature - Jira",
                processID: 5678
            )
            
            print("\nProcessing Jira ticket with \(jiraResults.count) OCR results...")
            
            // Test OCR enhancement
            let testImage = createTestImage(width: 1200, height: 800)
            let enhancedResults = try await productivityPlugin.enhanceOCRResults(
                jiraResults,
                context: jiraContext,
                frame: testImage
            )
            
            print("Enhanced OCR results: \(enhancedResults.count)")
            for result in enhancedResults {
                print("  • \(result.semanticType): \(result.originalResult.text)")
                if !result.structuredData.isEmpty {
                    print("    Data: \(result.structuredData)")
                }
            }
            
            // Test structured data extraction
            let structuredData = try await productivityPlugin.extractStructuredData(
                from: jiraResults,
                context: jiraContext
            )
            
            print("\nExtracted structured data: \(structuredData.count) elements")
            for element in structuredData {
                print("  • \(element.type): \(element.value)")
                if let project = element.metadata["project"] {
                    print("    Project: \(project)")
                }
            }
            
            productivityPlugin.cleanup()
            print("✅ Productivity plugin demo completed")
            
        } catch {
            print("❌ Productivity plugin demo failed: \(error)")
        }
    }
    
    /// Demo terminal application parsing capabilities
    private func demoTerminalApplicationParsing() async {
        print("\n💻 Demo: Terminal Application Parsing")
        print("-" * 40)
        
        let terminalPlugin = TerminalParsingPlugin()
        let config = PluginConfiguration(pluginDirectory: demoDirectory)
        
        do {
            try terminalPlugin.initialize(configuration: config)
            print("✅ Terminal plugin initialized")
            
            // Create sample terminal session OCR results
            let terminalResults = createSampleTerminalOCRResults()
            let terminalContext = ApplicationContext(
                bundleID: "com.apple.Terminal",
                applicationName: "Terminal",
                windowTitle: "Terminal — bash — 80×24",
                processID: 9012
            )
            
            print("\nProcessing terminal session with \(terminalResults.count) OCR results...")
            
            // Test OCR enhancement
            let testImage = createTestImage(width: 1000, height: 700)
            let enhancedResults = try await terminalPlugin.enhanceOCRResults(
                terminalResults,
                context: terminalContext,
                frame: testImage
            )
            
            print("Enhanced OCR results: \(enhancedResults.count)")
            for result in enhancedResults {
                print("  • \(result.semanticType): \(result.originalResult.text)")
                if !result.structuredData.isEmpty {
                    print("    Data: \(result.structuredData)")
                }
            }
            
            // Test structured data extraction
            let structuredData = try await terminalPlugin.extractStructuredData(
                from: terminalResults,
                context: terminalContext
            )
            
            print("\nExtracted structured data: \(structuredData.count) elements")
            for element in structuredData {
                print("  • \(element.type): \(element.value)")
                if let commandType = element.metadata["command_type"] {
                    print("    Command Type: \(commandType)")
                }
            }
            
            terminalPlugin.cleanup()
            print("✅ Terminal plugin demo completed")
            
        } catch {
            print("❌ Terminal plugin demo failed: \(error)")
        }
    }
    
    /// Demo event detection capabilities
    private func demoEventDetection() async {
        print("\n🔍 Demo: Event Detection")
        print("-" * 40)
        
        // Create sample OCR delta for event detection
        let previousResults = [
            OCRResult(text: "Username:", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "old_username", boundingBox: CGRect(x: 90, y: 0, width: 100, height: 20), confidence: 0.95)
        ]
        
        let currentResults = [
            OCRResult(text: "Username:", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "new_username", boundingBox: CGRect(x: 90, y: 0, width: 100, height: 20), confidence: 0.95)
        ]
        
        let ocrDelta = OCRDelta(
            previousResults: previousResults,
            currentResults: currentResults,
            addedElements: [],
            removedElements: [],
            modifiedElements: [(previous: previousResults[1], current: currentResults[1])]
        )
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Login Form - Safari",
            processID: 1234
        )
        
        print("Detecting events from OCR delta...")
        let events = await pluginManager.detectEvents(from: ocrDelta, context: context)
        
        print("Detected events: \(events.count)")
        for event in events {
            print("  • \(event.type): \(event.target)")
            print("    From: '\(event.valueBefore ?? "nil")' → To: '\(event.valueAfter ?? "nil")'")
            print("    Confidence: \(String(format: "%.2f", event.confidence))")
        }
    }
    
    /// Demo plugin management operations
    private func demoPluginManagement() async {
        print("\n⚙️ Demo: Plugin Management")
        print("-" * 40)
        
        // Show loaded plugins
        let loadedPlugins = pluginManager.getLoadedPlugins()
        print("Currently loaded plugins: \(loadedPlugins.count)")
        
        // Test plugin context matching
        let contexts = [
            ApplicationContext(bundleID: "com.apple.Safari", applicationName: "Safari", windowTitle: "Test", processID: 1),
            ApplicationContext(bundleID: "com.atlassian.jira", applicationName: "Jira", windowTitle: "Test", processID: 2),
            ApplicationContext(bundleID: "com.apple.Terminal", applicationName: "Terminal", windowTitle: "Test", processID: 3),
            ApplicationContext(bundleID: "com.unknown.app", applicationName: "Unknown", windowTitle: "Test", processID: 4)
        ]
        
        for context in contexts {
            let parsingPlugins = pluginManager.getParsingPlugins(for: context)
            let eventPlugins = pluginManager.getEventDetectionPlugins(for: context)
            
            print("\nApp: \(context.bundleID)")
            print("  Parsing plugins: \(parsingPlugins.count)")
            print("  Event plugins: \(eventPlugins.count)")
        }
        
        // Test plugin loading status
        let testIdentifiers = [
            "com.alwayson.plugins.web",
            "com.alwayson.plugins.productivity",
            "com.alwayson.plugins.terminal",
            "com.nonexistent.plugin"
        ]
        
        print("\nPlugin loading status:")
        for identifier in testIdentifiers {
            let isLoaded = pluginManager.isPluginLoaded(identifier)
            print("  \(identifier): \(isLoaded ? "✅ Loaded" : "❌ Not loaded")")
        }
    }
    
    // MARK: - Sample Data Creation
    
    private func createSampleWebFormOCRResults() -> [OCRResult] {
        return [
            OCRResult(text: "Contact Form", boundingBox: CGRect(x: 50, y: 20, width: 200, height: 30), confidence: 0.95),
            OCRResult(text: "Name:", boundingBox: CGRect(x: 50, y: 80, width: 60, height: 20), confidence: 0.9),
            OCRResult(text: "John Doe", boundingBox: CGRect(x: 120, y: 80, width: 150, height: 20), confidence: 0.95),
            OCRResult(text: "Email:", boundingBox: CGRect(x: 50, y: 110, width: 60, height: 20), confidence: 0.9),
            OCRResult(text: "john.doe@example.com", boundingBox: CGRect(x: 120, y: 110, width: 200, height: 20), confidence: 0.95),
            OCRResult(text: "Message:", boundingBox: CGRect(x: 50, y: 140, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "Hello, I would like to...", boundingBox: CGRect(x: 50, y: 170, width: 300, height: 60), confidence: 0.85),
            OCRResult(text: "Submit", boundingBox: CGRect(x: 50, y: 250, width: 80, height: 35), confidence: 0.95),
            OCRResult(text: "Cancel", boundingBox: CGRect(x: 140, y: 250, width: 80, height: 35), confidence: 0.95),
            OCRResult(text: "Home", boundingBox: CGRect(x: 20, y: 10, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "About", boundingBox: CGRect(x: 80, y: 10, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "Contact", boundingBox: CGRect(x: 140, y: 10, width: 60, height: 20), confidence: 0.9)
        ]
    }
    
    private func createSampleJiraOCRResults() -> [OCRResult] {
        return [
            OCRResult(text: "PROJ-123", boundingBox: CGRect(x: 50, y: 20, width: 100, height: 25), confidence: 0.95),
            OCRResult(text: "Story", boundingBox: CGRect(x: 200, y: 20, width: 60, height: 20), confidence: 0.9),
            OCRResult(text: "High", boundingBox: CGRect(x: 300, y: 20, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "Assignee:", boundingBox: CGRect(x: 50, y: 60, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "John Smith", boundingBox: CGRect(x: 140, y: 60, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "Reporter:", boundingBox: CGRect(x: 50, y: 90, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "Jane Doe", boundingBox: CGRect(x: 140, y: 90, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "Story Points:", boundingBox: CGRect(x: 50, y: 120, width: 100, height: 20), confidence: 0.9),
            OCRResult(text: "5", boundingBox: CGRect(x: 160, y: 120, width: 20, height: 20), confidence: 0.95),
            OCRResult(text: "Sprint 23", boundingBox: CGRect(x: 50, y: 150, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "In Progress", boundingBox: CGRect(x: 200, y: 150, width: 100, height: 20), confidence: 0.9),
            OCRResult(text: "Implement new user authentication feature", boundingBox: CGRect(x: 50, y: 200, width: 400, height: 25), confidence: 0.85)
        ]
    }
    
    private func createSampleTerminalOCRResults() -> [OCRResult] {
        return [
            OCRResult(text: "user@macbook:~$", boundingBox: CGRect(x: 10, y: 20, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "ls -la", boundingBox: CGRect(x: 140, y: 20, width: 60, height: 20), confidence: 0.95),
            OCRResult(text: "total 24", boundingBox: CGRect(x: 10, y: 50, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "drwxr-xr-x", boundingBox: CGRect(x: 10, y: 80, width: 100, height: 20), confidence: 0.85),
            OCRResult(text: "5", boundingBox: CGRect(x: 120, y: 80, width: 20, height: 20), confidence: 0.9),
            OCRResult(text: "user", boundingBox: CGRect(x: 150, y: 80, width: 40, height: 20), confidence: 0.9),
            OCRResult(text: "staff", boundingBox: CGRect(x: 200, y: 80, width: 40, height: 20), confidence: 0.9),
            OCRResult(text: "160", boundingBox: CGRect(x: 250, y: 80, width: 30, height: 20), confidence: 0.9),
            OCRResult(text: "Dec 15 10:30", boundingBox: CGRect(x: 290, y: 80, width: 100, height: 20), confidence: 0.85),
            OCRResult(text: "Documents", boundingBox: CGRect(x: 400, y: 80, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "user@macbook:~$", boundingBox: CGRect(x: 10, y: 110, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "git status", boundingBox: CGRect(x: 140, y: 110, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "On branch main", boundingBox: CGRect(x: 10, y: 140, width: 120, height: 20), confidence: 0.9),
            OCRResult(text: "nothing to commit", boundingBox: CGRect(x: 10, y: 170, width: 150, height: 20), confidence: 0.85)
        ]
    }
    
    private func createTestImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Failed to create CGContext")
        }
        
        // Fill with white background
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let image = context.makeImage() else {
            fatalError("Failed to create CGImage")
        }
        
        return image
    }
}

// MARK: - String Extension for Repeat

private extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}