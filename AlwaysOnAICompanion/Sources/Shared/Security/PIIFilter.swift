import Foundation

/// Real-time PII filtering configuration
public struct PIIFilterConfig {
    public let enableRealTimeFiltering: Bool
    public let preventPIIStorage: Bool
    public let logFilteredContent: Bool
    public let allowedPIITypes: Set<PIIType>
    public let maskingConfig: PIIMaskingConfig
    public let detectionConfig: PIIDetectionConfig
    
    public init(
        enableRealTimeFiltering: Bool = true,
        preventPIIStorage: Bool = true,
        logFilteredContent: Bool = true,
        allowedPIITypes: Set<PIIType> = [],
        maskingConfig: PIIMaskingConfig = .default,
        detectionConfig: PIIDetectionConfig = .default
    ) {
        self.enableRealTimeFiltering = enableRealTimeFiltering
        self.preventPIIStorage = preventPIIStorage
        self.logFilteredContent = logFilteredContent
        self.allowedPIITypes = allowedPIITypes
        self.maskingConfig = maskingConfig
        self.detectionConfig = detectionConfig
    }
    
    public static let `default` = PIIFilterConfig()
}

/// Result of PII filtering operation
public struct PIIFilterResult {
    public let originalText: String
    public let filteredText: String
    public let containedPII: Bool
    public let detectedTypes: Set<PIIType>
    public let blockedTypes: Set<PIIType>
    public let maskingApplied: Bool
    public let shouldStore: Bool
    
    public init(
        originalText: String,
        filteredText: String,
        containedPII: Bool,
        detectedTypes: Set<PIIType>,
        blockedTypes: Set<PIIType>,
        maskingApplied: Bool,
        shouldStore: Bool
    ) {
        self.originalText = originalText
        self.filteredText = filteredText
        self.containedPII = containedPII
        self.detectedTypes = detectedTypes
        self.blockedTypes = blockedTypes
        self.maskingApplied = maskingApplied
        self.shouldStore = shouldStore
    }
}

/// Real-time PII filtering system for OCR processing pipeline
public class PIIFilter {
    private let config: PIIFilterConfig
    private let detector: PIIDetector
    private let masker: PIIMasker
    private let auditor: PrivacyAuditor
    
    public init(
        config: PIIFilterConfig = .default,
        auditor: PrivacyAuditor? = nil
    ) {
        self.config = config
        self.detector = PIIDetector(config: config.detectionConfig)
        self.masker = PIIMasker(config: config.maskingConfig, detector: detector)
        self.auditor = auditor ?? PrivacyAuditor()
    }
    
    /// Filter PII from OCR text before storage
    public func filterOCRText(_ text: String, source: String = "OCR") -> PIIFilterResult {
        guard config.enableRealTimeFiltering else {
            return PIIFilterResult(
                originalText: text,
                filteredText: text,
                containedPII: false,
                detectedTypes: [],
                blockedTypes: [],
                maskingApplied: false,
                shouldStore: true
            )
        }
        
        let detectedTypes = detector.getPIITypes(in: text)
        let containsPII = !detectedTypes.isEmpty
        
        if !containsPII {
            return PIIFilterResult(
                originalText: text,
                filteredText: text,
                containedPII: false,
                detectedTypes: [],
                blockedTypes: [],
                maskingApplied: false,
                shouldStore: true
            )
        }
        
        // Log PII detection
        auditor.logPIIDetection(piiTypes: detectedTypes, context: "OCR text filtering", source: source)
        
        // Determine blocked types (not in allowed list)
        let blockedTypes = detectedTypes.subtracting(config.allowedPIITypes)
        
        // Decide whether to store based on policy
        let shouldStore = config.preventPIIStorage ? blockedTypes.isEmpty : true
        
        // Apply masking if storing or if masking is enabled
        var filteredText = text
        var maskingApplied = false
        
        if shouldStore && !blockedTypes.isEmpty {
            let maskingResult = masker.maskPII(in: text)
            filteredText = maskingResult.maskedText
            maskingApplied = maskingResult.maskedCount > 0
            
            if maskingApplied {
                auditor.logPIIMasking(piiTypes: detectedTypes, maskingResult: maskingResult, source: source)
            }
        } else if !shouldStore {
            // If not storing, return empty or redacted text
            filteredText = "[CONTENT BLOCKED - CONTAINS PII]"
            maskingApplied = true
        }
        
        if config.logFilteredContent {
            logFilteringAction(
                originalText: text,
                filteredText: filteredText,
                detectedTypes: detectedTypes,
                blockedTypes: blockedTypes,
                shouldStore: shouldStore,
                source: source
            )
        }
        
        return PIIFilterResult(
            originalText: text,
            filteredText: filteredText,
            containedPII: containsPII,
            detectedTypes: detectedTypes,
            blockedTypes: blockedTypes,
            maskingApplied: maskingApplied,
            shouldStore: shouldStore
        )
    }
    
    /// Filter multiple OCR results in batch
    public func filterOCRResults(_ results: [OCRResult], source: String = "OCR") -> [PIIFilterResult] {
        return results.map { result in
            filterOCRText(result.text, source: source)
        }
    }
    
    /// Check if text should be blocked from storage
    public func shouldBlockStorage(for text: String) -> Bool {
        guard config.preventPIIStorage else { return false }
        
        let detectedTypes = detector.getPIITypes(in: text)
        let blockedTypes = detectedTypes.subtracting(config.allowedPIITypes)
        
        return !blockedTypes.isEmpty
    }
    
    /// Get PII summary for text without filtering
    public func analyzePII(in text: String) -> PIIAnalysis {
        let matches = detector.detectPII(in: text)
        let types = Set(matches.map { $0.type })
        let highConfidenceMatches = matches.filter { $0.confidence >= 0.8 }
        
        return PIIAnalysis(
            containsPII: !matches.isEmpty,
            detectedTypes: types,
            totalMatches: matches.count,
            highConfidenceMatches: highConfidenceMatches.count,
            averageConfidence: matches.isEmpty ? 0 : matches.map { $0.confidence }.reduce(0, +) / Float(matches.count),
            matches: matches
        )
    }
    
    /// Update filter configuration
    public func updateConfig(_ newConfig: PIIFilterConfig) {
        // In a real implementation, this would update the internal config
        // and log the configuration change
        auditor.logConfigChange(
            component: "PIIFilter",
            changes: [
                "enableRealTimeFiltering": String(newConfig.enableRealTimeFiltering),
                "preventPIIStorage": String(newConfig.preventPIIStorage),
                "allowedPIITypes": newConfig.allowedPIITypes.map { $0.rawValue }.joined(separator: ",")
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func logFilteringAction(
        originalText: String,
        filteredText: String,
        detectedTypes: Set<PIIType>,
        blockedTypes: Set<PIIType>,
        shouldStore: Bool,
        source: String
    ) {
        let context = shouldStore ? 
            "Text filtered and stored with masking" : 
            "Text blocked from storage due to PII"
        
        let severity: PrivacySeverity = blockedTypes.isEmpty ? .low : .medium
        
        let event = PrivacyAuditEvent(
            eventType: shouldStore ? .piiMasked : .piiDetected,
            piiTypes: detectedTypes,
            context: context,
            sourceComponent: source,
            severity: severity,
            metadata: [
                "original_length": String(originalText.count),
                "filtered_length": String(filteredText.count),
                "blocked_types": blockedTypes.map { $0.rawValue }.joined(separator: ","),
                "should_store": String(shouldStore)
            ]
        )
        
        auditor.logEvent(event)
    }
}

/// PII analysis result
public struct PIIAnalysis {
    public let containsPII: Bool
    public let detectedTypes: Set<PIIType>
    public let totalMatches: Int
    public let highConfidenceMatches: Int
    public let averageConfidence: Float
    public let matches: [PIIMatch]
    
    public init(
        containsPII: Bool,
        detectedTypes: Set<PIIType>,
        totalMatches: Int,
        highConfidenceMatches: Int,
        averageConfidence: Float,
        matches: [PIIMatch]
    ) {
        self.containsPII = containsPII
        self.detectedTypes = detectedTypes
        self.totalMatches = totalMatches
        self.highConfidenceMatches = highConfidenceMatches
        self.averageConfidence = averageConfidence
        self.matches = matches
    }
}

// OCRResult is defined in VisionOCRProcessor.swift