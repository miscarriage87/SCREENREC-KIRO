import Foundation
import Vision
import CoreImage
import CoreGraphics

/// Privacy-aware OCR processor that integrates PII filtering
public class PrivacyAwareOCRProcessor: OCRProcessor {
    
    private let baseProcessor: OCRProcessor
    private let piiFilter: PIIFilter
    private let auditor: PrivacyAuditor
    
    public var confidence: Float {
        return baseProcessor.confidence
    }
    
    public init(
        baseProcessor: OCRProcessor? = nil,
        piiFilter: PIIFilter? = nil,
        auditor: PrivacyAuditor? = nil
    ) {
        self.baseProcessor = baseProcessor ?? VisionOCRProcessor()
        self.auditor = auditor ?? PrivacyAuditor()
        self.piiFilter = piiFilter ?? PIIFilter(auditor: self.auditor)
    }
    
    /// Extract text with PII filtering applied
    public func extractText(from image: CGImage) async throws -> [OCRResult] {
        // First, perform standard OCR
        let rawResults = try await baseProcessor.extractText(from: image)
        
        // Apply PII filtering to each result
        var filteredResults: [OCRResult] = []
        
        for result in rawResults {
            let filterResult = piiFilter.filterOCRText(result.text, source: "VisionOCR")
            
            // Only include results that should be stored
            if filterResult.shouldStore {
                let filteredOCRResult = OCRResult(
                    text: filterResult.filteredText,
                    boundingBox: result.boundingBox,
                    confidence: result.confidence,
                    language: result.language
                )
                filteredResults.append(filteredOCRResult)
            } else {
                // Log that content was blocked
                auditor.logEvent(PrivacyAuditEvent(
                    eventType: .piiStored,
                    piiTypes: filterResult.detectedTypes,
                    context: "OCR content blocked from storage",
                    sourceComponent: "PrivacyAwareOCRProcessor",
                    severity: .medium,
                    metadata: [
                        "blocked_types": filterResult.blockedTypes.map { $0.rawValue }.joined(separator: ","),
                        "bounding_box": "\(result.boundingBox)"
                    ]
                ))
            }
        }
        
        return filteredResults
    }
    
    /// Preprocess image using base processor
    public func preprocessImage(_ image: CGImage) -> CGImage {
        return baseProcessor.preprocessImage(image)
    }
    
    /// Process batch with PII filtering
    public func processBatchWithPrivacy(_ images: [CGImage]) async throws -> [String: [OCRResult]] {
        var results: [String: [OCRResult]] = [:]
        
        await withTaskGroup(of: (String, [OCRResult]).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let imageId = "frame_\(index)"
                    do {
                        let ocrResults = try await self.extractText(from: image)
                        return (imageId, ocrResults)
                    } catch {
                        print("Privacy-aware OCR failed for image \(imageId): \(error)")
                        return (imageId, [])
                    }
                }
            }
            
            for await (imageId, ocrResults) in group {
                results[imageId] = ocrResults
            }
        }
        
        return results
    }
    
    /// Analyze PII in image without storing results
    public func analyzePIIInImage(_ image: CGImage) async throws -> PIIAnalysisReport {
        let rawResults = try await baseProcessor.extractText(from: image)
        
        var totalPIIInstances = 0
        var piiTypeFrequency: [PIIType: Int] = [:]
        var highRiskRegions: [CGRect] = []
        var analysisDetails: [PIIRegionAnalysis] = []
        
        for result in rawResults {
            let analysis = piiFilter.analyzePII(in: result.text)
            
            if analysis.containsPII {
                totalPIIInstances += analysis.totalMatches
                
                for piiType in analysis.detectedTypes {
                    piiTypeFrequency[piiType, default: 0] += 1
                }
                
                // Mark high-confidence PII regions as high risk
                if analysis.highConfidenceMatches > 0 {
                    highRiskRegions.append(result.boundingBox)
                }
                
                analysisDetails.append(PIIRegionAnalysis(
                    boundingBox: result.boundingBox,
                    text: result.text,
                    piiAnalysis: analysis
                ))
            }
        }
        
        return PIIAnalysisReport(
            totalTextRegions: rawResults.count,
            piiRegions: analysisDetails.count,
            totalPIIInstances: totalPIIInstances,
            piiTypeFrequency: piiTypeFrequency,
            highRiskRegions: highRiskRegions,
            regionDetails: analysisDetails,
            overallRiskLevel: calculateRiskLevel(piiTypeFrequency: piiTypeFrequency, highRiskRegions: highRiskRegions.count)
        )
    }
    
    /// Update PII filtering configuration
    public func updatePIIConfig(_ config: PIIFilterConfig) {
        piiFilter.updateConfig(config)
    }
    
    /// Get current PII filtering statistics
    public func getPIIStats(from startDate: Date, to endDate: Date) -> PrivacyAuditStats? {
        return auditor.getAuditStats(from: startDate, to: endDate)
    }
    
    // MARK: - Private Methods
    
    private func calculateRiskLevel(piiTypeFrequency: [PIIType: Int], highRiskRegions: Int) -> PIIRiskLevel {
        let criticalTypes: Set<PIIType> = [.ssn, .creditCard, .passport, .driversLicense]
        let highTypes: Set<PIIType> = [.email, .phone, .dateOfBirth]
        
        let hasCriticalPII = !Set(piiTypeFrequency.keys).isDisjoint(with: criticalTypes)
        let hasHighPII = !Set(piiTypeFrequency.keys).isDisjoint(with: highTypes)
        let totalPIITypes = piiTypeFrequency.count
        
        if hasCriticalPII || highRiskRegions > 3 {
            return .critical
        } else if hasHighPII || totalPIITypes > 2 {
            return .high
        } else if totalPIITypes > 0 {
            return .medium
        } else {
            return .low
        }
    }
}

/// PII analysis report for an image
public struct PIIAnalysisReport {
    public let totalTextRegions: Int
    public let piiRegions: Int
    public let totalPIIInstances: Int
    public let piiTypeFrequency: [PIIType: Int]
    public let highRiskRegions: [CGRect]
    public let regionDetails: [PIIRegionAnalysis]
    public let overallRiskLevel: PIIRiskLevel
    
    public init(
        totalTextRegions: Int,
        piiRegions: Int,
        totalPIIInstances: Int,
        piiTypeFrequency: [PIIType: Int],
        highRiskRegions: [CGRect],
        regionDetails: [PIIRegionAnalysis],
        overallRiskLevel: PIIRiskLevel
    ) {
        self.totalTextRegions = totalTextRegions
        self.piiRegions = piiRegions
        self.totalPIIInstances = totalPIIInstances
        self.piiTypeFrequency = piiTypeFrequency
        self.highRiskRegions = highRiskRegions
        self.regionDetails = regionDetails
        self.overallRiskLevel = overallRiskLevel
    }
}

/// PII analysis for a specific region
public struct PIIRegionAnalysis {
    public let boundingBox: CGRect
    public let text: String
    public let piiAnalysis: PIIAnalysis
    
    public init(boundingBox: CGRect, text: String, piiAnalysis: PIIAnalysis) {
        self.boundingBox = boundingBox
        self.text = text
        self.piiAnalysis = piiAnalysis
    }
}

/// Risk level assessment for PII content
public enum PIIRiskLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var description: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        case .critical: return "Critical Risk"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}