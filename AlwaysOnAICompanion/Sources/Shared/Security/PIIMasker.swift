import Foundation

/// Masking strategies for different types of PII
public enum MaskingStrategy {
    case redact           // Replace with [REDACTED]
    case asterisk         // Replace with asterisks (****)
    case partial          // Show first/last characters with middle masked
    case hash             // Replace with consistent hash
    case placeholder      // Replace with type-specific placeholder
    case remove           // Remove entirely from text
    
    var description: String {
        switch self {
        case .redact: return "Redact with [REDACTED]"
        case .asterisk: return "Replace with asterisks"
        case .partial: return "Partial masking"
        case .hash: return "Hash replacement"
        case .placeholder: return "Type-specific placeholder"
        case .remove: return "Complete removal"
        }
    }
}

/// Configuration for PII masking behavior
public struct PIIMaskingConfig {
    public let strategies: [PIIType: MaskingStrategy]
    public let preserveLength: Bool
    public let hashSalt: String
    public let partialMaskingRatio: Float
    
    public init(
        strategies: [PIIType: MaskingStrategy] = Self.defaultStrategies,
        preserveLength: Bool = true,
        hashSalt: String = "default_salt",
        partialMaskingRatio: Float = 0.6
    ) {
        self.strategies = strategies
        self.preserveLength = preserveLength
        self.hashSalt = hashSalt
        self.partialMaskingRatio = partialMaskingRatio
    }
    
    public static let defaultStrategies: [PIIType: MaskingStrategy] = [
        .email: .partial,
        .phone: .partial,
        .ssn: .redact,
        .creditCard: .partial,
        .ipAddress: .asterisk,
        .macAddress: .asterisk,
        .url: .placeholder,
        .name: .hash,
        .address: .redact,
        .dateOfBirth: .redact,
        .passport: .redact,
        .driversLicense: .redact
    ]
    
    public static let `default` = PIIMaskingConfig()
}

/// Result of PII masking operation
public struct MaskingResult {
    public let maskedText: String
    public let maskedCount: Int
    public let maskingMap: [PIIType: Int]
    public let preservedRanges: [NSRange]
    
    public init(maskedText: String, maskedCount: Int, maskingMap: [PIIType: Int], preservedRanges: [NSRange]) {
        self.maskedText = maskedText
        self.maskedCount = maskedCount
        self.maskingMap = maskingMap
        self.preservedRanges = preservedRanges
    }
}

/// PII masking engine that applies configurable masking strategies
public class PIIMasker {
    private let config: PIIMaskingConfig
    private let detector: PIIDetector
    
    public init(config: PIIMaskingConfig = .default, detector: PIIDetector? = nil) {
        self.config = config
        self.detector = detector ?? PIIDetector()
    }
    
    /// Mask all detected PII in the given text
    public func maskPII(in text: String) -> MaskingResult {
        let matches = detector.detectPII(in: text)
        
        if matches.isEmpty {
            return MaskingResult(
                maskedText: text,
                maskedCount: 0,
                maskingMap: [:],
                preservedRanges: []
            )
        }
        
        return applyMasking(to: text, matches: matches)
    }
    
    /// Check if text needs masking (contains PII)
    public func needsMasking(_ text: String) -> Bool {
        return detector.containsPII(text)
    }
    
    /// Get masking preview without applying changes
    public func previewMasking(for text: String) -> [(PIIMatch, String)] {
        let matches = detector.detectPII(in: text)
        return matches.map { match in
            let strategy = config.strategies[match.type] ?? .redact
            let masked = maskText(match.text, strategy: strategy, type: match.type)
            return (match, masked)
        }
    }
    
    // MARK: - Private Methods
    
    private func applyMasking(to text: String, matches: [PIIMatch]) -> MaskingResult {
        var maskedText = text
        var maskingMap: [PIIType: Int] = [:]
        var preservedRanges: [NSRange] = []
        var offset = 0
        
        // Sort matches by location to handle offset correctly
        let sortedMatches = matches.sorted { $0.range.location < $1.range.location }
        
        for match in sortedMatches {
            let strategy = config.strategies[match.type] ?? .redact
            let maskedValue = maskText(match.text, strategy: strategy, type: match.type)
            
            // Calculate adjusted range accounting for previous replacements
            let adjustedRange = NSRange(
                location: match.range.location + offset,
                length: match.range.length
            )
            
            // Replace the text
            let nsText = maskedText as NSString
            maskedText = nsText.replacingCharacters(in: adjustedRange, with: maskedValue)
            
            // Update offset for next replacement
            offset += maskedValue.count - match.range.length
            
            // Update masking statistics
            maskingMap[match.type, default: 0] += 1
            
            // Track preserved ranges if applicable
            if strategy == .partial {
                let newRange = NSRange(location: adjustedRange.location, length: maskedValue.count)
                preservedRanges.append(newRange)
            }
        }
        
        return MaskingResult(
            maskedText: maskedText,
            maskedCount: sortedMatches.count,
            maskingMap: maskingMap,
            preservedRanges: preservedRanges
        )
    }
    
    private func maskText(_ text: String, strategy: MaskingStrategy, type: PIIType) -> String {
        switch strategy {
        case .redact:
            return "[REDACTED]"
            
        case .asterisk:
            return config.preserveLength ? String(repeating: "*", count: text.count) : "****"
            
        case .partial:
            return applyPartialMasking(to: text, type: type)
            
        case .hash:
            return generateHash(for: text, type: type)
            
        case .placeholder:
            return getPlaceholder(for: type)
            
        case .remove:
            return ""
        }
    }
    
    private func applyPartialMasking(to text: String, type: PIIType) -> String {
        let length = text.count
        
        switch type {
        case .email:
            return maskEmail(text)
        case .phone:
            return maskPhone(text)
        case .creditCard:
            return maskCreditCard(text)
        case .ssn:
            return "***-**-****"
        default:
            let visibleCount = max(1, Int(Float(length) * (1.0 - config.partialMaskingRatio)))
            let maskCount = length - visibleCount
            let prefix = String(text.prefix(visibleCount / 2))
            let suffix = String(text.suffix(visibleCount - visibleCount / 2))
            let mask = String(repeating: "*", count: maskCount)
            return prefix + mask + suffix
        }
    }
    
    private func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return "***@***.***" }
        
        let username = String(email[..<atIndex])
        let domain = String(email[email.index(after: atIndex)...])
        
        let maskedUsername = username.count > 2 ? 
            String(username.prefix(1)) + String(repeating: "*", count: username.count - 2) + String(username.suffix(1)) :
            String(repeating: "*", count: username.count)
        
        let maskedDomain = domain.contains(".") ?
            String(domain.prefix(1)) + "***." + String(domain.split(separator: ".").last ?? "***") :
            "***"
        
        return maskedUsername + "@" + maskedDomain
    }
    
    private func maskPhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        if digits.count >= 10 {
            let lastFour = String(digits.suffix(4))
            let masked = String(repeating: "*", count: digits.count - 4)
            return masked + lastFour
        }
        return String(repeating: "*", count: phone.count)
    }
    
    private func maskCreditCard(_ card: String) -> String {
        let digits = card.filter { $0.isNumber }
        if digits.count >= 13 {
            let lastFour = String(digits.suffix(4))
            let masked = String(repeating: "*", count: digits.count - 4)
            return masked + lastFour
        }
        return String(repeating: "*", count: card.count)
    }
    
    private func generateHash(for text: String, type: PIIType) -> String {
        let saltedText = text + config.hashSalt + type.rawValue
        let hash = saltedText.data(using: .utf8)?.base64EncodedString() ?? "HASH"
        let shortHash = String(hash.prefix(8))
        return "[HASH:\(shortHash)]"
    }
    
    private func getPlaceholder(for type: PIIType) -> String {
        switch type {
        case .email: return "[EMAIL]"
        case .phone: return "[PHONE]"
        case .ssn: return "[SSN]"
        case .creditCard: return "[CREDIT_CARD]"
        case .ipAddress: return "[IP_ADDRESS]"
        case .macAddress: return "[MAC_ADDRESS]"
        case .url: return "[URL]"
        case .name: return "[NAME]"
        case .address: return "[ADDRESS]"
        case .dateOfBirth: return "[DOB]"
        case .passport: return "[PASSPORT]"
        case .driversLicense: return "[LICENSE]"
        }
    }
}