import Foundation

/// Demo showcasing PII masking and privacy controls functionality
public class PIIMaskingDemo {
    
    private let detector: PIIDetector
    private let masker: PIIMasker
    private let filter: PIIFilter
    private let auditor: PrivacyAuditor
    
    public init() {
        self.auditor = PrivacyAuditor()
        self.detector = PIIDetector()
        self.masker = PIIMasker()
        self.filter = PIIFilter(auditor: auditor)
    }
    
    /// Run comprehensive PII masking demonstration
    public func runDemo() {
        print("=== PII Masking and Privacy Controls Demo ===\n")
        
        demonstratePIIDetection()
        demonstrateMaskingStrategies()
        demonstrateRealTimeFiltering()
        demonstratePrivacyAudit()
        demonstrateConfigurableSettings()
        demonstrateRealWorldScenarios()
        
        print("\n=== Demo Complete ===")
    }
    
    // MARK: - PII Detection Demo
    
    private func demonstratePIIDetection() {
        print("1. PII Detection Capabilities")
        print("=" * 40)
        
        let testDocuments = [
            """
            EMPLOYEE INFORMATION FORM
            
            Full Name: John Smith
            Email: john.smith@company.com
            Phone: (555) 123-4567
            SSN: 123-45-6789
            Date of Birth: 05/15/1985
            
            Emergency Contact:
            Name: Jane Smith
            Phone: (555) 987-6543
            Email: jane.smith@email.com
            """,
            
            """
            PAYMENT INFORMATION
            
            Credit Card: 4111 1111 1111 1111
            Expiry: 12/25
            CVV: 123
            Billing Address: 123 Main St, Anytown, ST 12345
            """,
            
            """
            SYSTEM CONFIGURATION
            
            Server IP: 192.168.1.100
            MAC Address: 00:1B:44:11:3A:B7
            Database URL: https://db.company.com:5432/prod
            API Key: sk-1234567890abcdef
            """
        ]
        
        for (index, document) in testDocuments.enumerated() {
            print("\nDocument \(index + 1):")
            print("-" * 20)
            
            let matches = detector.detectPII(in: document)
            
            if matches.isEmpty {
                print("✅ No PII detected")
            } else {
                print("⚠️  PII detected:")
                for match in matches {
                    print("  • \(match.type.description): '\(match.text)' (confidence: \(String(format: "%.2f", match.confidence)))")
                }
            }
        }
        
        print("\n")
    }
    
    // MARK: - Masking Strategies Demo
    
    private func demonstrateMaskingStrategies() {
        print("2. Masking Strategies")
        print("=" * 40)
        
        let testText = "Contact: john.doe@company.com, Phone: (555) 123-4567, SSN: 123-45-6789"
        
        let strategies: [PIIType: MaskingStrategy] = [
            .email: .partial,
            .phone: .asterisk,
            .ssn: .redact
        ]
        
        print("Original text:")
        print("  \(testText)")
        print()
        
        for (piiType, strategy) in strategies {
            let config = PIIMaskingConfig(strategies: [piiType: strategy])
            let customMasker = PIIMasker(config: config, detector: detector)
            let result = customMasker.maskPII(in: testText)
            
            print("\(piiType.description) with \(strategy.description):")
            print("  \(result.maskedText)")
        }
        
        // Demonstrate all strategies at once
        let comprehensiveConfig = PIIMaskingConfig(strategies: strategies)
        let comprehensiveMasker = PIIMasker(config: comprehensiveConfig, detector: detector)
        let finalResult = comprehensiveMasker.maskPII(in: testText)
        
        print("\nAll strategies applied:")
        print("  \(finalResult.maskedText)")
        print("  Masked \(finalResult.maskedCount) PII instances")
        print()
    }
    
    // MARK: - Real-Time Filtering Demo
    
    private func demonstrateRealTimeFiltering() {
        print("3. Real-Time PII Filtering")
        print("=" * 40)
        
        let ocrResults = [
            "Welcome to our application",
            "Please enter your email: john@company.com",
            "Your SSN: 123-45-6789 has been verified",
            "Server error at IP: 192.168.1.1",
            "Thank you for your submission"
        ]
        
        print("Simulating OCR text processing with PII filtering:\n")
        
        for (index, text) in ocrResults.enumerated() {
            print("OCR Result \(index + 1): \(text)")
            
            let filterResult = filter.filterOCRText(text, source: "DemoOCR")
            
            if filterResult.containedPII {
                print("  ⚠️  PII detected: \(filterResult.detectedTypes.map { $0.description }.joined(separator: ", "))")
                print("  🔒 Filtered text: \(filterResult.filteredText)")
                print("  📊 Should store: \(filterResult.shouldStore ? "Yes" : "No")")
            } else {
                print("  ✅ Clean text - no filtering needed")
            }
            print()
        }
    }
    
    // MARK: - Privacy Audit Demo
    
    private func demonstratePrivacyAudit() {
        print("4. Privacy Audit System")
        print("=" * 40)
        
        // Simulate some PII processing events
        auditor.logPIIDetection(piiTypes: [.email, .phone], context: "Form processing", source: "DemoOCR")
        auditor.logPIIMasking(
            piiTypes: [.ssn],
            maskingResult: MaskingResult(maskedText: "SSN: [REDACTED]", maskedCount: 1, maskingMap: [.ssn: 1], preservedRanges: []),
            source: "DemoMasker"
        )
        auditor.logConfigChange(component: "PIIFilter", changes: ["enableRealTimeFiltering": "true"])
        
        // Generate audit report
        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()
        
        let report = auditor.generateAuditReport(from: startDate, to: endDate)
        print("Privacy Audit Report:")
        print(report)
        print()
    }
    
    // MARK: - Configurable Settings Demo
    
    private func demonstrateConfigurableSettings() {
        print("5. Configurable Privacy Settings")
        print("=" * 40)
        
        let testText = "Email: user@domain.com, Phone: 555-1234, SSN: 123-45-6789"
        
        // Scenario 1: Strict privacy (block all PII)
        print("Scenario 1: Strict Privacy (No PII allowed)")
        let strictConfig = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: []
        )
        let strictFilter = PIIFilter(config: strictConfig, auditor: auditor)
        let strictResult = strictFilter.filterOCRText(testText)
        print("  Result: \(strictResult.filteredText)")
        print("  Should store: \(strictResult.shouldStore)")
        print()
        
        // Scenario 2: Moderate privacy (allow email only)
        print("Scenario 2: Moderate Privacy (Email allowed)")
        let moderateConfig = PIIFilterConfig(
            preventPIIStorage: true,
            allowedPIITypes: [.email]
        )
        let moderateFilter = PIIFilter(config: moderateConfig, auditor: auditor)
        let moderateResult = moderateFilter.filterOCRText(testText)
        print("  Result: \(moderateResult.filteredText)")
        print("  Should store: \(moderateResult.shouldStore)")
        print()
        
        // Scenario 3: Permissive (mask but store all)
        print("Scenario 3: Permissive (Mask but store all)")
        let permissiveConfig = PIIFilterConfig(
            preventPIIStorage: false,
            allowedPIITypes: Set(PIIType.allCases)
        )
        let permissiveFilter = PIIFilter(config: permissiveConfig, auditor: auditor)
        let permissiveResult = permissiveFilter.filterOCRText(testText)
        print("  Result: \(permissiveResult.filteredText)")
        print("  Should store: \(permissiveResult.shouldStore)")
        print()
    }
    
    // MARK: - Real-World Scenarios Demo
    
    private func demonstrateRealWorldScenarios() {
        print("6. Real-World Scenarios")
        print("=" * 40)
        
        let scenarios = [
            (
                name: "Medical Form",
                content: """
                PATIENT INTAKE FORM
                
                Patient Name: Sarah Johnson
                DOB: 03/22/1978
                SSN: 987-65-4321
                Phone: (555) 444-3333
                Email: sarah.j@email.com
                Insurance ID: ABC123456789
                
                Emergency Contact: Mike Johnson (555) 444-3334
                """,
                config: PIIFilterConfig(preventPIIStorage: true, allowedPIITypes: [])
            ),
            
            (
                name: "Business Card",
                content: """
                JOHN SMITH
                Senior Developer
                
                📧 john.smith@techcorp.com
                📱 (555) 123-4567
                🌐 www.techcorp.com
                
                TechCorp Solutions
                123 Innovation Drive
                """,
                config: PIIFilterConfig(preventPIIStorage: false, allowedPIITypes: [.email, .phone, .url])
            ),
            
            (
                name: "System Log",
                content: """
                [2024-03-15 10:30:15] INFO: User login successful
                [2024-03-15 10:30:16] DEBUG: Session ID: abc123def456
                [2024-03-15 10:30:17] ERROR: Failed to connect to 192.168.1.100:5432
                [2024-03-15 10:30:18] WARN: Invalid email format: user@invalid
                [2024-03-15 10:30:19] INFO: Processing payment for card ****1234
                """,
                config: PIIFilterConfig(preventPIIStorage: false, allowedPIITypes: [.ipAddress])
            )
        ]
        
        for scenario in scenarios {
            print("\n\(scenario.name):")
            print("-" * scenario.name.count)
            
            let customFilter = PIIFilter(config: scenario.config, auditor: auditor)
            let result = customFilter.filterOCRText(scenario.content, source: "Demo\(scenario.name.replacingOccurrences(of: " ", with: ""))")
            
            print("Original length: \(scenario.content.count) characters")
            print("Filtered length: \(result.filteredText.count) characters")
            print("PII detected: \(result.detectedTypes.map { $0.description }.joined(separator: ", "))")
            print("Should store: \(result.shouldStore ? "Yes" : "No")")
            
            if result.maskingApplied {
                print("✅ Masking applied")
            } else {
                print("ℹ️  No masking needed")
            }
        }
        
        print()
    }
}

// MARK: - Helper Extensions

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}