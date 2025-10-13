import Foundation
import CoreGraphics
import Shared

/// Demo showcasing browser-specific parsing capabilities
public class BrowserParsingDemo {
    
    private let webPlugin: WebParsingPlugin
    
    public init() {
        self.webPlugin = WebParsingPlugin()
        
        // Initialize plugin with demo configuration
        let tempDir = FileManager.default.temporaryDirectory
        let configuration = PluginConfiguration(
            pluginDirectory: tempDir,
            configurationData: [
                "enable_url_tracking": true,
                "enable_dom_analysis": true,
                "cache_size": 100
            ],
            sandboxEnabled: false
        )
        
        do {
            try webPlugin.initialize(configuration: configuration)
            print("✅ WebParsingPlugin initialized successfully")
        } catch {
            print("❌ Failed to initialize WebParsingPlugin: \(error)")
        }
    }
    
    deinit {
        webPlugin.cleanup()
    }
    
    // MARK: - Demo Scenarios
    
    public func runAllDemos() {
        print("\n🌐 Browser-Specific Parsing Plugin Demo")
        print("=====================================\n")
        
        Task {
            await demoEcommerceParsing()
            await demoSocialMediaParsing()
            await demoProductivityToolParsing()
            await demoFormAnalysis()
            await demoNavigationTracking()
            await demoContentStructureAnalysis()
            
            print("\n✅ All browser parsing demos completed successfully!")
        }
    }
    
    // MARK: - E-commerce Parsing Demo
    
    private func demoEcommerceParsing() async {
        print("🛒 E-commerce Website Parsing Demo")
        print("----------------------------------")
        
        let mockOCRResults = [
            OCRResult(text: "Home > Electronics > Laptops > Gaming", boundingBox: CGRect(x: 50, y: 30, width: 300, height: 18), confidence: 0.95),
            OCRResult(text: "ASUS ROG Strix G15", boundingBox: CGRect(x: 50, y: 80, width: 250, height: 35), confidence: 0.95),
            OCRResult(text: "$1,299.99", boundingBox: CGRect(x: 50, y: 130, width: 100, height: 25), confidence: 0.90),
            OCRResult(text: "⭐⭐⭐⭐⭐ (4.8/5)", boundingBox: CGRect(x: 160, y: 135, width: 120, height: 20), confidence: 0.88),
            OCRResult(text: "Color:", boundingBox: CGRect(x: 50, y: 180, width: 50, height: 20), confidence: 0.95),
            OCRResult(text: "Eclipse Gray", boundingBox: CGRect(x: 110, y: 180, width: 90, height: 20), confidence: 0.90),
            OCRResult(text: "RAM:", boundingBox: CGRect(x: 50, y: 210, width: 40, height: 20), confidence: 0.95),
            OCRResult(text: "16GB DDR4", boundingBox: CGRect(x: 100, y: 210, width: 80, height: 20), confidence: 0.90),
            OCRResult(text: "Storage:", boundingBox: CGRect(x: 50, y: 240, width: 60, height: 20), confidence: 0.95),
            OCRResult(text: "1TB SSD", boundingBox: CGRect(x: 120, y: 240, width: 70, height: 20), confidence: 0.90),
            OCRResult(text: "Add to Cart", boundingBox: CGRect(x: 50, y: 290, width: 100, height: 40), confidence: 0.95),
            OCRResult(text: "Buy Now", boundingBox: CGRect(x: 160, y: 290, width: 80, height: 40), confidence: 0.95),
            OCRResult(text: "♡ Add to Wishlist", boundingBox: CGRect(x: 250, y: 295, width: 120, height: 30), confidence: 0.90)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.google.Chrome",
            applicationName: "Chrome",
            windowTitle: "ASUS ROG Strix G15 - TechStore - https://www.techstore.com/laptops/gaming/asus-rog-strix-g15 - Chrome",
            processID: 1234
        )
        
        do {
            let mockFrame = createMockCGImage()
            let enhancedResults = try await webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try await webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            print("📊 Analysis Results:")
            
            // URL and page context
            if let urlElement = structuredData.first(where: { $0.type == "url" }) {
                print("  🔗 URL: \(urlElement.value)")
                print("  🌐 Domain: \(urlElement.metadata["domain"] ?? "unknown")")
                print("  📄 Page Type: \(urlElement.metadata["page_type"] ?? "unknown")")
            }
            
            // Breadcrumb navigation
            if let breadcrumbElement = structuredData.first(where: { $0.type == "breadcrumbs" }) {
                if let breadcrumbs = breadcrumbElement.value as? [String] {
                    print("  🍞 Breadcrumbs: \(breadcrumbs.joined(separator: " > "))")
                    print("  📍 Current Section: \(breadcrumbs.last ?? "unknown")")
                }
            }
            
            // Product information (form fields)
            let productFields = structuredData.filter { $0.type == "form_field" }
            print("  🏷️  Product Options:")
            for field in productFields {
                let label = field.metadata["label"] as? String ?? "Unknown"
                let value = field.value as? String ?? ""
                print("    • \(label): \(value)")
            }
            
            // Interactive elements
            let buttons = enhancedResults.filter { $0.semanticType == "form_button" || $0.semanticType == "interactive_element" }
            print("  🔘 Interactive Elements: \(buttons.count)")
            for button in buttons {
                let buttonType = button.structuredData["button_type"] as? String ?? 
                               button.structuredData["element_type"] as? String ?? "button"
                print("    • \(button.originalResult.text) (\(buttonType))")
            }
            
            // DOM structure summary
            if let domElement = structuredData.first(where: { $0.type == "dom_structure" }) {
                if let structure = domElement.value as? [String: Any] {
                    print("  🏗️  Page Structure:")
                    print("    • Forms: \(structure["forms"] ?? 0)")
                    print("    • Interactive Elements: \(structure["interactive_elements"] ?? 0)")
                    print("    • Navigation Items: \(structure["navigation_items"] ?? 0)")
                }
            }
            
        } catch {
            print("❌ Error in e-commerce parsing demo: \(error)")
        }
        
        print("")
    }
    
    // MARK: - Social Media Parsing Demo
    
    private func demoSocialMediaParsing() async {
        print("📱 Social Media Platform Parsing Demo")
        print("------------------------------------")
        
        let mockOCRResults = [
            OCRResult(text: "Home", boundingBox: CGRect(x: 50, y: 20, width: 50, height: 20), confidence: 0.95),
            OCRResult(text: "Explore", boundingBox: CGRect(x: 110, y: 20, width: 60, height: 20), confidence: 0.95),
            OCRResult(text: "Notifications", boundingBox: CGRect(x: 180, y: 20, width: 90, height: 20), confidence: 0.95),
            OCRResult(text: "Messages", boundingBox: CGRect(x: 280, y: 20, width: 70, height: 20), confidence: 0.95),
            OCRResult(text: "Profile", boundingBox: CGRect(x: 360, y: 20, width: 50, height: 20), confidence: 0.95),
            OCRResult(text: "Sarah Johnson", boundingBox: CGRect(x: 70, y: 80, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "@sarahj_dev", boundingBox: CGRect(x: 70, y: 100, width: 80, height: 16), confidence: 0.90),
            OCRResult(text: "Just deployed my new React app! 🚀 Excited to share it with everyone.", boundingBox: CGRect(x: 70, y: 130, width: 400, height: 18), confidence: 0.90),
            OCRResult(text: "2 hours ago", boundingBox: CGRect(x: 70, y: 155, width: 80, height: 14), confidence: 0.85),
            OCRResult(text: "❤️ 24", boundingBox: CGRect(x: 70, y: 180, width: 50, height: 18), confidence: 0.90),
            OCRResult(text: "💬 8", boundingBox: CGRect(x: 130, y: 180, width: 40, height: 18), confidence: 0.90),
            OCRResult(text: "🔄 3", boundingBox: CGRect(x: 180, y: 180, width: 40, height: 18), confidence: 0.90),
            OCRResult(text: "Share", boundingBox: CGRect(x: 230, y: 180, width: 50, height: 18), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Twitter - https://twitter.com/home - Safari",
            processID: 1234
        )
        
        do {
            let mockFrame = createMockCGImage()
            let enhancedResults = try await webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try await webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            print("📊 Analysis Results:")
            
            // Platform detection
            if let urlElement = structuredData.first(where: { $0.type == "url" }) {
                print("  🌐 Platform: Twitter (\(urlElement.metadata["domain"] ?? "unknown"))")
                print("  📱 App Context: \(urlElement.metadata["app_context"] ?? "unknown")")
            }
            
            // Navigation structure
            let navItems = enhancedResults.filter { $0.semanticType == "navigation_item" }
            print("  🧭 Navigation Items: \(navItems.count)")
            for nav in navItems {
                let level = nav.structuredData["nav_level"] as? Int ?? 0
                print("    • \(nav.originalResult.text) (Level \(level))")
            }
            
            // Social interactions
            let interactions = enhancedResults.filter { 
                $0.semanticType == "interactive_element" || 
                ($0.semanticType == "form_button" && $0.originalResult.text.lowercased().contains("share"))
            }
            print("  💫 Social Interactions: \(interactions.count)")
            for interaction in interactions {
                print("    • \(interaction.originalResult.text)")
            }
            
            // Content analysis
            let contentSections = enhancedResults.filter { $0.semanticType == "content_section" }
            print("  📝 Content Sections: \(contentSections.count)")
            
            // Page metadata
            if let pageMetadata = structuredData.first(where: { $0.type == "page_metadata" }) {
                let linkCount = pageMetadata.metadata["linkCount"] as? Int ?? 0
                let buttonCount = pageMetadata.metadata["buttonCount"] as? Int ?? 0
                print("  📈 Page Stats: \(linkCount) links, \(buttonCount) buttons")
            }
            
        } catch {
            print("❌ Error in social media parsing demo: \(error)")
        }
        
        print("")
    }
    
    // MARK: - Productivity Tool Parsing Demo
    
    private func demoProductivityToolParsing() async {
        print("💼 Productivity Tool Parsing Demo (Jira)")
        print("---------------------------------------")
        
        let mockOCRResults = [
            OCRResult(text: "Projects > Mobile App > Sprint 23", boundingBox: CGRect(x: 50, y: 30, width: 250, height: 18), confidence: 0.95),
            OCRResult(text: "Create User Authentication System", boundingBox: CGRect(x: 50, y: 80, width: 300, height: 25), confidence: 0.95),
            OCRResult(text: "TASK-1234", boundingBox: CGRect(x: 50, y: 110, width: 80, height: 18), confidence: 0.90),
            OCRResult(text: "Status:", boundingBox: CGRect(x: 50, y: 140, width: 50, height: 18), confidence: 0.95),
            OCRResult(text: "In Progress", boundingBox: CGRect(x: 110, y: 140, width: 80, height: 18), confidence: 0.90),
            OCRResult(text: "Assignee:", boundingBox: CGRect(x: 50, y: 165, width: 70, height: 18), confidence: 0.95),
            OCRResult(text: "John Smith", boundingBox: CGRect(x: 130, y: 165, width: 80, height: 18), confidence: 0.90),
            OCRResult(text: "Priority:", boundingBox: CGRect(x: 50, y: 190, width: 60, height: 18), confidence: 0.95),
            OCRResult(text: "High", boundingBox: CGRect(x: 120, y: 190, width: 40, height: 18), confidence: 0.90),
            OCRResult(text: "Due Date:", boundingBox: CGRect(x: 50, y: 215, width: 70, height: 18), confidence: 0.95),
            OCRResult(text: "2024-01-15", boundingBox: CGRect(x: 130, y: 215, width: 80, height: 18), confidence: 0.90),
            OCRResult(text: "Edit", boundingBox: CGRect(x: 50, y: 250, width: 40, height: 30), confidence: 0.95),
            OCRResult(text: "Comment", boundingBox: CGRect(x: 100, y: 250, width: 70, height: 30), confidence: 0.95),
            OCRResult(text: "Transition", boundingBox: CGRect(x: 180, y: 250, width: 80, height: 30), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.google.Chrome",
            applicationName: "Chrome",
            windowTitle: "TASK-1234 - Company Jira - https://company.atlassian.net/browse/TASK-1234 - Chrome",
            processID: 1234
        )
        
        do {
            let mockFrame = createMockCGImage()
            let enhancedResults = try await webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try await webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            print("📊 Analysis Results:")
            
            // Tool identification
            if let urlElement = structuredData.first(where: { $0.type == "url" }) {
                print("  🛠️  Tool: Jira (\(urlElement.metadata["domain"] ?? "unknown"))")
                print("  🎯 Context: \(urlElement.metadata["app_context"] ?? "unknown")")
            }
            
            // Project navigation
            if let breadcrumbElement = structuredData.first(where: { $0.type == "breadcrumbs" }) {
                if let breadcrumbs = breadcrumbElement.value as? [String] {
                    print("  📂 Project Path: \(breadcrumbs.joined(separator: " > "))")
                }
            }
            
            // Task information
            let taskFields = structuredData.filter { $0.type == "form_field" }
            print("  📋 Task Details:")
            for field in taskFields {
                let label = field.metadata["label"] as? String ?? "Unknown"
                let value = field.value as? String ?? ""
                print("    • \(label): \(value)")
            }
            
            // Workflow actions
            let workflowButtons = enhancedResults.filter { 
                $0.semanticType == "form_button" || $0.semanticType == "interactive_element"
            }
            print("  ⚡ Available Actions: \(workflowButtons.count)")
            for button in workflowButtons {
                print("    • \(button.originalResult.text)")
            }
            
            // Form structure
            if let formElement = structuredData.first(where: { $0.type == "web_form" }) {
                let fieldCount = formElement.metadata["field_count"] as? Int ?? 0
                print("  📝 Form Structure: \(fieldCount) fields detected")
            }
            
        } catch {
            print("❌ Error in productivity tool parsing demo: \(error)")
        }
        
        print("")
    }
    
    // MARK: - Form Analysis Demo
    
    private func demoFormAnalysis() async {
        print("📝 Advanced Form Analysis Demo")
        print("-----------------------------")
        
        let mockOCRResults = [
            OCRResult(text: "Contact Information", boundingBox: CGRect(x: 50, y: 50, width: 200, height: 25), confidence: 0.95),
            OCRResult(text: "First Name*:", boundingBox: CGRect(x: 50, y: 100, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "John", boundingBox: CGRect(x: 160, y: 100, width: 50, height: 20), confidence: 0.90),
            OCRResult(text: "Last Name*:", boundingBox: CGRect(x: 250, y: 100, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "Doe", boundingBox: CGRect(x: 360, y: 100, width: 40, height: 20), confidence: 0.90),
            OCRResult(text: "Email Address*:", boundingBox: CGRect(x: 50, y: 130, width: 120, height: 20), confidence: 0.95),
            OCRResult(text: "john.doe@example.com", boundingBox: CGRect(x: 180, y: 130, width: 180, height: 20), confidence: 0.90),
            OCRResult(text: "Phone Number:", boundingBox: CGRect(x: 50, y: 160, width: 110, height: 20), confidence: 0.95),
            OCRResult(text: "+1 (555) 123-4567", boundingBox: CGRect(x: 170, y: 160, width: 130, height: 20), confidence: 0.88),
            OCRResult(text: "Company:", boundingBox: CGRect(x: 50, y: 190, width: 70, height: 20), confidence: 0.95),
            OCRResult(text: "Tech Corp Inc.", boundingBox: CGRect(x: 130, y: 190, width: 100, height: 20), confidence: 0.90),
            OCRResult(text: "Message*:", boundingBox: CGRect(x: 50, y: 220, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "I'm interested in your services...", boundingBox: CGRect(x: 50, y: 250, width: 300, height: 60), confidence: 0.85),
            OCRResult(text: "☐ Subscribe to newsletter", boundingBox: CGRect(x: 50, y: 330, width: 200, height: 20), confidence: 0.90),
            OCRResult(text: "☑ I agree to the terms and conditions", boundingBox: CGRect(x: 50, y: 360, width: 280, height: 20), confidence: 0.90),
            OCRResult(text: "Submit", boundingBox: CGRect(x: 50, y: 400, width: 80, height: 35), confidence: 0.95),
            OCRResult(text: "Reset", boundingBox: CGRect(x: 140, y: 400, width: 60, height: 35), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Contact Us - TechCorp - https://www.techcorp.com/contact - Safari",
            processID: 1234
        )
        
        do {
            let mockFrame = createMockCGImage()
            let enhancedResults = try await webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try await webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            print("📊 Analysis Results:")
            
            // Form structure analysis
            if let formElement = structuredData.first(where: { $0.type == "web_form" }) {
                let fieldCount = formElement.metadata["field_count"] as? Int ?? 0
                let submitButtons = formElement.metadata["submit_buttons"] as? Int ?? 0
                print("  📋 Form Structure:")
                print("    • Total Fields: \(fieldCount)")
                print("    • Submit Buttons: \(submitButtons)")
            }
            
            // Field analysis
            let formFields = structuredData.filter { $0.type == "form_field" }
            print("  🏷️  Field Analysis:")
            var requiredFields = 0
            var optionalFields = 0
            
            for field in formFields {
                let label = field.metadata["label"] as? String ?? "Unknown"
                let fieldType = field.metadata["field_type"] as? String ?? field.metadata["input_type"] as? String ?? "text"
                let required = field.metadata["required"] as? Bool ?? false
                let value = field.value as? String ?? ""
                
                if required {
                    requiredFields += 1
                } else {
                    optionalFields += 1
                }
                
                let requiredMark = required ? "*" : ""
                print("    • \(label)\(requiredMark) (\(fieldType)): \(value.isEmpty ? "empty" : "filled")")
            }
            
            print("  📊 Field Summary: \(requiredFields) required, \(optionalFields) optional")
            
            // Interactive elements
            let checkboxes = enhancedResults.filter { 
                $0.semanticType == "interactive_element" && 
                ($0.structuredData["element_type"] as? String) == "checkbox"
            }
            print("  ☑️  Checkboxes: \(checkboxes.count)")
            for checkbox in checkboxes {
                let state = checkbox.structuredData["element_state"] as? String ?? "unknown"
                print("    • \(checkbox.originalResult.text) (\(state))")
            }
            
            // Form buttons
            let buttons = enhancedResults.filter { $0.semanticType == "form_button" }
            print("  🔘 Form Buttons: \(buttons.count)")
            for button in buttons {
                let buttonType = button.structuredData["button_type"] as? String ?? "action"
                let isPrimary = button.structuredData["is_primary"] as? Bool ?? false
                let primaryMark = isPrimary ? " (primary)" : ""
                print("    • \(button.originalResult.text) (\(buttonType))\(primaryMark)")
            }
            
        } catch {
            print("❌ Error in form analysis demo: \(error)")
        }
        
        print("")
    }
    
    // MARK: - Navigation Tracking Demo
    
    private func demoNavigationTracking() async {
        print("🧭 Navigation Tracking Demo")
        print("--------------------------")
        
        // Simulate navigation through multiple pages
        let navigationSequence = [
            ("Home - TechStore - https://www.techstore.com - Safari", "homepage"),
            ("Laptops - TechStore - https://www.techstore.com/laptops - Safari", "category"),
            ("Gaming Laptops - TechStore - https://www.techstore.com/laptops/gaming - Safari", "subcategory"),
            ("ASUS ROG - TechStore - https://www.techstore.com/laptops/gaming/asus-rog-strix - Safari", "product")
        ]
        
        let mockOCRResults = [
            OCRResult(text: "Navigation content", boundingBox: CGRect(x: 50, y: 100, width: 200, height: 20), confidence: 0.90)
        ]
        
        print("📊 Navigation Sequence:")
        
        for (index, (windowTitle, pageType)) in navigationSequence.enumerated() {
            let context = ApplicationContext(
                bundleID: "com.apple.Safari",
                applicationName: "Safari",
                windowTitle: windowTitle,
                processID: 1234
            )
            
            do {
                let mockFrame = createMockCGImage()
                _ = try await webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
                let structuredData = try await webPlugin.extractStructuredData(from: mockOCRResults, context: context)
                
                if let urlElement = structuredData.first(where: { $0.type == "url" }) {
                    let url = urlElement.value as? String ?? "unknown"
                    print("  \(index + 1). \(pageType.capitalized): \(url)")
                }
                
                // Show navigation history after a few steps
                if index >= 2 {
                    if let navElement = structuredData.first(where: { $0.type == "navigation_history" }) {
                        if let urls = navElement.value as? [String] {
                            print("     📚 Recent History: \(urls.suffix(3).joined(separator: " → "))")
                        }
                    }
                }
                
            } catch {
                print("❌ Error tracking navigation step \(index + 1): \(error)")
            }
        }
        
        print("")
    }
    
    // MARK: - Content Structure Analysis Demo
    
    private func demoContentStructureAnalysis() async {
        print("🏗️ Content Structure Analysis Demo")
        print("----------------------------------")
        
        let mockOCRResults = [
            // Header section
            OCRResult(text: "TechBlog", boundingBox: CGRect(x: 50, y: 20, width: 100, height: 30), confidence: 0.95),
            OCRResult(text: "Home", boundingBox: CGRect(x: 200, y: 25, width: 50, height: 20), confidence: 0.95),
            OCRResult(text: "Articles", boundingBox: CGRect(x: 260, y: 25, width: 60, height: 20), confidence: 0.95),
            OCRResult(text: "About", boundingBox: CGRect(x: 330, y: 25, width: 50, height: 20), confidence: 0.95),
            
            // Main content
            OCRResult(text: "The Future of Web Development", boundingBox: CGRect(x: 50, y: 80, width: 350, height: 35), confidence: 0.95),
            OCRResult(text: "Published on January 10, 2024", boundingBox: CGRect(x: 50, y: 120, width: 200, height: 16), confidence: 0.90),
            OCRResult(text: "Introduction", boundingBox: CGRect(x: 50, y: 160, width: 120, height: 25), confidence: 0.95),
            OCRResult(text: "Web development continues to evolve rapidly...", boundingBox: CGRect(x: 50, y: 190, width: 400, height: 60), confidence: 0.85),
            OCRResult(text: "Key Technologies", boundingBox: CGRect(x: 50, y: 270, width: 150, height: 25), confidence: 0.95),
            OCRResult(text: "React, Vue.js, and Angular remain popular...", boundingBox: CGRect(x: 50, y: 300, width: 400, height: 60), confidence: 0.85),
            OCRResult(text: "Conclusion", boundingBox: CGRect(x: 50, y: 380, width: 100, height: 25), confidence: 0.95),
            OCRResult(text: "The future looks bright for web developers...", boundingBox: CGRect(x: 50, y: 410, width: 400, height: 40), confidence: 0.85),
            
            // Sidebar
            OCRResult(text: "Related Articles", boundingBox: CGRect(x: 500, y: 160, width: 150, height: 25), confidence: 0.95),
            OCRResult(text: "• JavaScript Trends 2024", boundingBox: CGRect(x: 500, y: 190, width: 180, height: 18), confidence: 0.90),
            OCRResult(text: "• CSS Grid vs Flexbox", boundingBox: CGRect(x: 500, y: 215, width: 160, height: 18), confidence: 0.90),
            OCRResult(text: "• API Design Best Practices", boundingBox: CGRect(x: 500, y: 240, width: 190, height: 18), confidence: 0.90),
            
            // Footer
            OCRResult(text: "© 2024 TechBlog. All rights reserved.", boundingBox: CGRect(x: 50, y: 500, width: 250, height: 16), confidence: 0.85)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "The Future of Web Development - TechBlog - https://techblog.com/articles/future-web-dev - Safari",
            processID: 1234
        )
        
        do {
            let mockFrame = createMockCGImage()
            let enhancedResults = try await webPlugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            let structuredData = try await webPlugin.extractStructuredData(from: mockOCRResults, context: context)
            
            print("📊 Analysis Results:")
            
            // Page structure
            if let domElement = structuredData.first(where: { $0.type == "dom_structure" }) {
                if let structure = domElement.value as? [String: Any] {
                    print("  🏗️  Page Structure:")
                    print("    • Headings: \(structure["headings"] ?? 0)")
                    print("    • Content Sections: \(structure["content_sections"] ?? 0)")
                    print("    • Navigation Items: \(structure["navigation_items"] ?? 0)")
                    print("    • Interactive Elements: \(structure["interactive_elements"] ?? 0)")
                }
            }
            
            // Heading hierarchy
            let headings = enhancedResults.filter { $0.semanticType == "heading" }
            print("  📑 Heading Structure:")
            for heading in headings.sorted(by: { $0.originalResult.boundingBox.origin.y < $1.originalResult.boundingBox.origin.y }) {
                let level = heading.structuredData["heading_level"] as? Int ?? 0
                let indent = String(repeating: "  ", count: level)
                print("    \(indent)H\(level): \(heading.originalResult.text)")
            }
            
            // Content sections
            let contentSections = enhancedResults.filter { $0.semanticType == "content_section" }
            print("  📄 Content Sections: \(contentSections.count)")
            for section in contentSections {
                let sectionType = section.structuredData["section_type"] as? String ?? "section"
                let heading = section.structuredData["section_heading"] as? String ?? "No heading"
                print("    • \(sectionType.capitalized): \(heading)")
            }
            
            // Navigation analysis
            let navItems = enhancedResults.filter { $0.semanticType == "navigation_item" }
            print("  🧭 Navigation: \(navItems.count) items")
            for nav in navItems {
                let level = nav.structuredData["nav_level"] as? Int ?? 1
                print("    • \(nav.originalResult.text) (Level \(level))")
            }
            
            // Page metadata
            if let pageMetadata = structuredData.first(where: { $0.type == "page_metadata" }) {
                let pageTitle = pageMetadata.metadata["pageTitle"] as? String ?? "Unknown"
                print("  📋 Page Title: \(pageTitle)")
            }
            
        } catch {
            print("❌ Error in content structure analysis demo: \(error)")
        }
        
        print("")
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
}

// MARK: - Demo Runner

public func runBrowserParsingDemo() {
    let demo = BrowserParsingDemo()
    demo.runAllDemos()
}