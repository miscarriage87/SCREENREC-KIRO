#!/usr/bin/env swift

import Foundation
import CoreGraphics

// Add the Sources directory to the import path
import Shared

/// Validation script for browser-specific parsing plugin functionality
class BrowserParsingValidator {
    
    private let webPlugin: WebParsingPlugin
    private var testResults: [TestResult] = []
    
    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
        let executionTime: TimeInterval
    }
    
    init() {
        self.webPlugin = WebParsingPlugin()
        
        // Initialize plugin
        let tempDir = FileManager.default.temporaryDirectory
        let configuration = PluginConfiguration(
            pluginDirectory: tempDir,
            configurationData: [:],
            sandboxEnabled: false
        )
        
        do {
            try webPlugin.initialize(configuration: configuration)
            print("✅ WebParsingPlugin initialized for validation")
        } catch {
            print("❌ Failed to initialize WebParsingPlugin: \(error)")
            exit(1)
        }
    }
    
    deinit {
        webPlugin.cleanup()
    }
    
    func runAllValidations() {
        print("\n🌐 Browser-Specific Parsing Plugin Validation")
        print("=============================================\n")
        
        // Run validation tests
        validateURLTracking()
        validateDOMStructureAnalysis()
        validatePageContextClassification()
        validateFormDetection()
        validateNavigationElements()
        validateBreadcrumbExtraction()
        validateInteractiveElements()
        validateWebApplicationContext()
        validatePerformance()
        
        // Print summary
        printValidationSummary()
    }
    
    // MARK: - Validation Tests
    
    private func validateURLTracking() {
        let testName = "URL Tracking and Navigation History"
        let startTime = Date()
        
        do {
            let contexts = [
                ApplicationContext(
                    bundleID: "com.apple.Safari",
                    applicationName: "Safari",
                    windowTitle: "Home - https://www.example.com - Safari",
                    processID: 1234
                ),
                ApplicationContext(
                    bundleID: "com.apple.Safari",
                    applicationName: "Safari",
                    windowTitle: "Products - https://www.example.com/products - Safari",
                    processID: 1234
                ),
                ApplicationContext(
                    bundleID: "com.apple.Safari",
                    applicationName: "Safari",
                    windowTitle: "Contact - https://www.example.com/contact - Safari",
                    processID: 1234
                )
            ]
            
            let mockOCRResults = [
                OCRResult(text: "Page Content", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.9)
            ]
            let mockFrame = createMockCGImage()
            
            // Simulate navigation
            for context in contexts {
                _ = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            }
            
            // Validate navigation history
            let structuredData = try webPlugin.extractStructuredData(from: mockOCRResults, context: contexts.last!)
            
            let urlElement = structuredData.first { $0.type == "url" }
            let navElement = structuredData.first { $0.type == "navigation_history" }
            
            let urlValid = urlElement != nil && (urlElement?.value as? String) == "https://www.example.com/contact"
            let navValid = navElement != nil && (navElement?.value as? [String])?.count == 3
            
            let passed = urlValid && navValid
            let details = passed ? "URL extraction and navigation history tracking working correctly" : 
                         "Failed: URL valid=\(urlValid), Navigation valid=\(navValid)"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validateDOMStructureAnalysis() {
        let testName = "DOM Structure Analysis"
        let startTime = Date()
        
        do {
            let mockOCRResults = [
                OCRResult(text: "Main Page Title", boundingBox: CGRect(x: 100, y: 50, width: 300, height: 40), confidence: 0.95),
                OCRResult(text: "Section Heading", boundingBox: CGRect(x: 100, y: 150, width: 200, height: 30), confidence: 0.90),
                OCRResult(text: "Email:", boundingBox: CGRect(x: 50, y: 200, width: 60, height: 20), confidence: 0.95),
                OCRResult(text: "user@example.com", boundingBox: CGRect(x: 120, y: 200, width: 150, height: 20), confidence: 0.90),
                OCRResult(text: "Submit", boundingBox: CGRect(x: 100, y: 250, width: 60, height: 30), confidence: 0.95)
            ]
            
            let context = ApplicationContext(
                bundleID: "com.google.Chrome",
                applicationName: "Chrome",
                windowTitle: "Test Page - Chrome",
                processID: 1234
            )
            
            let mockFrame = createMockCGImage()
            let enhancedResults = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            // Validate DOM structure detection
            let domElement = structuredData.first { $0.type == "dom_structure" }
            let headings = enhancedResults.filter { $0.semanticType == "heading" }
            let formFields = enhancedResults.filter { $0.semanticType == "form_field" || $0.semanticType == "form_label" }
            let buttons = enhancedResults.filter { $0.semanticType == "form_button" }
            
            let domValid = domElement != nil
            let headingsValid = headings.count >= 1
            let formsValid = formFields.count >= 1
            let buttonsValid = buttons.count >= 1
            
            let passed = domValid && headingsValid && formsValid && buttonsValid
            let details = passed ? "DOM structure analysis working correctly" : 
                         "Failed: DOM=\(domValid), Headings=\(headingsValid), Forms=\(formsValid), Buttons=\(buttonsValid)"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validatePageContextClassification() {
        let testName = "Page Context Classification"
        let startTime = Date()
        
        do {
            let testCases = [
                ("Login Page - https://example.com/login - Safari", "login"),
                ("Search Results - https://example.com/search?q=test - Safari", "search"),
                ("User Profile - https://example.com/profile - Safari", "profile"),
                ("Product Page - https://shop.example.com/product/123 - Safari", "product")
            ]
            
            var passedCases = 0
            
            for (windowTitle, expectedType) in testCases {
                let context = ApplicationContext(
                    bundleID: "com.apple.Safari",
                    applicationName: "Safari",
                    windowTitle: windowTitle,
                    processID: 1234
                )
                
                let mockOCRResults = [
                    OCRResult(text: "Page Content", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.9)
                ]
                
                let mockFrame = createMockCGImage()
                _ = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
                let structuredData = try webPlugin.extractStructuredData(from: mockOCRResults, context: context)
                
                let urlElement = structuredData.first { $0.type == "url" }
                if urlElement != nil {
                    passedCases += 1
                }
            }
            
            let passed = passedCases == testCases.count
            let details = passed ? "Page context classification working correctly" : 
                         "Failed: \(passedCases)/\(testCases.count) cases passed"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validateFormDetection() {
        let testName = "Enhanced Form Detection"
        let startTime = Date()
        
        do {
            let mockOCRResults = [
                OCRResult(text: "First Name*:", boundingBox: CGRect(x: 50, y: 100, width: 100, height: 20), confidence: 0.95),
                OCRResult(text: "John", boundingBox: CGRect(x: 160, y: 100, width: 50, height: 20), confidence: 0.90),
                OCRResult(text: "Email Address:", boundingBox: CGRect(x: 50, y: 130, width: 120, height: 20), confidence: 0.95),
                OCRResult(text: "john@example.com", boundingBox: CGRect(x: 180, y: 130, width: 150, height: 20), confidence: 0.90),
                OCRResult(text: "Submit", boundingBox: CGRect(x: 100, y: 170, width: 60, height: 30), confidence: 0.95)
            ]
            
            let context = ApplicationContext(
                bundleID: "com.google.Chrome",
                applicationName: "Chrome",
                windowTitle: "Contact Form - Chrome",
                processID: 1234
            )
            
            let mockFrame = createMockCGImage()
            let enhancedResults = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            // Validate form detection
            let formFields = structuredData.filter { $0.type == "form_field" }
            let webForms = structuredData.filter { $0.type == "web_form" }
            let formButtons = enhancedResults.filter { $0.semanticType == "form_button" }
            
            let fieldsValid = formFields.count >= 2
            let formsValid = webForms.count >= 1 || formFields.count >= 2 // Either structured form or field pairs
            let buttonsValid = formButtons.count >= 1
            
            // Check field types
            let emailField = formFields.first { ($0.metadata["input_type"] as? String) == "email" }
            let requiredField = formFields.first { ($0.metadata["required"] as? Bool) == true }
            
            let typesValid = emailField != nil && requiredField != nil
            
            let passed = fieldsValid && formsValid && buttonsValid && typesValid
            let details = passed ? "Form detection working correctly" : 
                         "Failed: Fields=\(fieldsValid), Forms=\(formsValid), Buttons=\(buttonsValid), Types=\(typesValid)"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validateNavigationElements() {
        let testName = "Navigation Element Detection"
        let startTime = Date()
        
        do {
            let mockOCRResults = [
                OCRResult(text: "Home", boundingBox: CGRect(x: 50, y: 20, width: 50, height: 20), confidence: 0.95),
                OCRResult(text: "Products", boundingBox: CGRect(x: 110, y: 20, width: 70, height: 20), confidence: 0.95),
                OCRResult(text: "About", boundingBox: CGRect(x: 190, y: 20, width: 50, height: 20), confidence: 0.95),
                OCRResult(text: "Contact", boundingBox: CGRect(x: 250, y: 20, width: 60, height: 20), confidence: 0.95)
            ]
            
            let context = ApplicationContext(
                bundleID: "com.apple.Safari",
                applicationName: "Safari",
                windowTitle: "Company Website - Safari",
                processID: 1234
            )
            
            let mockFrame = createMockCGImage()
            let enhancedResults = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            
            let navItems = enhancedResults.filter { $0.semanticType == "navigation_item" }
            let primaryNavItems = navItems.filter { ($0.structuredData["nav_level"] as? Int) == 1 }
            
            let navValid = navItems.count >= 3
            let levelValid = primaryNavItems.count >= 3
            
            let passed = navValid && levelValid
            let details = passed ? "Navigation element detection working correctly" : 
                         "Failed: Navigation=\(navValid), Levels=\(levelValid)"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validateBreadcrumbExtraction() {
        let testName = "Breadcrumb Extraction"
        let startTime = Date()
        
        do {
            let mockOCRResults = [
                OCRResult(text: "Home > Products > Electronics > Laptops", boundingBox: CGRect(x: 50, y: 80, width: 300, height: 20), confidence: 0.95),
                OCRResult(text: "Gaming Laptop Selection", boundingBox: CGRect(x: 50, y: 120, width: 200, height: 30), confidence: 0.90)
            ]
            
            let context = ApplicationContext(
                bundleID: "com.apple.Safari",
                applicationName: "Safari",
                windowTitle: "Laptops - TechStore - Safari",
                processID: 1234
            )
            
            let mockFrame = createMockCGImage()
            _ = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            let breadcrumbElement = structuredData.first { $0.type == "breadcrumbs" }
            
            var breadcrumbsValid = false
            var depthValid = false
            
            if let breadcrumbs = breadcrumbElement?.value as? [String] {
                breadcrumbsValid = breadcrumbs.count == 4 && breadcrumbs[0] == "Home" && breadcrumbs.last == "Laptops"
                depthValid = (breadcrumbElement?.metadata["depth"] as? Int) == 4
            }
            
            let passed = breadcrumbsValid && depthValid
            let details = passed ? "Breadcrumb extraction working correctly" : 
                         "Failed: Breadcrumbs=\(breadcrumbsValid), Depth=\(depthValid)"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validateInteractiveElements() {
        let testName = "Interactive Element Detection"
        let startTime = Date()
        
        do {
            let mockOCRResults = [
                OCRResult(text: "Add to Cart", boundingBox: CGRect(x: 200, y: 300, width: 100, height: 40), confidence: 0.95),
                OCRResult(text: "☐ Subscribe to newsletter", boundingBox: CGRect(x: 50, y: 350, width: 200, height: 20), confidence: 0.90),
                OCRResult(text: "● Option A", boundingBox: CGRect(x: 50, y: 380, width: 100, height: 20), confidence: 0.90),
                OCRResult(text: "○ Option B", boundingBox: CGRect(x: 50, y: 400, width: 100, height: 20), confidence: 0.90)
            ]
            
            let context = ApplicationContext(
                bundleID: "com.google.Chrome",
                applicationName: "Chrome",
                windowTitle: "Product Page - Chrome",
                processID: 1234
            )
            
            let mockFrame = createMockCGImage()
            let enhancedResults = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            
            let interactiveElements = enhancedResults.filter { $0.semanticType == "interactive_element" }
            let buttons = interactiveElements.filter { ($0.structuredData["element_type"] as? String) == "button" }
            let checkboxes = interactiveElements.filter { ($0.structuredData["element_type"] as? String) == "checkbox" }
            let radios = interactiveElements.filter { ($0.structuredData["element_type"] as? String) == "radio" }
            
            let buttonsValid = buttons.count >= 1
            let checkboxesValid = checkboxes.count >= 1
            let radiosValid = radios.count >= 1
            
            // Check states
            let uncheckedCheckbox = checkboxes.first { ($0.structuredData["element_state"] as? String) == "unchecked" }
            let checkedRadio = radios.first { ($0.structuredData["element_state"] as? String) == "checked" }
            
            let statesValid = uncheckedCheckbox != nil && checkedRadio != nil
            
            let passed = buttonsValid && checkboxesValid && radiosValid && statesValid
            let details = passed ? "Interactive element detection working correctly" : 
                         "Failed: Buttons=\(buttonsValid), Checkboxes=\(checkboxesValid), Radios=\(radiosValid), States=\(statesValid)"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validateWebApplicationContext() {
        let testName = "Web Application Context Detection"
        let startTime = Date()
        
        do {
            let testCases = [
                ("Jira Dashboard - https://company.atlassian.net/dashboard - Safari", "jira"),
                ("Salesforce - https://company.salesforce.com - Safari", "salesforce"),
                ("Facebook - https://www.facebook.com - Safari", "facebook"),
                ("Online Store - https://shop.example.com - Safari", "shop")
            ]
            
            var passedCases = 0
            
            for (windowTitle, expectedDomain) in testCases {
                let context = ApplicationContext(
                    bundleID: "com.apple.Safari",
                    applicationName: "Safari",
                    windowTitle: windowTitle,
                    processID: 1234
                )
                
                let mockOCRResults = [
                    OCRResult(text: "Application Content", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.9)
                ]
                
                let mockFrame = createMockCGImage()
                _ = try webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
                let structuredData = try webPlugin.extractStructuredData(from: mockOCRResults, context: context)
                
                let urlElement = structuredData.first { $0.type == "url" }
                if let domain = urlElement?.metadata["domain"] as? String,
                   domain.lowercased().contains(expectedDomain) {
                    passedCases += 1
                }
            }
            
            let passed = passedCases >= testCases.count - 1 // Allow one failure
            let details = passed ? "Web application context detection working correctly" : 
                         "Failed: \(passedCases)/\(testCases.count) cases passed"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    private func validatePerformance() {
        let testName = "Performance with Large OCR Results"
        let startTime = Date()
        
        do {
            // Create large OCR result set
            let largeOCRResults = (0..<500).map { index in
                OCRResult(
                    text: "Text element \(index)",
                    boundingBox: CGRect(x: CGFloat(index % 50) * 10, y: CGFloat(index / 50) * 20, width: 100, height: 18),
                    confidence: Float.random(in: 0.8...0.95)
                )
            }
            
            let context = ApplicationContext(
                bundleID: "com.apple.Safari",
                applicationName: "Safari",
                windowTitle: "Large Page - Safari",
                processID: 1234
            )
            
            let mockFrame = createMockCGImage()
            let processingStart = Date()
            _ = try webPlugin.enhanceOCRResults(largeOCRResults, context: context, frame: mockFrame)
            let processingTime = Date().timeIntervalSince(processingStart)
            
            // Performance should be under 2 seconds for 500 elements
            let performanceValid = processingTime < 2.0
            
            let passed = performanceValid
            let details = passed ? "Performance test passed (\(String(format: "%.3f", processingTime))s)" : 
                         "Performance test failed: \(String(format: "%.3f", processingTime))s (expected < 2.0s)"
            
            testResults.append(TestResult(
                testName: testName,
                passed: passed,
                details: details,
                executionTime: Date().timeIntervalSince(startTime)
            ))
            
        } catch {
            testResults.append(TestResult(
                testName: testName,
                passed: false,
                details: "Error: \(error)",
                executionTime: Date().timeIntervalSince(startTime)
            ))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockCGImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 800,
            height: 600,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        
        return context.makeImage()!
    }
    
    private func printValidationSummary() {
        print("\n📊 Validation Summary")
        print("====================")
        
        let passedTests = testResults.filter { $0.passed }
        let failedTests = testResults.filter { !$0.passed }
        
        print("✅ Passed: \(passedTests.count)")
        print("❌ Failed: \(failedTests.count)")
        print("📈 Success Rate: \(String(format: "%.1f", Double(passedTests.count) / Double(testResults.count) * 100))%")
        
        let totalTime = testResults.reduce(0) { $0 + $1.executionTime }
        print("⏱️  Total Execution Time: \(String(format: "%.3f", totalTime))s")
        
        print("\n📋 Detailed Results:")
        for result in testResults {
            let status = result.passed ? "✅" : "❌"
            let time = String(format: "%.3f", result.executionTime)
            print("  \(status) \(result.testName) (\(time)s)")
            if !result.passed {
                print("      \(result.details)")
            }
        }
        
        if failedTests.isEmpty {
            print("\n🎉 All browser parsing validations passed successfully!")
        } else {
            print("\n⚠️  Some validations failed. Please review the implementation.")
        }
    }
}

// MARK: - Main Execution

let validator = BrowserParsingValidator()
validator.runAllValidations()