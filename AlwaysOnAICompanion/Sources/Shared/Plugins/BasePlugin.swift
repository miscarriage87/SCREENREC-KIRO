import Foundation
import CoreGraphics

/// Base implementation for all plugins with common functionality
open class BasePlugin: PluginProtocol {
    
    public let identifier: String
    public let name: String
    public let version: String
    public let description: String
    public let supportedApplications: [String]
    
    internal var configuration: PluginConfiguration?
    internal var isInitialized = false
    
    public init(
        identifier: String,
        name: String,
        version: String,
        description: String,
        supportedApplications: [String]
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.supportedApplications = supportedApplications
    }
    
    // MARK: - PluginProtocol Implementation
    
    public func initialize(configuration: PluginConfiguration) throws {
        self.configuration = configuration
        try performInitialization()
        isInitialized = true
        Logger.shared.info("Plugin \(identifier) initialized successfully")
    }
    
    public func cleanup() {
        performCleanup()
        isInitialized = false
        Logger.shared.info("Plugin \(identifier) cleaned up")
    }
    
    public func canHandle(context: ApplicationContext) -> Bool {
        guard isInitialized else { return false }
        
        // Check if bundle ID is in supported applications
        if supportedApplications.contains(context.bundleID) {
            return true
        }
        
        // Check for wildcard patterns
        for supportedApp in supportedApplications {
            if supportedApp.hasSuffix("*") {
                let prefix = String(supportedApp.dropLast())
                if context.bundleID.hasPrefix(prefix) {
                    return true
                }
            }
        }
        
        return canHandleCustom(context: context)
    }
    
    // MARK: - Subclass Override Points
    
    /// Override to perform plugin-specific initialization
    open func performInitialization() throws {
        // Default implementation does nothing
    }
    
    /// Override to perform plugin-specific cleanup
    open func performCleanup() {
        // Default implementation does nothing
    }
    
    /// Override to provide custom context handling logic
    open func canHandleCustom(context: ApplicationContext) -> Bool {
        return false
    }
    
    // MARK: - Utility Methods
    
    /// Check if text matches common UI patterns
    internal func isUILabel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix(":") || 
               trimmed.count < 50 && !trimmed.contains("\n")
    }
    
    /// Check if text appears to be a field value
    internal func isFieldValue(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && 
               !trimmed.hasSuffix(":") &&
               trimmed.count > 0
    }
    
    /// Extract field pairs from OCR results
    internal func extractFieldPairs(from results: [OCRResult]) -> [(label: OCRResult, value: OCRResult?)] {
        var pairs: [(label: OCRResult, value: OCRResult?)] = []
        
        for (index, result) in results.enumerated() {
            if isUILabel(result.text) {
                // Look for a value to the right or below
                let potentialValue = findNearestValue(to: result, in: results, startingFrom: index + 1)
                pairs.append((label: result, value: potentialValue))
            }
        }
        
        return pairs
    }
    
    /// Find the nearest value OCR result to a label
    private func findNearestValue(to label: OCRResult, in results: [OCRResult], startingFrom index: Int) -> OCRResult? {
        let labelCenter = CGPoint(
            x: label.boundingBox.midX,
            y: label.boundingBox.midY
        )
        
        var nearestValue: OCRResult?
        var nearestDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        for i in index..<results.count {
            let candidate = results[i]
            
            // Skip if this looks like another label
            if isUILabel(candidate.text) {
                continue
            }
            
            let candidateCenter = CGPoint(
                x: candidate.boundingBox.midX,
                y: candidate.boundingBox.midY
            )
            
            // Calculate distance
            let distance = sqrt(
                pow(candidateCenter.x - labelCenter.x, 2) +
                pow(candidateCenter.y - labelCenter.y, 2)
            )
            
            // Prefer values to the right or below
            let isToRight = candidateCenter.x > labelCenter.x
            let isBelow = candidateCenter.y > labelCenter.y
            
            if (isToRight || isBelow) && distance < nearestDistance {
                nearestDistance = distance
                nearestValue = candidate
            }
        }
        
        return nearestValue
    }
    
    /// Create a structured data element from a field pair
    internal func createStructuredElement(
        from pair: (label: OCRResult, value: OCRResult?),
        type: String = "field"
    ) -> StructuredDataElement? {
        guard let value = pair.value else { return nil }
        
        let id = "\(identifier)_\(UUID().uuidString)"
        let labelText = pair.label.text.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n"))
        
        return StructuredDataElement(
            id: id,
            type: type,
            value: value.text,
            metadata: [
                "label": labelText,
                "confidence": min(pair.label.confidence, value.confidence),
                "label_bounds": NSValue(rect: pair.label.boundingBox),
                "value_bounds": NSValue(rect: value.boundingBox)
            ],
            boundingBox: pair.label.boundingBox.union(value.boundingBox)
        )
    }
    
    /// Detect common button patterns
    internal func detectButtons(in results: [OCRResult]) -> [UIElement] {
        let buttonKeywords = ["OK", "Cancel", "Submit", "Save", "Delete", "Edit", "Add", "Remove", "Next", "Previous", "Continue", "Finish"]
        
        return results.compactMap { result in
            let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if buttonKeywords.contains(text) || 
               (text.count <= 20 && !text.contains(" ") && text.uppercased() == text) {
                return UIElement(
                    id: "\(identifier)_button_\(UUID().uuidString)",
                    type: "button",
                    boundingBox: result.boundingBox,
                    properties: [
                        "text": text,
                        "confidence": result.confidence
                    ],
                    isInteractive: true
                )
            }
            
            return nil
        }
    }
    
    /// Create enhanced OCR result with semantic information
    internal func createEnhancedResult(
        from original: OCRResult,
        semanticType: String,
        structuredData: [String: Any] = [:],
        relationships: [String] = []
    ) -> EnhancedOCRResult {
        return EnhancedOCRResult(
            originalResult: original,
            semanticType: semanticType,
            structuredData: structuredData,
            relationships: relationships
        )
    }
}

/// Base class for parsing plugins with common parsing functionality
open class BaseParsingPlugin: BasePlugin, ParsingPluginProtocol {
    
    // MARK: - ParsingPluginProtocol Implementation
    
    open func enhanceOCRResults(
        _ results: [OCRResult],
        context: ApplicationContext,
        frame: CGImage
    ) async throws -> [EnhancedOCRResult] {
        var enhancedResults: [EnhancedOCRResult] = []
        
        // Extract field pairs and enhance them
        let fieldPairs = extractFieldPairs(from: results)
        for pair in fieldPairs {
            if let value = pair.value {
                let labelEnhanced = createEnhancedResult(
                    from: pair.label,
                    semanticType: "field_label",
                    structuredData: ["paired_with": value.text]
                )
                
                let valueEnhanced = createEnhancedResult(
                    from: value,
                    semanticType: "field_value",
                    structuredData: ["label": pair.label.text]
                )
                
                enhancedResults.append(labelEnhanced)
                enhancedResults.append(valueEnhanced)
            }
        }
        
        // Detect buttons and enhance them
        let buttons = detectButtons(in: results)
        for button in buttons {
            if let buttonResult = results.first(where: { $0.boundingBox.intersects(button.boundingBox) }) {
                let enhanced = createEnhancedResult(
                    from: buttonResult,
                    semanticType: "button",
                    structuredData: button.properties
                )
                enhancedResults.append(enhanced)
            }
        }
        
        return enhancedResults
    }
    
    open func extractStructuredData(
        from results: [OCRResult],
        context: ApplicationContext
    ) async throws -> [StructuredDataElement] {
        let fieldPairs = extractFieldPairs(from: results)
        return fieldPairs.compactMap { createStructuredElement(from: $0) }
    }
    
    open func detectUIElements(
        in frame: CGImage,
        context: ApplicationContext
    ) async throws -> [UIElement] {
        // This would typically involve image processing to detect UI elements
        // For now, we'll return an empty array as this requires more complex implementation
        return []
    }
}

/// Base class for event detection plugins
open class BaseEventDetectionPlugin: BasePlugin, EventDetectionPluginProtocol {
    
    // MARK: - EventDetectionPluginProtocol Implementation
    
    open func detectEvents(
        from ocrDelta: OCRDelta,
        context: ApplicationContext
    ) async throws -> [DetectedEvent] {
        var events: [DetectedEvent] = []
        
        // Detect field value changes
        for (previous, current) in ocrDelta.modifiedElements {
            if isFieldValue(previous.text) && isFieldValue(current.text) {
                let event = DetectedEvent(
                    type: "field_change",
                    target: "field_\(previous.boundingBox.origin.x)_\(previous.boundingBox.origin.y)",
                    valueBefore: previous.text,
                    valueAfter: current.text,
                    confidence: min(previous.confidence, current.confidence),
                    metadata: [
                        "bounds": NSValue(rect: current.boundingBox),
                        "app": context.bundleID
                    ]
                )
                events.append(event)
            }
        }
        
        // Detect new content
        for added in ocrDelta.addedElements {
            if isFieldValue(added.text) {
                let event = DetectedEvent(
                    type: "content_added",
                    target: "field_\(added.boundingBox.origin.x)_\(added.boundingBox.origin.y)",
                    valueAfter: added.text,
                    confidence: added.confidence,
                    metadata: [
                        "bounds": NSValue(rect: added.boundingBox),
                        "app": context.bundleID
                    ]
                )
                events.append(event)
            }
        }
        
        return events
    }
    
    open func classifyEvent(
        _ event: DetectedEvent,
        context: ApplicationContext
    ) async throws -> EventClassification {
        let category = classifyEventCategory(event, context: context)
        let importance = determineEventImportance(event, context: context)
        
        return EventClassification(
            category: category,
            subcategory: nil,
            importance: importance,
            tags: generateEventTags(event, context: context),
            confidence: event.confidence
        )
    }
    
    // MARK: - Classification Helpers
    
    internal func classifyEventCategory(_ event: DetectedEvent, context: ApplicationContext) -> String {
        switch event.type {
        case "field_change":
            return "data_modification"
        case "content_added":
            return "data_creation"
        case "content_removed":
            return "data_deletion"
        default:
            return "interaction"
        }
    }
    
    internal func determineEventImportance(_ event: DetectedEvent, context: ApplicationContext) -> EventImportance {
        // Default importance based on event type
        switch event.type {
        case "field_change":
            return .medium
        case "content_added", "content_removed":
            return .low
        default:
            return .low
        }
    }
    
    internal func generateEventTags(_ event: DetectedEvent, context: ApplicationContext) -> [String] {
        var tags: [String] = []
        
        tags.append(context.bundleID)
        tags.append(event.type)
        
        if let windowTitle = context.metadata["windowTitle"] as? String, !windowTitle.isEmpty {
            tags.append("window:\(windowTitle)")
        }
        
        return tags
    }
}