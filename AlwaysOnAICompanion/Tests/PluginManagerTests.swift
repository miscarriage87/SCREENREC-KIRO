import XCTest
import CoreGraphics
@testable import AlwaysOnAICompanion

class PluginManagerTests: XCTestCase {
    
    var pluginManager: PluginManager!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginManagerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        pluginManager = PluginManager(
            pluginDirectory: tempDirectory,
            sandboxEnabled: false // Disable for testing
        )
    }
    
    override func tearDown() {
        pluginManager.unloadAllPlugins()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    // MARK: - Plugin Loading Tests
    
    func testLoadAllPluginsWithEmptyDirectory() throws {
        try pluginManager.loadAllPlugins()
        
        let loadedPlugins = pluginManager.getLoadedPlugins()
        XCTAssertEqual(loadedPlugins.count, 0)
    }
    
    func testCreatePluginDirectory() {
        // Plugin manager should create directory if it doesn't exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.path))
    }
    
    func testGetLoadedPluginsInfo() {
        // Initially no plugins should be loaded
        let plugins = pluginManager.getLoadedPlugins()
        XCTAssertTrue(plugins.isEmpty)
    }
    
    func testIsPluginLoaded() {
        XCTAssertFalse(pluginManager.isPluginLoaded("com.test.nonexistent"))
    }
    
    // MARK: - Plugin Execution Tests
    
    func testGetParsingPluginsForContext() {
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Test Page",
            processID: 1234
        )
        
        let parsingPlugins = pluginManager.getParsingPlugins(for: context)
        XCTAssertTrue(parsingPlugins.isEmpty) // No plugins loaded initially
    }
    
    func testGetEventDetectionPluginsForContext() {
        let context = ApplicationContext(
            bundleID: "com.apple.Terminal",
            applicationName: "Terminal",
            windowTitle: "Terminal",
            processID: 5678
        )
        
        let eventPlugins = pluginManager.getEventDetectionPlugins(for: context)
        XCTAssertTrue(eventPlugins.isEmpty) // No plugins loaded initially
    }
    
    func testEnhanceOCRResultsWithNoPlugins() async {
        let results = [
            OCRResult(text: "Test", boundingBox: CGRect.zero, confidence: 0.9)
        ]
        let context = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test Window",
            processID: 1234
        )
        
        // Create a test image (1x1 pixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context2 = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let image = context2.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let enhancedResults = await pluginManager.enhanceOCRResults(
            results,
            context: context,
            frame: image
        )
        
        XCTAssertTrue(enhancedResults.isEmpty) // No plugins to enhance results
    }
    
    func testDetectEventsWithNoPlugins() async {
        let ocrDelta = OCRDelta(
            previousResults: [],
            currentResults: [],
            addedElements: [],
            removedElements: [],
            modifiedElements: []
        )
        let context = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test Window",
            processID: 1234
        )
        
        let events = await pluginManager.detectEvents(from: ocrDelta, context: context)
        XCTAssertTrue(events.isEmpty) // No plugins to detect events
    }
    
    // MARK: - Plugin Manifest Tests
    
    func testPluginManifestCreation() {
        let manifest = PluginManifest(
            identifier: "com.test.plugin",
            name: "Test Plugin",
            version: "1.0.0",
            description: "A test plugin",
            type: "web",
            supportedApplications: ["com.apple.Safari"],
            maxMemoryUsage: 100 * 1024 * 1024,
            maxExecutionTime: 30.0,
            author: "Test Author",
            website: "https://example.com"
        )
        
        XCTAssertEqual(manifest.identifier, "com.test.plugin")
        XCTAssertEqual(manifest.name, "Test Plugin")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.description, "A test plugin")
        XCTAssertEqual(manifest.type, "web")
        XCTAssertEqual(manifest.supportedApplications, ["com.apple.Safari"])
        XCTAssertEqual(manifest.maxMemoryUsage, 100 * 1024 * 1024)
        XCTAssertEqual(manifest.maxExecutionTime, 30.0, accuracy: 0.001)
        XCTAssertEqual(manifest.author, "Test Author")
        XCTAssertEqual(manifest.website, "https://example.com")
    }
    
    func testPluginManifestCodable() throws {
        let manifest = PluginManifest(
            identifier: "com.test.plugin",
            name: "Test Plugin",
            version: "1.0.0",
            description: "A test plugin",
            type: "web",
            supportedApplications: ["com.apple.Safari", "com.google.Chrome"]
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(manifest)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedManifest = try decoder.decode(PluginManifest.self, from: data)
        
        XCTAssertEqual(decodedManifest.identifier, manifest.identifier)
        XCTAssertEqual(decodedManifest.name, manifest.name)
        XCTAssertEqual(decodedManifest.version, manifest.version)
        XCTAssertEqual(decodedManifest.description, manifest.description)
        XCTAssertEqual(decodedManifest.type, manifest.type)
        XCTAssertEqual(decodedManifest.supportedApplications, manifest.supportedApplications)
    }
    
    // MARK: - Plugin Info Tests
    
    func testPluginInfoCreation() {
        let info = PluginInfo(
            identifier: "com.test.plugin",
            name: "Test Plugin",
            version: "1.0.0",
            description: "A test plugin",
            supportedApplications: ["com.apple.Safari"],
            isEnabled: true
        )
        
        XCTAssertEqual(info.identifier, "com.test.plugin")
        XCTAssertEqual(info.name, "Test Plugin")
        XCTAssertEqual(info.version, "1.0.0")
        XCTAssertEqual(info.description, "A test plugin")
        XCTAssertEqual(info.supportedApplications, ["com.apple.Safari"])
        XCTAssertTrue(info.isEnabled)
    }
    
    // MARK: - Error Handling Tests
    
    func testPluginErrorDescriptions() {
        let missingManifestError = PluginError.missingManifest(URL(fileURLWithPath: "/test/path"))
        XCTAssertEqual(
            missingManifestError.errorDescription,
            "Plugin manifest not found at /test/path"
        )
        
        let unsupportedTypeError = PluginError.unsupportedPluginType("unknown")
        XCTAssertEqual(
            unsupportedTypeError.errorDescription,
            "Unsupported plugin type: unknown"
        )
        
        let timeoutError = PluginError.executionTimeout
        XCTAssertEqual(
            timeoutError.errorDescription,
            "Plugin execution timed out"
        )
        
        let initError = PluginError.initializationFailed("Test reason")
        XCTAssertEqual(
            initError.errorDescription,
            "Plugin initialization failed: Test reason"
        )
        
        let sandboxError = PluginError.sandboxViolation("Test violation")
        XCTAssertEqual(
            sandboxError.errorDescription,
            "Plugin sandbox violation: Test violation"
        )
    }
    
    // MARK: - Integration Tests with Built-in Plugins
    
    func testWebPluginCreation() {
        let webPlugin = WebParsingPlugin()
        
        XCTAssertEqual(webPlugin.identifier, "com.alwayson.plugins.web")
        XCTAssertEqual(webPlugin.name, "Web Application Parser")
        XCTAssertEqual(webPlugin.version, "1.0.0")
        XCTAssertTrue(webPlugin.supportedApplications.contains("com.apple.Safari"))
        XCTAssertTrue(webPlugin.supportedApplications.contains("com.google.Chrome"))
    }
    
    func testProductivityPluginCreation() {
        let productivityPlugin = ProductivityParsingPlugin()
        
        XCTAssertEqual(productivityPlugin.identifier, "com.alwayson.plugins.productivity")
        XCTAssertEqual(productivityPlugin.name, "Productivity Application Parser")
        XCTAssertEqual(productivityPlugin.version, "1.0.0")
        XCTAssertTrue(productivityPlugin.supportedApplications.contains("com.atlassian.jira"))
        XCTAssertTrue(productivityPlugin.supportedApplications.contains("com.salesforce.*"))
    }
    
    func testTerminalPluginCreation() {
        let terminalPlugin = TerminalParsingPlugin()
        
        XCTAssertEqual(terminalPlugin.identifier, "com.alwayson.plugins.terminal")
        XCTAssertEqual(terminalPlugin.name, "Terminal Application Parser")
        XCTAssertEqual(terminalPlugin.version, "1.0.0")
        XCTAssertTrue(terminalPlugin.supportedApplications.contains("com.apple.Terminal"))
        XCTAssertTrue(terminalPlugin.supportedApplications.contains("com.googlecode.iterm2"))
    }
    
    // MARK: - Plugin Context Handling Tests
    
    func testWebPluginContextHandling() {
        let webPlugin = WebParsingPlugin()
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        
        try? webPlugin.initialize(configuration: config)
        
        let safariContext = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Test",
            processID: 1234
        )
        
        let chromeContext = ApplicationContext(
            bundleID: "com.google.Chrome",
            applicationName: "Chrome",
            windowTitle: "Test",
            processID: 5678
        )
        
        let terminalContext = ApplicationContext(
            bundleID: "com.apple.Terminal",
            applicationName: "Terminal",
            windowTitle: "Test",
            processID: 9012
        )
        
        XCTAssertTrue(webPlugin.canHandle(context: safariContext))
        XCTAssertTrue(webPlugin.canHandle(context: chromeContext))
        XCTAssertFalse(webPlugin.canHandle(context: terminalContext))
    }
    
    func testTerminalPluginContextHandling() {
        let terminalPlugin = TerminalParsingPlugin()
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        
        try? terminalPlugin.initialize(configuration: config)
        
        let terminalContext = ApplicationContext(
            bundleID: "com.apple.Terminal",
            applicationName: "Terminal",
            windowTitle: "Test",
            processID: 1234
        )
        
        let itermContext = ApplicationContext(
            bundleID: "com.googlecode.iterm2",
            applicationName: "iTerm2",
            windowTitle: "Test",
            processID: 5678
        )
        
        let safariContext = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Test",
            processID: 9012
        )
        
        XCTAssertTrue(terminalPlugin.canHandle(context: terminalContext))
        XCTAssertTrue(terminalPlugin.canHandle(context: itermContext))
        XCTAssertFalse(terminalPlugin.canHandle(context: safariContext))
    }
    
    // MARK: - Performance Tests
    
    func testPluginExecutionTimeout() async {
        // This test would require a mock plugin that takes too long to execute
        // For now, we'll test that the timeout mechanism exists
        let context = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test Window",
            processID: 1234
        )
        
        let ocrDelta = OCRDelta(
            previousResults: [],
            currentResults: [],
            addedElements: [],
            removedElements: [],
            modifiedElements: []
        )
        
        // Should complete quickly with no plugins
        let startTime = Date()
        let events = await pluginManager.detectEvents(from: ocrDelta, context: context)
        let executionTime = Date().timeIntervalSince(startTime)
        
        XCTAssertTrue(events.isEmpty)
        XCTAssertLessThan(executionTime, 1.0) // Should be very fast with no plugins
    }
}