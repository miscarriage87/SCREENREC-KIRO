import XCTest
import CoreGraphics
@testable import AlwaysOnAICompanion

class PluginProtocolTests: XCTestCase {
    
    // MARK: - Test Data Models
    
    func testOCRResult() {
        let result = OCRResult(
            text: "Test Text",
            boundingBox: CGRect(x: 10, y: 20, width: 100, height: 30),
            confidence: 0.95,
            language: "en"
        )
        
        XCTAssertEqual(result.text, "Test Text")
        XCTAssertEqual(result.boundingBox, CGRect(x: 10, y: 20, width: 100, height: 30))
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
        XCTAssertEqual(result.language, "en")
    }
    
    func testEnhancedOCRResult() {
        let originalResult = OCRResult(
            text: "Username:",
            boundingBox: CGRect(x: 0, y: 0, width: 80, height: 20),
            confidence: 0.9
        )
        
        let enhanced = EnhancedOCRResult(
            originalResult: originalResult,
            semanticType: "field_label",
            structuredData: ["input_type": "text"],
            relationships: ["field_123"]
        )
        
        XCTAssertEqual(enhanced.originalResult.text, "Username:")
        XCTAssertEqual(enhanced.semanticType, "field_label")
        XCTAssertEqual(enhanced.structuredData["input_type"] as? String, "text")
        XCTAssertEqual(enhanced.relationships, ["field_123"])
    }
    
    func testStructuredDataElement() {
        let element = StructuredDataElement(
            id: "test_element",
            type: "form_field",
            value: "john.doe@example.com",
            metadata: ["label": "Email", "required": true],
            boundingBox: CGRect(x: 0, y: 0, width: 200, height: 25)
        )
        
        XCTAssertEqual(element.id, "test_element")
        XCTAssertEqual(element.type, "form_field")
        XCTAssertEqual(element.value as? String, "john.doe@example.com")
        XCTAssertEqual(element.metadata["label"] as? String, "Email")
        XCTAssertEqual(element.metadata["required"] as? Bool, true)
        XCTAssertNotNil(element.boundingBox)
    }
    
    func testUIElement() {
        let element = UIElement(
            id: "button_submit",
            type: "button",
            boundingBox: CGRect(x: 100, y: 200, width: 80, height: 30),
            properties: ["text": "Submit", "enabled": true],
            isInteractive: true
        )
        
        XCTAssertEqual(element.id, "button_submit")
        XCTAssertEqual(element.type, "button")
        XCTAssertEqual(element.properties["text"] as? String, "Submit")
        XCTAssertEqual(element.properties["enabled"] as? Bool, true)
        XCTAssertTrue(element.isInteractive)
    }
    
    func testApplicationContext() {
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Google - Safari",
            processID: 1234,
            timestamp: Date(),
            metadata: ["url": "https://www.google.com"]
        )
        
        XCTAssertEqual(context.bundleID, "com.apple.Safari")
        XCTAssertEqual(context.applicationName, "Safari")
        XCTAssertEqual(context.windowTitle, "Google - Safari")
        XCTAssertEqual(context.processID, 1234)
        XCTAssertEqual(context.metadata["url"] as? String, "https://www.google.com")
    }
    
    func testDetectedEvent() {
        let event = DetectedEvent(
            type: "field_change",
            target: "username_field",
            valueBefore: "old_value",
            valueAfter: "new_value",
            confidence: 0.85,
            metadata: ["app": "com.example.app"]
        )
        
        XCTAssertEqual(event.type, "field_change")
        XCTAssertEqual(event.target, "username_field")
        XCTAssertEqual(event.valueBefore, "old_value")
        XCTAssertEqual(event.valueAfter, "new_value")
        XCTAssertEqual(event.confidence, 0.85, accuracy: 0.001)
        XCTAssertEqual(event.metadata["app"] as? String, "com.example.app")
    }
    
    func testEventClassification() {
        let classification = EventClassification(
            category: "data_modification",
            subcategory: "form_input",
            importance: .medium,
            tags: ["user_input", "form"],
            confidence: 0.9
        )
        
        XCTAssertEqual(classification.category, "data_modification")
        XCTAssertEqual(classification.subcategory, "form_input")
        XCTAssertEqual(classification.importance, .medium)
        XCTAssertEqual(classification.tags, ["user_input", "form"])
        XCTAssertEqual(classification.confidence, 0.9, accuracy: 0.001)
    }
    
    func testEventImportance() {
        XCTAssertEqual(EventImportance.low.rawValue, "low")
        XCTAssertEqual(EventImportance.medium.rawValue, "medium")
        XCTAssertEqual(EventImportance.high.rawValue, "high")
        XCTAssertEqual(EventImportance.critical.rawValue, "critical")
        
        XCTAssertEqual(EventImportance.allCases.count, 4)
    }
    
    func testPluginConfiguration() {
        let config = PluginConfiguration(
            pluginDirectory: URL(fileURLWithPath: "/test/plugins"),
            configurationData: ["timeout": 30, "enabled": true],
            sandboxEnabled: true,
            maxMemoryUsage: 50 * 1024 * 1024,
            maxExecutionTime: 15.0
        )
        
        XCTAssertEqual(config.pluginDirectory.path, "/test/plugins")
        XCTAssertEqual(config.configurationData["timeout"] as? Int, 30)
        XCTAssertEqual(config.configurationData["enabled"] as? Bool, true)
        XCTAssertTrue(config.sandboxEnabled)
        XCTAssertEqual(config.maxMemoryUsage, 50 * 1024 * 1024)
        XCTAssertEqual(config.maxExecutionTime, 15.0, accuracy: 0.001)
    }
    
    func testOCRDelta() {
        let previous = [
            OCRResult(text: "Old Text", boundingBox: CGRect.zero, confidence: 0.9)
        ]
        let current = [
            OCRResult(text: "New Text", boundingBox: CGRect.zero, confidence: 0.9)
        ]
        let added = [
            OCRResult(text: "Added Text", boundingBox: CGRect.zero, confidence: 0.8)
        ]
        let removed = [
            OCRResult(text: "Removed Text", boundingBox: CGRect.zero, confidence: 0.7)
        ]
        let modified = [(
            previous: OCRResult(text: "Old", boundingBox: CGRect.zero, confidence: 0.9),
            current: OCRResult(text: "New", boundingBox: CGRect.zero, confidence: 0.9)
        )]
        
        let delta = OCRDelta(
            previousResults: previous,
            currentResults: current,
            addedElements: added,
            removedElements: removed,
            modifiedElements: modified
        )
        
        XCTAssertEqual(delta.previousResults.count, 1)
        XCTAssertEqual(delta.currentResults.count, 1)
        XCTAssertEqual(delta.addedElements.count, 1)
        XCTAssertEqual(delta.removedElements.count, 1)
        XCTAssertEqual(delta.modifiedElements.count, 1)
        
        XCTAssertEqual(delta.previousResults[0].text, "Old Text")
        XCTAssertEqual(delta.currentResults[0].text, "New Text")
        XCTAssertEqual(delta.addedElements[0].text, "Added Text")
        XCTAssertEqual(delta.removedElements[0].text, "Removed Text")
        XCTAssertEqual(delta.modifiedElements[0].previous.text, "Old")
        XCTAssertEqual(delta.modifiedElements[0].current.text, "New")
    }
}

// MARK: - Mock Plugin for Testing

class MockPlugin: PluginProtocol {
    let identifier = "com.test.mock"
    let name = "Mock Plugin"
    let version = "1.0.0"
    let description = "A mock plugin for testing"
    let supportedApplications = ["com.test.app"]
    
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
}

class MockParsingPlugin: MockPlugin, ParsingPluginProtocol {
    func enhanceOCRResults(
        _ results: [OCRResult],
        context: ApplicationContext,
        frame: CGImage
    ) async throws -> [EnhancedOCRResult] {
        return results.map { result in
            EnhancedOCRResult(
                originalResult: result,
                semanticType: "mock_enhanced",
                structuredData: ["mock": true]
            )
        }
    }
    
    func extractStructuredData(
        from results: [OCRResult],
        context: ApplicationContext
    ) async throws -> [StructuredDataElement] {
        return results.map { result in
            StructuredDataElement(
                id: "mock_\(UUID().uuidString)",
                type: "mock_data",
                value: result.text,
                metadata: ["confidence": result.confidence]
            )
        }
    }
    
    func detectUIElements(
        in frame: CGImage,
        context: ApplicationContext
    ) async throws -> [UIElement] {
        return [
            UIElement(
                id: "mock_button",
                type: "button",
                boundingBox: CGRect(x: 0, y: 0, width: 100, height: 30),
                properties: ["mock": true]
            )
        ]
    }
}

class MockEventDetectionPlugin: MockPlugin, EventDetectionPluginProtocol {
    func detectEvents(
        from ocrDelta: OCRDelta,
        context: ApplicationContext
    ) async throws -> [DetectedEvent] {
        return ocrDelta.modifiedElements.map { (previous, current) in
            DetectedEvent(
                type: "mock_change",
                target: "mock_target",
                valueBefore: previous.text,
                valueAfter: current.text,
                confidence: 0.8
            )
        }
    }
    
    func classifyEvent(
        _ event: DetectedEvent,
        context: ApplicationContext
    ) async throws -> EventClassification {
        return EventClassification(
            category: "mock_category",
            importance: .medium,
            confidence: event.confidence
        )
    }
}