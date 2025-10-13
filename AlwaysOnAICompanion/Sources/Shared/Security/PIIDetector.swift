import Foundation
import RegexBuilder

/// Types of personally identifiable information that can be detected
public enum PIIType: String, CaseIterable {
    case email = "email"
    case phone = "phone"
    case ssn = "ssn"
    case creditCard = "credit_card"
    case ipAddress = "ip_address"
    case macAddress = "mac_address"
    case url = "url"
    case name = "name"
    case address = "address"
    case dateOfBirth = "date_of_birth"
    case passport = "passport"
    case driversLicense = "drivers_license"
    
    var description: String {
        switch self {
        case .email: return "Email Address"
        case .phone: return "Phone Number"
        case .ssn: return "Social Security Number"
        case .creditCard: return "Credit Card Number"
        case .ipAddress: return "IP Address"
        case .macAddress: return "MAC Address"
        case .url: return "URL"
        case .name: return "Personal Name"
        case .address: return "Physical Address"
        case .dateOfBirth: return "Date of Birth"
        case .passport: return "Passport Number"
        case .driversLicense: return "Driver's License"
        }
    }
}

/// Detected PII instance with location and confidence
public struct PIIMatch {
    public let type: PIIType
    public let text: String
    public let range: NSRange
    public let confidence: Float
    public let context: String
    
    public init(type: PIIType, text: String, range: NSRange, confidence: Float, context: String) {
        self.type = type
        self.text = text
        self.range = range
        self.confidence = confidence
        self.context = context
    }
}

/// Configuration for PII detection sensitivity and patterns
public struct PIIDetectionConfig {
    public let enabledTypes: Set<PIIType>
    public let minimumConfidence: Float
    public let contextWindow: Int
    public let customPatterns: [PIIType: String]
    
    public init(
        enabledTypes: Set<PIIType> = Set(PIIType.allCases),
        minimumConfidence: Float = 0.7,
        contextWindow: Int = 20,
        customPatterns: [PIIType: String] = [:]
    ) {
        self.enabledTypes = enabledTypes
        self.minimumConfidence = minimumConfidence
        self.contextWindow = contextWindow
        self.customPatterns = customPatterns
    }
    
    public static let `default` = PIIDetectionConfig()
}

/// Core PII detection engine using regex patterns and heuristics
public class PIIDetector {
    private let config: PIIDetectionConfig
    private let patterns: [PIIType: NSRegularExpression]
    
    public init(config: PIIDetectionConfig = .default) {
        self.config = config
        self.patterns = Self.buildPatterns(config: config)
    }
    
    /// Detect all PII instances in the given text
    public func detectPII(in text: String) -> [PIIMatch] {
        var matches: [PIIMatch] = []
        
        for type in config.enabledTypes {
            guard let pattern = patterns[type] else { continue }
            
            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            
            pattern.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match = match else { return }
                
                let matchedText = nsText.substring(with: match.range)
                let confidence = calculateConfidence(for: type, text: matchedText, fullText: text)
                
                if confidence >= config.minimumConfidence {
                    let context = extractContext(from: text, range: match.range, window: config.contextWindow)
                    
                    matches.append(PIIMatch(
                        type: type,
                        text: matchedText,
                        range: match.range,
                        confidence: confidence,
                        context: context
                    ))
                }
            }
        }
        
        return matches.sorted { $0.range.location < $1.range.location }
    }
    
    /// Check if text contains any PII above confidence threshold
    public func containsPII(_ text: String) -> Bool {
        return !detectPII(in: text).isEmpty
    }
    
    /// Get PII types detected in text
    public func getPIITypes(in text: String) -> Set<PIIType> {
        return Set(detectPII(in: text).map { $0.type })
    }
    
    // MARK: - Private Methods
    
    private static func buildPatterns(config: PIIDetectionConfig) -> [PIIType: NSRegularExpression] {
        var patterns: [PIIType: NSRegularExpression] = [:]
        
        let defaultPatterns: [PIIType: String] = [
            .email: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#,
            .phone: #"\b(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})\b"#,
            .ssn: #"\b(?!000|666|9\d{2})\d{3}[-\s]?(?!00)\d{2}[-\s]?(?!0000)\d{4}\b"#,
            .creditCard: #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3[0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"#,
            .ipAddress: #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#,
            .macAddress: #"\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b"#,
            .url: #"\bhttps?://(?:[-\w.])+(?:[:\d]+)?(?:/(?:[\w/_.])*(?:\?(?:[\w&=%.])*)?(?:#(?:[\w.])*)?)?/?"#,
            .dateOfBirth: #"\b(?:0[1-9]|1[0-2])[-/](?:0[1-9]|[12][0-9]|3[01])[-/](?:19|20)\d{2}\b"#,
            .passport: #"\b[A-Z]{1,2}[0-9]{6,9}\b"#,
            .driversLicense: #"\b[A-Z]{1,2}[0-9]{6,8}\b"#
        ]
        
        for type in config.enabledTypes {
            let patternString = config.customPatterns[type] ?? defaultPatterns[type] ?? ""
            
            do {
                let regex = try NSRegularExpression(pattern: patternString, options: [.caseInsensitive])
                patterns[type] = regex
            } catch {
                print("Failed to compile regex for \(type): \(error)")
            }
        }
        
        return patterns
    }
    
    private func calculateConfidence(for type: PIIType, text: String, fullText: String) -> Float {
        var confidence: Float = 0.5
        
        switch type {
        case .email:
            confidence = validateEmail(text) ? 0.9 : 0.3
        case .phone:
            confidence = validatePhone(text) ? 0.8 : 0.4
        case .ssn:
            confidence = validateSSN(text) ? 0.95 : 0.2
        case .creditCard:
            confidence = validateCreditCard(text) ? 0.9 : 0.3
        case .ipAddress:
            confidence = validateIPAddress(text) ? 0.85 : 0.4
        case .url:
            confidence = text.contains("://") ? 0.9 : 0.6
        default:
            confidence = 0.7
        }
        
        // Adjust confidence based on context
        if hasPrivacyContext(fullText) {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    private func validateEmail(_ text: String) -> Bool {
        return text.contains("@") && text.contains(".") && !text.contains(" ")
    }
    
    private func validatePhone(_ text: String) -> Bool {
        let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits.count >= 10 && digits.count <= 15
    }
    
    private func validateSSN(_ text: String) -> Bool {
        let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits.count == 9 && digits != "000000000"
    }
    
    private func validateCreditCard(_ text: String) -> Bool {
        let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits.count >= 13 && digits.count <= 19 && luhnCheck(digits)
    }
    
    private func validateIPAddress(_ text: String) -> Bool {
        let components = text.split(separator: ".")
        return components.count == 4 && components.allSatisfy { 
            guard let num = Int($0) else { return false }
            return num >= 0 && num <= 255
        }
    }
    
    private func luhnCheck(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        var sum = 0
        var isEven = false
        
        for digit in digits.reversed() {
            var value = digit
            if isEven {
                value *= 2
                if value > 9 {
                    value = value % 10 + value / 10
                }
            }
            sum += value
            isEven.toggle()
        }
        
        return sum % 10 == 0
    }
    
    private func hasPrivacyContext(_ text: String) -> Bool {
        let privacyKeywords = ["personal", "private", "confidential", "sensitive", "ssn", "social security"]
        let lowercaseText = text.lowercased()
        return privacyKeywords.contains { lowercaseText.contains($0) }
    }
    
    private func extractContext(from text: String, range: NSRange, window: Int) -> String {
        let nsText = text as NSString
        let start = max(0, range.location - window)
        let end = min(nsText.length, range.location + range.length + window)
        let contextRange = NSRange(location: start, length: end - start)
        return nsText.substring(with: contextRange)
    }
}