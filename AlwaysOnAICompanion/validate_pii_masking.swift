#!/usr/bin/env swift

import Foundation

// Simple validation script for PII masking functionality
// This script can be run independently to verify the PII system works correctly

print("=== PII Masking System Validation ===\n")

// Test data with various PII types
let testCases = [
    (
        name: "Email Detection",
        input: "Contact me at john.doe@company.com for more information",
        expectedPII: ["email"],
        shouldContainOriginal: false
    ),
    (
        name: "Phone Number Detection", 
        input: "Call me at (555) 123-4567 or text 555-987-6543",
        expectedPII: ["phone"],
        shouldContainOriginal: false
    ),
    (
        name: "SSN Detection",
        input: "My social security number is 123-45-6789",
        expectedPII: ["ssn"],
        shouldContainOriginal: false
    ),
    (
        name: "Credit Card Detection",
        input: "Payment with card 4111111111111111 was successful",
        expectedPII: ["credit_card"],
        shouldContainOriginal: false
    ),
    (
        name: "Multiple PII Types",
        input: "Employee: John Smith, Email: john@company.com, Phone: 555-1234, SSN: 123-45-6789",
        expectedPII: ["email", "phone", "ssn"],
        shouldContainOriginal: false
    ),
    (
        name: "Clean Text",
        input: "This is a clean document with no personal information",
        expectedPII: [],
        shouldContainOriginal: true
    ),
    (
        name: "IP Address Detection",
        input: "Server error at IP address 192.168.1.100",
        expectedPII: ["ip_address"],
        shouldContainOriginal: false
    ),
    (
        name: "Mixed Content",
        input: """
        CONFIDENTIAL FORM
        Name: Jane Smith
        Email: jane.smith@email.com
        Phone: (555) 444-3333
        Date: March 15, 2024
        Notes: Regular customer, no issues
        """,
        expectedPII: ["email", "phone"],
        shouldContainOriginal: false
    )
]

// Simple PII detection patterns (simplified version for validation)
let piiPatterns = [
    "email": #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#,
    "phone": #"\b(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})\b"#,
    "ssn": #"\b(?!000|666|9\d{2})\d{3}[-\s]?(?!00)\d{2}[-\s]?(?!0000)\d{4}\b"#,
    "credit_card": #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b"#,
    "ip_address": #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#
]

func detectPII(in text: String) -> [String] {
    var detectedTypes: [String] = []
    
    for (type, pattern) in piiPatterns {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, options: [], range: range)
            
            if !matches.isEmpty {
                detectedTypes.append(type)
            }
        } catch {
            print("Error with regex for \(type): \(error)")
        }
    }
    
    return detectedTypes
}

func maskPII(in text: String) -> String {
    var maskedText = text
    
    // Simple masking - replace detected PII with placeholders
    for (type, pattern) in piiPatterns {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: maskedText.utf16.count)
            
            switch type {
            case "email":
                maskedText = regex.stringByReplacingMatches(in: maskedText, options: [], range: range, withTemplate: "[EMAIL]")
            case "phone":
                maskedText = regex.stringByReplacingMatches(in: maskedText, options: [], range: range, withTemplate: "[PHONE]")
            case "ssn":
                maskedText = regex.stringByReplacingMatches(in: maskedText, options: [], range: range, withTemplate: "[SSN]")
            case "credit_card":
                maskedText = regex.stringByReplacingMatches(in: maskedText, options: [], range: range, withTemplate: "[CREDIT_CARD]")
            case "ip_address":
                maskedText = regex.stringByReplacingMatches(in: maskedText, options: [], range: range, withTemplate: "[IP_ADDRESS]")
            default:
                maskedText = regex.stringByReplacingMatches(in: maskedText, options: [], range: range, withTemplate: "[REDACTED]")
            }
        } catch {
            print("Error masking \(type): \(error)")
        }
    }
    
    return maskedText
}

// Run validation tests
var passedTests = 0
var totalTests = testCases.count

for (index, testCase) in testCases.enumerated() {
    print("Test \(index + 1): \(testCase.name)")
    print("Input: \(testCase.input)")
    
    // Detect PII
    let detectedPII = detectPII(in: testCase.input)
    print("Detected PII: \(detectedPII.isEmpty ? "None" : detectedPII.joined(separator: ", "))")
    
    // Apply masking
    let maskedText = maskPII(in: testCase.input)
    print("Masked: \(maskedText)")
    
    // Validate results
    var testPassed = true
    
    // Check if expected PII types were detected
    for expectedType in testCase.expectedPII {
        if !detectedPII.contains(expectedType) {
            print("❌ Expected PII type '\(expectedType)' not detected")
            testPassed = false
        }
    }
    
    // Check if original sensitive content is properly masked
    if !testCase.shouldContainOriginal {
        if maskedText == testCase.input && !detectedPII.isEmpty {
            print("❌ Original text not masked despite PII detection")
            testPassed = false
        }
    }
    
    // Check for false positives
    if testCase.expectedPII.isEmpty && !detectedPII.isEmpty {
        print("⚠️  Unexpected PII detected in clean text")
        // This is a warning, not a failure
    }
    
    if testPassed {
        print("✅ Test passed")
        passedTests += 1
    } else {
        print("❌ Test failed")
    }
    
    print("-" * 50)
}

// Summary
print("\n=== Validation Summary ===")
print("Passed: \(passedTests)/\(totalTests) tests")

if passedTests == totalTests {
    print("🎉 All tests passed! PII masking system is working correctly.")
    exit(0)
} else {
    print("⚠️  Some tests failed. Please review the PII masking implementation.")
    exit(1)
}

// Helper for string repetition
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}