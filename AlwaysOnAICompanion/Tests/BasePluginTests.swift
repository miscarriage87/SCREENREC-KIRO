import XCTest
import CoreGraphics
@testable import AlwaysOnAICompanion

class BasePluginTests: XCTestCase {
    
    var basePlugin: TestableBasePlugin!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BasePluginTests")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        basePlugin = TestableBasePlugin()
    }
    
    override func tearDown() {
        basePlugin.cleanup()
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Base Plugin Tests
    
    func testBasePluginInitialization() {
        XCTAssertEqual(basePlugin.identifier, "com.test.base")
        XCTAssertEqual(basePlugin.name, "Test Base Plugin")
        XCTAssertEqual(basePlugin.version, "1.0.0")
        XCTAssertEqual(basePlugin.description, "A test base plugin")
        XCTAssertEqual(basePlugin.supportedApplications, ["com.test.app"])
        XCTAssertFalse(basePlugin.isInitialized)
    }
    
    func testPluginInitializeAndCleanup() throws {
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        
        try basePlugin.initialize(configuration: config)
        XCTAssertTrue(basePlugin.isInitialized)
        
        basePlugin.cleanup()
        XCTAssertFalse(basePlugin.isInitialized)
    }
    
    func testCanHandleContext() throws {
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        try basePlugin.initialize(configuration: config)
        
        let supportedContext = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test",
            processID: 1234
        )
        
        let unsupportedContext = ApplicationContext(
            bundleID: "com.other.app",
            applicationName: "Other App",
            windowTitle: "Test",
            processID: 5678
        )
        
        XCTAssertTrue(basePlugin.canHandle(context: supportedContext))
        XCTAssertFalse(basePlugin.canHandle(context: unsupportedContext))
    }
    
    func testCanHandleWildcardPattern() throws {
        let wildcardPlugin = TestableBasePlugin(
            supportedApplications: ["com.test.*", "com.example.specific"]
        )
        
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        try wildcardPlugin.initialize(configuration: config)
        
        let matchingContext1 = ApplicationContext(
            bundleID: "com.test.app1",
            applicationName: "Test App 1",
            windowTitle: "Test",
            processID: 1234
        )
        
        let matchingContext2 = ApplicationContext(
            bundleID: "com.test.app2",
            applicationName: "Test App 2",
            windowTitle: "Test",
            processID: 5678
        )
        
        let specificContext = ApplicationContext(
            bundleID: "com.example.specific",
            applicationName: "Specific App",
            windowTitle: "Test",
            processID: 9012
        )
        
        let nonMatchingContext = ApplicationContext(
            bundleID: "com.other.app",
            applicationName: "Other App",
            windowTitle: "Test",
            processID: 3456
        )
        
        XCTAssertTrue(wildcardPlugin.canHandle(context: matchingContext1))
        XCTAssertTrue(wildcardPlugin.canHandle(context: matchingContext2))
        XCTAssertTrue(wildcardPlugin.canHandle(context: specificContext))
        XCTAssertFalse(wildcardPlugin.canHandle(context: nonMatchingContext))
    }
    
    func testCannotHandleWhenNotInitialized() {
        let context = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test",
            processID: 1234
        )
        
        XCTAssertFalse(basePlugin.canHandle(context: context))
    }
    
    // MARK: - Utility Method Tests
    
    func testIsUILabel() {
        XCTAssertTrue(basePlugin.testIsUILabel("Username:"))
        XCTAssertTrue(basePlugin.testIsUILabel("Email Address:"))
        XCTAssertTrue(basePlugin.testIsUILabel("Short Label"))
        
        XCTAssertFalse(basePlugin.testIsUILabel("This is a very long text that is unlikely to be a UI label because it contains multiple sentences and is too verbose."))
        XCTAssertFalse(basePlugin.testIsUILabel("Multi\nline\ntext"))
        XCTAssertFalse(basePlugin.testIsUILabel(""))
    }
    
    func testIsFieldValue() {
        XCTAssertTrue(basePlugin.testIsFieldValue("john.doe@example.com"))
        XCTAssertTrue(basePlugin.testIsFieldValue("Some field value"))
        XCTAssertTrue(basePlugin.testIsFieldValue("123"))
        
        XCTAssertFalse(basePlugin.testIsFieldValue(""))
        XCTAssertFalse(basePlugin.testIsFieldValue("   "))
        XCTAssertFalse(basePlugin.testIsFieldValue("Label:"))
    }
    
    func testExtractFieldPairs() {
        let results = [
            OCRResult(text: "Username:", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "john.doe", boundingBox: CGRect(x: 90, y: 0, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "Password:", boundingBox: CGRect(x: 0, y: 30, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "••••••••", boundingBox: CGRect(x: 90, y: 30, width: 100, height: 20), confidence: 0.8),
            OCRResult(text: "Submit", boundingBox: CGRect(x: 0, y: 60, width: 60, height: 30), confidence: 0.95)
        ]
        
        let pairs = basePlugin.testExtractFieldPairs(from: results)
        
        XCTAssertEqual(pairs.count, 2)
        
        // First pair: Username -> john.doe
        XCTAssertEqual(pairs[0].label.text, "Username:")
        XCTAssertEqual(pairs[0].value?.text, "john.doe")
        
        // Second pair: Password -> ••••••••
        XCTAssertEqual(pairs[1].label.text, "Password:")
        XCTAssertEqual(pairs[1].value?.text, "••••••••")
    }
    
    func testCreateStructuredElement() {
        let labelResult = OCRResult(
            text: "Email:",
            boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20),
            confidence: 0.9
        )
        let valueResult = OCRResult(
            text: "test@example.com",
            boundingBox: CGRect(x: 60, y: 0, width: 120, height: 20),
            confidence: 0.95
        )
        
        let pair = (label: labelResult, value: valueResult)
        let element = basePlugin.testCreateStructuredElement(from: pair)
        
        XCTAssertNotNil(element)
        XCTAssertEqual(element?.type, "field")
        XCTAssertEqual(element?.value as? String, "test@example.com")
        XCTAssertEqual(element?.metadata["label"] as? String, "Email")
        XCTAssertEqual(element?.metadata["confidence"] as? Float, 0.9) // Min of both confidences
        
        let expectedBounds = labelResult.boundingBox.union(valueResult.boundingBox)
        XCTAssertEqual(element?.boundingBox, expectedBounds)
    }
    
    func testDetectButtons() {
        let results = [
            OCRResult(text: "OK", boundingBox: CGRect(x: 0, y: 0, width: 40, height: 30), confidence: 0.9),
            OCRResult(text: "Cancel", boundingBox: CGRect(x: 50, y: 0, width: 60, height: 30), confidence: 0.9),
            OCRResult(text: "SUBMIT", boundingBox: CGRect(x: 120, y: 0, width: 70, height: 30), confidence: 0.9),
            OCRResult(text: "This is not a button", boundingBox: CGRect(x: 0, y: 40, width: 200, height: 20), confidence: 0.9),
            OCRResult(text: "Save", boundingBox: CGRect(x: 0, y: 70, width: 50, height: 30), confidence: 0.9)
        ]
        
        let buttons = basePlugin.testDetectButtons(in: results)
        
        XCTAssertEqual(buttons.count, 4)
        
        let buttonTexts = buttons.map { $0.properties["text"] as? String }
        XCTAssertTrue(buttonTexts.contains("OK"))
        XCTAssertTrue(buttonTexts.contains("Cancel"))
        XCTAssertTrue(buttonTexts.contains("SUBMIT"))
        XCTAssertTrue(buttonTexts.contains("Save"))
        
        // Verify all detected elements are marked as buttons
        XCTAssertTrue(buttons.allSatisfy { $0.type == "button" && $0.isInteractive })
    }
    
    func testCreateEnhancedResult() {
        let originalResult = OCRResult(
            text: "Submit",
            boundingBox: CGRect(x: 0, y: 0, width: 60, height: 30),
            confidence: 0.9
        )
        
        let enhanced = basePlugin.testCreateEnhancedResult(
            from: originalResult,
            semanticType: "button",
            structuredData: ["action": "submit", "primary": true],
            relationships: ["form_123"]
        )
        
        XCTAssertEqual(enhanced.originalResult.text, "Submit")
        XCTAssertEqual(enhanced.semanticType, "button")
        XCTAssertEqual(enhanced.structuredData["action"] as? String, "submit")
        XCTAssertEqual(enhanced.structuredData["primary"] as? Bool, true)
        XCTAssertEqual(enhanced.relationships, ["form_123"])
    }
}

// MARK: - Base Parsing Plugin Tests

class BaseParsingPluginTests: XCTestCase {
    
    var parsingPlugin: TestableBaseParsingPlugin!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BaseParsingPluginTests")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        parsingPlugin = TestableBaseParsingPlugin()
        
        let config = PluginConfiguration(pluginDirectory: tempDirectory)
        try? parsingPlugin.initialize(configuration: config)
    }
    
    override func tearDown() {
        parsingPlugin.cleanup()
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testEnhanceOCRResults() async throws {
        let results = [
            OCRResult(text: "Username:", boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20), confidence: 0.9),
            OCRResult(text: "john.doe", boundingBox: CGRect(x: 90, y: 0, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "Submit", boundingBox: CGRect(x: 0, y: 30, width: 60, height: 30), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test",
            processID: 1234
        )
        
        // Create a test image
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
        ), let image = cgContext.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let enhanced = try await parsingPlugin.enhanceOCRResults(results, context: context, frame: image)
        
        // Should have enhanced results for field pairs and buttons
        XCTAssertGreaterThan(enhanced.count, 0)
        
        let semanticTypes = enhanced.map { $0.semanticType }
        XCTAssertTrue(semanticTypes.contains("field_label"))
        XCTAssertTrue(semanticTypes.contains("field_value"))
        XCTAssertTrue(semanticTypes.contains("button"))
    }
    
    func testExtractStructuredData() async throws {
        let results = [
            OCRResult(text: "Email:", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "test@example.com", boundingBox: CGRect(x: 60, y: 0, width: 120, height: 20), confidence: 0.95),
            OCRResult(text: "Phone:", boundingBox: CGRect(x: 0, y: 30, width: 50, height: 20), confidence: 0.9),
            OCRResult(text: "555-1234", boundingBox: CGRect(x: 60, y: 30, width: 80, height: 20), confidence: 0.9)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test",
            processID: 1234
        )
        
        let structuredData = try await parsingPlugin.extractStructuredData(from: results, context: context)
        
        XCTAssertEqual(structuredData.count, 2)
        
        // Check that we have field elements
        XCTAssertTrue(structuredData.allSatisfy { $0.type == "field" })
        
        let values = structuredData.map { $0.value as? String }
        XCTAssertTrue(values.contains("test@example.com"))
        XCTAssertTrue(values.contains("555-1234"))
    }
    
    func testDetectUIElements() async throws {
        let context = ApplicationContext(
            bundleID: "com.test.app",
            applicationName: "Test App",
            windowTitle: "Test",
            processID: 1234
        )
        
        // Create a test image
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
        ), let image = cgContext.makeImage() else {
            XCTFail("Failed to create test image")
            return
        }
        
        let uiElements = try await parsingPlugin.detectUIElements(in: image, context: context)
        
        // Base implementation returns empty array
        XCTAssertTrue(uiElements.isEmpty)
    }
}

// MARK: - Test Helper Classes

class TestableBasePlugin: BasePlugin {
    var isInitialized: Bool {
        return super.isInitialized
    }
    
    init(supportedApplications: [String] = ["com.test.app"]) {
        super.init(
            identifier: "com.test.base",
            name: "Test Base Plugin",
            version: "1.0.0",
            description: "A test base plugin",
            supportedApplications: supportedApplications
        )
    }
    
    // Expose internal methods for testing
    func testIsUILabel(_ text: String) -> Bool {
        return isUILabel(text)
    }
    
    func testIsFieldValue(_ text: String) -> Bool {
        return isFieldValue(text)
    }
    
    func testExtractFieldPairs(from results: [OCRResult]) -> [(label: OCRResult, value: OCRResult?)] {
        return extractFieldPairs(from: results)
    }
    
    func testCreateStructuredElement(from pair: (label: OCRResult, value: OCRResult?)) -> StructuredDataElement? {
        return createStructuredElement(from: pair)
    }
    
    func testDetectButtons(in results: [OCRResult]) -> [UIElement] {
        return detectButtons(in: results)
    }
    
    func testCreateEnhancedResult(
        from original: OCRResult,
        semanticType: String,
        structuredData: [String: Any] = [:],
        relationships: [String] = []
    ) -> EnhancedOCRResult {
        return createEnhancedResult(
            from: original,
            semanticType: semanticType,
            structuredData: structuredData,
            relationships: relationships
        )
    }
}

class TestableBaseParsingPlugin: BaseParsingPlugin {
    init() {
        super.init(
            identifier: "com.test.parsing",
            name: "Test Parsing Plugin",
            version: "1.0.0",
            description: "A test parsing plugin",
            supportedApplications: ["com.test.app"]
        )
    }
}