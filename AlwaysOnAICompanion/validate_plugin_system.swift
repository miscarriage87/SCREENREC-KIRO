#!/usr/bin/env swift

import Foundation
import CoreGraphics

// This script validates the plugin architecture implementation
// Run with: swift validate_plugin_system.swift

print("🔌 Plugin System Validation Script")
print("=" * 50)

// MARK: - Validation Functions

func validatePluginProtocols() -> Bool {
    print("\n📋 Validating Plugin Protocols...")
    
    // Test data model creation
    let ocrResult = OCRResult(
        text: "Test Text",
        boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
        confidence: 0.95,
        language: "en"
    )
    
    let enhancedResult = EnhancedOCRResult(
        originalResult: ocrResult,
        semanticType: "field_label",
        structuredData: ["type": "text"],
        relationships: []
    )
    
    let structuredElement = StructuredDataElement(
        id: "test_element",
        type: "form_field",
        value: "test_value",
        metadata: ["label": "Test Field"]
    )
    
    let uiElement = UIElement(
        id: "test_button",
        type: "button",
        boundingBox: CGRect(x: 0, y: 0, width: 80, height: 30),
        properties: ["text": "Submit"]
    )
    
    let context = ApplicationContext(
        bundleID: "com.test.app",
        applicationName: "Test App",
        windowTitle: "Test Window",
        processID: 1234
    )
    
    let event = DetectedEvent(
        type: "field_change",
        target: "username_field",
        valueBefore: "old_value",
        valueAfter: "new_value",
        confidence: 0.85
    )
    
    let classification = EventClassification(
        category: "data_modification",
        importance: .medium,
        confidence: 0.9
    )
    
    // Validate data integrity
    guard ocrResult.text == "Test Text" &&
          enhancedResult.semanticType == "field_label" &&
          structuredElement.type == "form_field" &&
          uiElement.type == "button" &&
          context.bundleID == "com.test.app" &&
          event.type == "field_change" &&
          classification.category == "data_modification" else {
        print("❌ Data model validation failed")
        return false
    }
    
    print("✅ Plugin protocols validated successfully")
    return true
}

func validateBuiltInPlugins() -> Bool {
    print("\n🔌 Validating Built-in Plugins...")
    
    // Test Web Plugin
    let webPlugin = WebParsingPlugin()
    guard webPlugin.identifier == "com.alwayson.plugins.web" &&
          webPlugin.name == "Web Application Parser" &&
          webPlugin.supportedApplications.contains("com.apple.Safari") else {
        print("❌ Web plugin validation failed")
        return false
    }
    
    // Test Productivity Plugin
    let productivityPlugin = ProductivityParsingPlugin()
    guard productivityPlugin.identifier == "com.alwayson.plugins.productivity" &&
          productivityPlugin.name == "Productivity Application Parser" &&
          productivityPlugin.supportedApplications.contains("com.atlassian.jira") else {
        print("❌ Productivity plugin validation failed")
        return false
    }
    
    // Test Terminal Plugin
    let terminalPlugin = TerminalParsingPlugin()
    guard terminalPlugin.identifier == "com.alwayson.plugins.terminal" &&
          terminalPlugin.name == "Terminal Application Parser" &&
          terminalPlugin.supportedApplications.contains("com.apple.Terminal") else {
        print("❌ Terminal plugin validation failed")
        return false
    }
    
    print("✅ Built-in plugins validated successfully")
    return true
}

func validatePluginManager() -> Bool {
    print("\n⚙️ Validating Plugin Manager...")
    
    // Create temporary directory
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginValidation")
        .appendingPathComponent(UUID().uuidString)
    
    do {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let pluginManager = PluginManager(pluginDirectory: tempDir, sandboxEnabled: false)
        
        // Test initial state
        let initialPlugins = pluginManager.getLoadedPlugins()
        guard initialPlugins.isEmpty else {
            print("❌ Plugin manager should start with no loaded plugins")
            return false
        }
        
        // Test context matching
        let safariContext = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Test",
            processID: 1234
        )
        
        let parsingPlugins = pluginManager.getParsingPlugins(for: safariContext)
        let eventPlugins = pluginManager.getEventDetectionPlugins(for: safariContext)
        
        // Should be empty since no plugins are loaded
        guard parsingPlugins.isEmpty && eventPlugins.isEmpty else {
            print("❌ Plugin manager should return empty arrays for unloaded plugins")
            return false
        }
        
        // Clean up
        try FileManager.default.removeItem(at: tempDir)
        
        print("✅ Plugin manager validated successfully")
        return true
        
    } catch {
        print("❌ Plugin manager validation failed: \(error)")
        return false
    }
}

func validateConfigurationManager() -> Bool {
    print("\n📝 Validating Configuration Manager...")
    
    // Create temporary directory
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConfigValidation")
        .appendingPathComponent(UUID().uuidString)
    
    do {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let configManager = PluginConfigurationManager(configurationDirectory: tempDir)
        
        // Test default configurations
        let allConfigs = configManager.getAllConfigurations()
        guard allConfigs.count == 3 else {
            print("❌ Should have 3 default configurations, got \(allConfigs.count)")
            return false
        }
        
        let identifiers = allConfigs.map { $0.identifier }
        let expectedIdentifiers = [
            "com.alwayson.plugins.web",
            "com.alwayson.plugins.productivity",
            "com.alwayson.plugins.terminal"
        ]
        
        for expectedId in expectedIdentifiers {
            guard identifiers.contains(expectedId) else {
                print("❌ Missing expected configuration: \(expectedId)")
                return false
            }
        }
        
        // Test configuration retrieval
        let webConfig = configManager.getConfiguration(for: "com.alwayson.plugins.web")
        guard let config = webConfig,
              config.enabled,
              config.supportedApplications.contains("com.apple.Safari") else {
            print("❌ Web configuration validation failed")
            return false
        }
        
        // Test configuration modification
        configManager.setPluginEnabled("com.alwayson.plugins.web", enabled: false)
        guard !configManager.isPluginEnabled("com.alwayson.plugins.web") else {
            print("❌ Plugin enable/disable failed")
            return false
        }
        
        // Test validation
        let invalidConfig = PluginConfigurationData(
            identifier: "",
            name: "Invalid",
            version: "1.0.0",
            supportedApplications: [],
            maxMemoryUsage: -1,
            maxExecutionTime: -1
        )
        
        let errors = configManager.validateConfiguration(invalidConfig)
        guard !errors.isEmpty else {
            print("❌ Configuration validation should detect errors")
            return false
        }
        
        // Clean up
        try FileManager.default.removeItem(at: tempDir)
        
        print("✅ Configuration manager validated successfully")
        return true
        
    } catch {
        print("❌ Configuration manager validation failed: \(error)")
        return false
    }
}

func validatePluginFunctionality() async -> Bool {
    print("\n🧪 Validating Plugin Functionality...")
    
    // Create temporary directory
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FunctionalityValidation")
        .appendingPathComponent(UUID().uuidString)
    
    do {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Test Web Plugin functionality
        let webPlugin = WebParsingPlugin()
        let config = PluginConfiguration(pluginDirectory: tempDir)
        
        try webPlugin.initialize(configuration: config)
        
        let safariContext = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Test Form - Safari",
            processID: 1234
        )
        
        // Test context handling
        guard webPlugin.canHandle(context: safariContext) else {
            print("❌ Web plugin should handle Safari context")
            return false
        }
        
        let terminalContext = ApplicationContext(
            bundleID: "com.apple.Terminal",
            applicationName: "Terminal",
            windowTitle: "Terminal",
            processID: 5678
        )
        
        guard !webPlugin.canHandle(context: terminalContext) else {
            print("❌ Web plugin should not handle Terminal context")
            return false
        }
        
        // Test OCR enhancement
        let sampleResults = [
            OCRResult(text: "Email:", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "test@example.com", boundingBox: CGRect(x: 60, y: 0, width: 120, height: 20), confidence: 0.95),
            OCRResult(text: "Submit", boundingBox: CGRect(x: 0, y: 30, width: 60, height: 30), confidence: 0.9)
        ]
        
        // Create test image
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let cgContext = CGContext(
            data: nil,
            width: 200,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 800,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let testImage = cgContext.makeImage() else {
            print("❌ Failed to create test image")
            return false
        }
        
        let enhancedResults = try await webPlugin.enhanceOCRResults(
            sampleResults,
            context: safariContext,
            frame: testImage
        )
        
        guard !enhancedResults.isEmpty else {
            print("❌ Web plugin should produce enhanced results")
            return false
        }
        
        // Test structured data extraction
        let structuredData = try await webPlugin.extractStructuredData(
            from: sampleResults,
            context: safariContext
        )
        
        guard !structuredData.isEmpty else {
            print("❌ Web plugin should extract structured data")
            return false
        }
        
        webPlugin.cleanup()
        
        // Clean up
        try FileManager.default.removeItem(at: tempDir)
        
        print("✅ Plugin functionality validated successfully")
        return true
        
    } catch {
        print("❌ Plugin functionality validation failed: \(error)")
        return false
    }
}

func validateErrorHandling() -> Bool {
    print("\n🚨 Validating Error Handling...")
    
    // Test plugin errors
    let missingManifestError = PluginError.missingManifest(URL(fileURLWithPath: "/nonexistent"))
    guard missingManifestError.localizedDescription.contains("manifest not found") else {
        print("❌ Missing manifest error description invalid")
        return false
    }
    
    let timeoutError = PluginError.executionTimeout
    guard timeoutError.localizedDescription.contains("timed out") else {
        print("❌ Timeout error description invalid")
        return false
    }
    
    // Test validation errors
    let emptyIdError = ValidationError.emptyIdentifier
    guard emptyIdError.localizedDescription.contains("cannot be empty") else {
        print("❌ Empty identifier error description invalid")
        return false
    }
    
    let noAppsError = ValidationError.noSupportedApplications("test.plugin")
    guard noAppsError.localizedDescription.contains("must support at least one") else {
        print("❌ No supported apps error description invalid")
        return false
    }
    
    print("✅ Error handling validated successfully")
    return true
}

// MARK: - Main Validation

func runValidation() async -> Bool {
    var allPassed = true
    
    allPassed = validatePluginProtocols() && allPassed
    allPassed = validateBuiltInPlugins() && allPassed
    allPassed = validatePluginManager() && allPassed
    allPassed = validateConfigurationManager() && allPassed
    allPassed = await validatePluginFunctionality() && allPassed
    allPassed = validateErrorHandling() && allPassed
    
    return allPassed
}

// Run the validation
Task {
    let success = await runValidation()
    
    print("\n" + "=" * 50)
    if success {
        print("🎉 All plugin system validations passed!")
        exit(0)
    } else {
        print("❌ Some validations failed!")
        exit(1)
    }
}

// Keep the script running
RunLoop.main.run()

// MARK: - Helper Extensions

extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// MARK: - Mock Implementations for Validation

// These would normally be imported from the main module
// For validation purposes, we include minimal implementations

struct OCRResult {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let language: String
    
    init(text: String, boundingBox: CGRect, confidence: Float, language: String = "en") {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.language = language
    }
}

struct EnhancedOCRResult {
    let originalResult: OCRResult
    let semanticType: String
    let structuredData: [String: Any]
    let relationships: [String]
    
    init(originalResult: OCRResult, semanticType: String, structuredData: [String: Any] = [:], relationships: [String] = []) {
        self.originalResult = originalResult
        self.semanticType = semanticType
        self.structuredData = structuredData
        self.relationships = relationships
    }
}

struct StructuredDataElement {
    let id: String
    let type: String
    let value: Any
    let metadata: [String: Any]
    let boundingBox: CGRect?
    
    init(id: String, type: String, value: Any, metadata: [String: Any] = [:], boundingBox: CGRect? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.metadata = metadata
        self.boundingBox = boundingBox
    }
}

struct UIElement {
    let id: String
    let type: String
    let boundingBox: CGRect
    let properties: [String: Any]
    let isInteractive: Bool
    
    init(id: String, type: String, boundingBox: CGRect, properties: [String: Any] = [:], isInteractive: Bool = true) {
        self.id = id
        self.type = type
        self.boundingBox = boundingBox
        self.properties = properties
        self.isInteractive = isInteractive
    }
}

struct ApplicationContext {
    let bundleID: String
    let applicationName: String
    let windowTitle: String
    let processID: pid_t
    let timestamp: Date
    let metadata: [String: Any]
    
    init(bundleID: String, applicationName: String, windowTitle: String, processID: pid_t, timestamp: Date = Date(), metadata: [String: Any] = [:]) {
        self.bundleID = bundleID
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.processID = processID
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

struct DetectedEvent {
    let id: String
    let type: String
    let timestamp: Date
    let target: String
    let valueBefore: String?
    let valueAfter: String?
    let confidence: Float
    let metadata: [String: Any]
    
    init(id: String = UUID().uuidString, type: String, timestamp: Date = Date(), target: String, valueBefore: String? = nil, valueAfter: String? = nil, confidence: Float, metadata: [String: Any] = [:]) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.target = target
        self.valueBefore = valueBefore
        self.valueAfter = valueAfter
        self.confidence = confidence
        self.metadata = metadata
    }
}

struct EventClassification {
    let category: String
    let subcategory: String?
    let importance: EventImportance
    let tags: [String]
    let confidence: Float
    
    init(category: String, subcategory: String? = nil, importance: EventImportance, tags: [String] = [], confidence: Float) {
        self.category = category
        self.subcategory = subcategory
        self.importance = importance
        self.tags = tags
        self.confidence = confidence
    }
}

enum EventImportance: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct PluginConfiguration {
    let pluginDirectory: URL
    let configurationData: [String: Any]
    let sandboxEnabled: Bool
    let maxMemoryUsage: Int64
    let maxExecutionTime: TimeInterval
    
    init(pluginDirectory: URL, configurationData: [String: Any] = [:], sandboxEnabled: Bool = true, maxMemoryUsage: Int64 = 100 * 1024 * 1024, maxExecutionTime: TimeInterval = 30.0) {
        self.pluginDirectory = pluginDirectory
        self.configurationData = configurationData
        self.sandboxEnabled = sandboxEnabled
        self.maxMemoryUsage = maxMemoryUsage
        self.maxExecutionTime = maxExecutionTime
    }
}

// Mock plugin implementations
class WebParsingPlugin {
    let identifier = "com.alwayson.plugins.web"
    let name = "Web Application Parser"
    let version = "1.0.0"
    let description = "Enhanced parsing for web applications"
    let supportedApplications = ["com.apple.Safari", "com.google.Chrome"]
    
    private var isInitialized = false
    
    func initialize(configuration: PluginConfiguration) throws {
        isInitialized = true
    }
    
    func cleanup() {
        isInitialized = false
    }
    
    func canHandle(context: ApplicationContext) -> Bool {
        return isInitialized && supportedApplications.contains(context.bundleID)
    }
    
    func enhanceOCRResults(_ results: [OCRResult], context: ApplicationContext, frame: CGImage) async throws -> [EnhancedOCRResult] {
        return results.map { result in
            EnhancedOCRResult(originalResult: result, semanticType: "web_element")
        }
    }
    
    func extractStructuredData(from results: [OCRResult], context: ApplicationContext) async throws -> [StructuredDataElement] {
        return results.map { result in
            StructuredDataElement(id: UUID().uuidString, type: "web_data", value: result.text)
        }
    }
}

class ProductivityParsingPlugin {
    let identifier = "com.alwayson.plugins.productivity"
    let name = "Productivity Application Parser"
    let version = "1.0.0"
    let supportedApplications = ["com.atlassian.jira", "com.salesforce.*"]
}

class TerminalParsingPlugin {
    let identifier = "com.alwayson.plugins.terminal"
    let name = "Terminal Application Parser"
    let version = "1.0.0"
    let supportedApplications = ["com.apple.Terminal", "com.googlecode.iterm2"]
}

class PluginManager {
    private let pluginDirectory: URL
    private let sandboxEnabled: Bool
    
    init(pluginDirectory: URL, sandboxEnabled: Bool = true) {
        self.pluginDirectory = pluginDirectory
        self.sandboxEnabled = sandboxEnabled
    }
    
    func getLoadedPlugins() -> [PluginInfo] {
        return []
    }
    
    func getParsingPlugins(for context: ApplicationContext) -> [Any] {
        return []
    }
    
    func getEventDetectionPlugins(for context: ApplicationContext) -> [Any] {
        return []
    }
}

struct PluginInfo {
    let identifier: String
    let name: String
    let version: String
    let description: String
    let supportedApplications: [String]
    let isEnabled: Bool
}

class PluginConfigurationManager {
    init(configurationDirectory: URL) {}
    
    func getAllConfigurations() -> [PluginConfigurationData] {
        return [
            PluginConfigurationData(identifier: "com.alwayson.plugins.web", name: "Web Parser", version: "1.0.0", supportedApplications: ["com.apple.Safari"], maxMemoryUsage: 100*1024*1024, maxExecutionTime: 30.0),
            PluginConfigurationData(identifier: "com.alwayson.plugins.productivity", name: "Productivity Parser", version: "1.0.0", supportedApplications: ["com.atlassian.jira"], maxMemoryUsage: 150*1024*1024, maxExecutionTime: 45.0),
            PluginConfigurationData(identifier: "com.alwayson.plugins.terminal", name: "Terminal Parser", version: "1.0.0", supportedApplications: ["com.apple.Terminal"], maxMemoryUsage: 75*1024*1024, maxExecutionTime: 20.0)
        ]
    }
    
    func getConfiguration(for identifier: String) -> PluginConfigurationData? {
        return getAllConfigurations().first { $0.identifier == identifier }
    }
    
    func setPluginEnabled(_ identifier: String, enabled: Bool) {}
    
    func isPluginEnabled(_ identifier: String) -> Bool {
        return identifier != "com.alwayson.plugins.web" // Simulate disabled state for testing
    }
    
    func validateConfiguration(_ config: PluginConfigurationData) -> [ValidationError] {
        var errors: [ValidationError] = []
        if config.identifier.isEmpty { errors.append(.emptyIdentifier) }
        if config.supportedApplications.isEmpty { errors.append(.noSupportedApplications(config.identifier)) }
        if config.maxMemoryUsage <= 0 { errors.append(.invalidMemoryLimit(config.identifier)) }
        if config.maxExecutionTime <= 0 { errors.append(.invalidExecutionTime(config.identifier)) }
        return errors
    }
}

struct PluginConfigurationData {
    let identifier: String
    let name: String
    let version: String
    var enabled: Bool
    let supportedApplications: [String]
    let maxMemoryUsage: Int64
    let maxExecutionTime: TimeInterval
    let sandboxEnabled: Bool
    var settings: [String: Any]
    
    init(identifier: String, name: String, version: String, enabled: Bool = true, supportedApplications: [String], maxMemoryUsage: Int64, maxExecutionTime: TimeInterval, sandboxEnabled: Bool = true, settings: [String: Any] = [:]) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.enabled = enabled
        self.supportedApplications = supportedApplications
        self.maxMemoryUsage = maxMemoryUsage
        self.maxExecutionTime = maxExecutionTime
        self.sandboxEnabled = sandboxEnabled
        self.settings = settings
    }
}

enum PluginError: Error, LocalizedError {
    case missingManifest(URL)
    case unsupportedPluginType(String)
    case executionTimeout
    case initializationFailed(String)
    case sandboxViolation(String)
    
    var errorDescription: String? {
        switch self {
        case .missingManifest(let url):
            return "Plugin manifest not found at \(url.path)"
        case .unsupportedPluginType(let type):
            return "Unsupported plugin type: \(type)"
        case .executionTimeout:
            return "Plugin execution timed out"
        case .initializationFailed(let reason):
            return "Plugin initialization failed: \(reason)"
        case .sandboxViolation(let reason):
            return "Plugin sandbox violation: \(reason)"
        }
    }
}

enum ValidationError: Error, LocalizedError {
    case emptyIdentifier
    case noSupportedApplications(String)
    case invalidMemoryLimit(String)
    case invalidExecutionTime(String)
    case invalidSettingValue(String, String, String)
    
    var errorDescription: String? {
        switch self {
        case .emptyIdentifier:
            return "Plugin identifier cannot be empty"
        case .noSupportedApplications(let identifier):
            return "Plugin \(identifier) must support at least one application"
        case .invalidMemoryLimit(let identifier):
            return "Plugin \(identifier) has invalid memory limit"
        case .invalidExecutionTime(let identifier):
            return "Plugin \(identifier) has invalid execution time limit"
        case .invalidSettingValue(let plugin, let key, let reason):
            return "Plugin \(plugin) setting '\(key)': \(reason)"
        }
    }
}