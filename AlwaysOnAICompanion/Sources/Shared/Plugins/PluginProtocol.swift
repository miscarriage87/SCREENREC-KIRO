import Foundation
import CoreGraphics

// MARK: - Core Plugin Protocol

/// Base protocol that all plugins must implement
public protocol PluginProtocol: AnyObject {
    /// Unique identifier for the plugin
    var identifier: String { get }
    
    /// Human-readable name of the plugin
    var name: String { get }
    
    /// Version of the plugin
    var version: String { get }
    
    /// Description of what the plugin does
    var description: String { get }
    
    /// Application bundle IDs this plugin supports
    var supportedApplications: [String] { get }
    
    /// Initialize the plugin with configuration
    func initialize(configuration: PluginConfiguration) throws
    
    /// Clean up resources when plugin is unloaded
    func cleanup()
    
    /// Check if this plugin can handle the given context
    func canHandle(context: ApplicationContext) -> Bool
}

// MARK: - Parsing Plugin Protocol

/// Protocol for plugins that enhance OCR and content parsing
public protocol ParsingPluginProtocol: PluginProtocol {
    /// Process OCR results and enhance them with app-specific knowledge
    func enhanceOCRResults(
        _ results: [OCRResult],
        context: ApplicationContext,
        frame: CGImage
    ) async throws -> [EnhancedOCRResult]
    
    /// Extract structured data from the application context
    func extractStructuredData(
        from results: [OCRResult],
        context: ApplicationContext
    ) async throws -> [StructuredDataElement]
    
    /// Detect UI elements specific to this application
    func detectUIElements(
        in frame: CGImage,
        context: ApplicationContext
    ) async throws -> [UIElement]
}

// MARK: - Event Detection Plugin Protocol

/// Protocol for plugins that enhance event detection
public protocol EventDetectionPluginProtocol: PluginProtocol {
    /// Detect application-specific events from OCR deltas
    func detectEvents(
        from ocrDelta: OCRDelta,
        context: ApplicationContext
    ) async throws -> [DetectedEvent]
    
    /// Classify events with application-specific knowledge
    func classifyEvent(
        _ event: DetectedEvent,
        context: ApplicationContext
    ) async throws -> EventClassification
}

// MARK: - Data Models

public struct PluginConfiguration {
    public let pluginDirectory: URL
    public let configurationData: [String: Any]
    public let sandboxEnabled: Bool
    public let maxMemoryUsage: Int64 // bytes
    public let maxExecutionTime: TimeInterval // seconds
    
    public init(
        pluginDirectory: URL,
        configurationData: [String: Any] = [:],
        sandboxEnabled: Bool = true,
        maxMemoryUsage: Int64 = 100 * 1024 * 1024, // 100MB
        maxExecutionTime: TimeInterval = 30.0
    ) {
        self.pluginDirectory = pluginDirectory
        self.configurationData = configurationData
        self.sandboxEnabled = sandboxEnabled
        self.maxMemoryUsage = maxMemoryUsage
        self.maxExecutionTime = maxExecutionTime
    }
}

public struct ApplicationContext {
    public let bundleID: String
    public let applicationName: String
    public let windowTitle: String
    public let processID: pid_t
    public let timestamp: Date
    public let metadata: [String: Any]
    
    public init(
        bundleID: String,
        applicationName: String,
        windowTitle: String,
        processID: pid_t,
        timestamp: Date = Date(),
        metadata: [String: Any] = [:]
    ) {
        self.bundleID = bundleID
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.processID = processID
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// OCRResult is defined in VisionOCRProcessor.swift - using that definition

public struct EnhancedOCRResult {
    public let originalResult: OCRResult
    public let semanticType: String // e.g., "field_label", "field_value", "button", "menu_item"
    public let structuredData: [String: Any]
    public let relationships: [String] // IDs of related elements
    
    public init(
        originalResult: OCRResult,
        semanticType: String,
        structuredData: [String: Any] = [:],
        relationships: [String] = []
    ) {
        self.originalResult = originalResult
        self.semanticType = semanticType
        self.structuredData = structuredData
        self.relationships = relationships
    }
}

public struct StructuredDataElement {
    public let id: String
    public let type: String
    public let value: Any
    public let metadata: [String: Any]
    public let boundingBox: CGRect?
    
    public init(
        id: String,
        type: String,
        value: Any,
        metadata: [String: Any] = [:],
        boundingBox: CGRect? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.metadata = metadata
        self.boundingBox = boundingBox
    }
}

public struct UIElement {
    public let id: String
    public let type: String // e.g., "button", "textfield", "dropdown", "tab"
    public let boundingBox: CGRect
    public let properties: [String: Any]
    public let isInteractive: Bool
    
    public init(
        id: String,
        type: String,
        boundingBox: CGRect,
        properties: [String: Any] = [:],
        isInteractive: Bool = true
    ) {
        self.id = id
        self.type = type
        self.boundingBox = boundingBox
        self.properties = properties
        self.isInteractive = isInteractive
    }
}

public struct OCRDelta {
    public let previousResults: [OCRResult]
    public let currentResults: [OCRResult]
    public let addedElements: [OCRResult]
    public let removedElements: [OCRResult]
    public let modifiedElements: [(previous: OCRResult, current: OCRResult)]
    
    public init(
        previousResults: [OCRResult],
        currentResults: [OCRResult],
        addedElements: [OCRResult],
        removedElements: [OCRResult],
        modifiedElements: [(previous: OCRResult, current: OCRResult)]
    ) {
        self.previousResults = previousResults
        self.currentResults = currentResults
        self.addedElements = addedElements
        self.removedElements = removedElements
        self.modifiedElements = modifiedElements
    }
}

public struct DetectedEvent {
    public let id: String
    public let type: String
    public let timestamp: Date
    public let target: String
    public let valueBefore: String?
    public let valueAfter: String?
    public let confidence: Float
    public let metadata: [String: Any]
    
    public init(
        id: String = UUID().uuidString,
        type: String,
        timestamp: Date = Date(),
        target: String,
        valueBefore: String? = nil,
        valueAfter: String? = nil,
        confidence: Float,
        metadata: [String: Any] = [:]
    ) {
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

public struct EventClassification {
    public let category: String
    public let subcategory: String?
    public let importance: EventImportance
    public let tags: [String]
    public let confidence: Float
    
    public init(
        category: String,
        subcategory: String? = nil,
        importance: EventImportance,
        tags: [String] = [],
        confidence: Float
    ) {
        self.category = category
        self.subcategory = subcategory
        self.importance = importance
        self.tags = tags
        self.confidence = confidence
    }
}

public enum EventImportance: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}