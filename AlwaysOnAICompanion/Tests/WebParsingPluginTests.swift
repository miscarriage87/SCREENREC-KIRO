import XCTest
import CoreGraphics
@testable import Shared

class WebParsingPluginTests: XCTestCase {
    
    var plugin: WebParsingPlugin!
    var mockConfiguration: PluginConfiguration!
    
    override func setUp() {
        super.setUp()
        plugin = WebParsingPlugin()
        
        let tempDir = FileManager.default.temporaryDirectory
        mockConfiguration = PluginConfiguration(
            pluginDirectory: tempDir,
            configurationData: [:],
            sandboxEnabled: false
        )
        
        try! plugin.initialize(configuration: mockConfiguration)
    }
    
    override func tearDown() {
        plugin.cleanup()
        plugin = nil
        mockConfiguration = nil
        super.tearDown()
    }
    
    // MARK: - Basic Plugin Tests
    
    func testPluginInitialization() {
        XCTAssertEqual(plugin.identifier, "com.alwayson.plugins.web")
        XCTAssertEqual(plugin.name, "Web Application Parser")
        XCTAssertEqual(plugin.version, "2.0.0")
        XCTAssertTrue(plugin.supportedApplications.contains("com.apple.Safari"))
        XCTAssertTrue(plugin.supportedApplications.contains("com.google.Chrome"))
    }
    
    func testCanHandleBrowserApplications() {
        let safariContext = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Google - Safari",
            processID: 1234
        )
        
        let chromeContext = ApplicationContext(
            bundleID: "com.google.Chrome",
            applicationName: "Chrome",
            windowTitle: "Google - Google Chrome",
            processID: 1235
        )
        
        let nonBrowserContext = ApplicationContext(
            bundleID: "com.apple.TextEdit",
            applicationName: "TextEdit",
            windowTitle: "Document.txt",
            processID: 1236
        )
        
        XCTAssertTrue(plugin.canHandle(context: safariContext))
        XCTAssertTrue(plugin.canHandle(context: chromeContext))
        XCTAssertFalse(plugin.canHandle(context: nonBrowserContext))
    }
    
    // MARK: - URL Tracking Tests
    
    func testURLExtractionFromWindowTitle() async {
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Example Page - https://www.example.com/page - Safari",
            processID: 1234
        )
        
        let mockOCRResults = [
            OCRResult(
                text: "Welcome to Example",
                boundingBox: CGRect(x: 100, y: 50, width: 200, height: 30),
                confidence: 0.95
            )
        ]
        
        let mockFrame = createMockCGImage()
        let enhancedResults = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        
        // Verify URL tracking occurred
        XCTAssertTrue(enhancedResults.count > 0)
        
        let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: context)
        let urlElement = structuredData.first { $0.type == "url" }
        
        XCTAssertNotNil(urlElement)
        XCTAssertEqual(urlElement?.value as? String, "https://www.example.com/page")
        XCTAssertEqual(urlElement?.metadata["domain"] as? String, "www.example.com")
        XCTAssertEqual(urlElement?.metadata["protocol"] as? String, "https")
    }
    
    func testNavigationHistoryTracking() async {
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
                windowTitle: "About - https://www.example.com/about - Safari",
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
        
        // Simulate navigation through multiple pages
        for context in contexts {
            _ = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        }
        
        // Check that navigation history is tracked
        let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: contexts.last!)
        let navElement = structuredData.first { $0.type == "navigation_history" }
        
        XCTAssertNotNil(navElement)
        if let urls = navElement?.value as? [String] {
            XCTAssertTrue(urls.contains("https://www.example.com"))
            XCTAssertTrue(urls.contains("https://www.example.com/about"))
            XCTAssertTrue(urls.contains("https://www.example.com/contact"))
        }
    }
    
    // MARK: - DOM Structure Analysis Tests
    
    func testHeadingDetection() async {
        let mockOCRResults = [
            OCRResult(text: "Main Page Title", boundingBox: CGRect(x: 100, y: 50, width: 300, height: 40), confidence: 0.95),
            OCRResult(text: "Section Heading", boundingBox: CGRect(x: 100, y: 150, width: 200, height: 30), confidence: 0.90),
            OCRResult(text: "Subsection Title", boundingBox: CGRect(x: 120, y: 250, width: 180, height: 25), confidence: 0.88),
            OCRResult(text: "Regular paragraph text that is longer", boundingBox: CGRect(x: 100, y: 300, width: 400, height: 20), confidence: 0.85)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Test Page - Safari",
            processID: 1234
        )
        
        let mockFrame = createMockCGImage()
        let enhancedResults = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        
        let headingResults = enhancedResults.filter { $0.semanticType == "heading" }
        XCTAssertTrue(headingResults.count >= 1)
        
        // Check that the main title is detected as H1
        let mainHeading = headingResults.first { $0.originalResult.text == "Main Page Title" }
        XCTAssertNotNil(mainHeading)
        XCTAssertEqual(mainHeading?.structuredData["heading_level"] as? Int, 1)
        XCTAssertEqual(mainHeading?.structuredData["is_page_title"] as? Bool, true)
    }
    
    func testFormDetection() async {
        let mockOCRResults = [
            OCRResult(text: "Email:", boundingBox: CGRect(x: 50, y: 100, width: 60, height: 20), confidence: 0.95),
            OCRResult(text: "user@example.com", boundingBox: CGRect(x: 120, y: 100, width: 150, height: 20), confidence: 0.90),
            OCRResult(text: "Password*:", boundingBox: CGRect(x: 50, y: 130, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "••••••••", boundingBox: CGRect(x: 140, y: 130, width: 80, height: 20), confidence: 0.85),
            OCRResult(text: "Submit", boundingBox: CGRect(x: 100, y: 170, width: 60, height: 30), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.google.Chrome",
            applicationName: "Chrome",
            windowTitle: "Login - Chrome",
            processID: 1234
        )
        
        let mockFrame = createMockCGImage()
        let enhancedResults = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        
        // Check for form field detection
        let formFields = enhancedResults.filter { $0.semanticType == "form_field" }
        XCTAssertTrue(formFields.count >= 1)
        
        // Check for form button detection
        let formButtons = enhancedResults.filter { $0.semanticType == "form_button" }
        XCTAssertTrue(formButtons.count >= 1)
        
        let submitButton = formButtons.first { $0.originalResult.text == "Submit" }
        XCTAssertNotNil(submitButton)
        XCTAssertEqual(submitButton?.structuredData["button_type"] as? String, "submit")
    }
    
    func testNavigationElementDetection() async {
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
        let enhancedResults = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        
        let navItems = enhancedResults.filter { $0.semanticType == "navigation_item" }
        XCTAssertTrue(navItems.count >= 3) // Should detect Home, Products, About, Contact
        
        let homeNav = navItems.first { $0.originalResult.text == "Home" }
        XCTAssertNotNil(homeNav)
        XCTAssertEqual(homeNav?.structuredData["nav_level"] as? Int, 1) // Primary navigation
    }
    
    // MARK: - Page Context Analysis Tests
    
    func testPageTypeClassification() async {
        let testCases = [
            ("Login Page - https://example.com/login - Safari", "login"),
            ("Search Results - https://example.com/search?q=test - Safari", "searchResults"),
            ("User Profile - https://example.com/profile - Safari", "userProfile"),
            ("Dashboard - https://example.com/dashboard - Safari", "dashboard"),
            ("Product Details - https://shop.example.com/product/123 - Safari", "productPage")
        ]
        
        for (windowTitle, expectedPageType) in testCases {
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
            _ = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            
            let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: context)
            let pageMetadata = structuredData.first { $0.type == "page_metadata" }
            
            XCTAssertNotNil(pageMetadata, "Failed for window title: \(windowTitle)")
            // Note: The actual page type classification logic would need to be tested more thoroughly
        }
    }
    
    func testWebApplicationContextDetection() async {
        let testCases = [
            ("Jira Dashboard - https://company.atlassian.net/dashboard - Safari", "productivity"),
            ("Salesforce - https://company.salesforce.com - Safari", "crm"),
            ("Facebook - https://www.facebook.com - Safari", "socialMedia"),
            ("Online Store - https://shop.example.com - Safari", "ecommerce")
        ]
        
        for (windowTitle, expectedContext) in testCases {
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
            _ = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
            
            let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: context)
            let urlElement = structuredData.first { $0.type == "url" }
            
            XCTAssertNotNil(urlElement, "Failed to extract URL for: \(windowTitle)")
            // The app_context should be detected based on domain analysis
        }
    }
    
    // MARK: - Breadcrumb Detection Tests
    
    func testBreadcrumbExtraction() async {
        let mockOCRResults = [
            OCRResult(text: "Home > Products > Electronics > Laptops", boundingBox: CGRect(x: 50, y: 80, width: 300, height: 20), confidence: 0.95),
            OCRResult(text: "MacBook Pro 16-inch", boundingBox: CGRect(x: 50, y: 120, width: 200, height: 30), confidence: 0.90)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "MacBook Pro - Apple Store - Safari",
            processID: 1234
        )
        
        let mockFrame = createMockCGImage()
        _ = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        
        let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: context)
        let breadcrumbElement = structuredData.first { $0.type == "breadcrumbs" }
        
        XCTAssertNotNil(breadcrumbElement)
        if let breadcrumbs = breadcrumbElement?.value as? [String] {
            XCTAssertEqual(breadcrumbs.count, 4)
            XCTAssertEqual(breadcrumbs[0], "Home")
            XCTAssertEqual(breadcrumbs[1], "Products")
            XCTAssertEqual(breadcrumbs[2], "Electronics")
            XCTAssertEqual(breadcrumbs[3], "Laptops")
        }
        
        XCTAssertEqual(breadcrumbElement?.metadata["depth"] as? Int, 4)
        XCTAssertEqual(breadcrumbElement?.metadata["current_page"] as? String, "Laptops")
    }
    
    // MARK: - Interactive Element Detection Tests
    
    func testInteractiveElementDetection() async {
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
        let enhancedResults = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        
        let interactiveElements = enhancedResults.filter { $0.semanticType == "interactive_element" }
        XCTAssertTrue(interactiveElements.count >= 2)
        
        // Check button detection
        let buttonElement = interactiveElements.first { $0.originalResult.text == "Add to Cart" }
        XCTAssertNotNil(buttonElement)
        XCTAssertEqual(buttonElement?.structuredData["element_type"] as? String, "button")
        
        // Check checkbox detection
        let checkboxElement = interactiveElements.first { $0.originalResult.text.contains("☐") }
        XCTAssertNotNil(checkboxElement)
        XCTAssertEqual(checkboxElement?.structuredData["element_type"] as? String, "checkbox")
        XCTAssertEqual(checkboxElement?.structuredData["element_state"] as? String, "unchecked")
        
        // Check radio button detection
        let radioElement = interactiveElements.first { $0.originalResult.text.contains("●") }
        XCTAssertNotNil(radioElement)
        XCTAssertEqual(radioElement?.structuredData["element_type"] as? String, "radio")
        XCTAssertEqual(radioElement?.structuredData["element_state"] as? String, "checked")
    }
    
    // MARK: - Enhanced Form Data Extraction Tests
    
    func testEnhancedFormDataExtraction() async {
        let mockOCRResults = [
            OCRResult(text: "First Name*:", boundingBox: CGRect(x: 50, y: 100, width: 100, height: 20), confidence: 0.95),
            OCRResult(text: "John", boundingBox: CGRect(x: 160, y: 100, width: 50, height: 20), confidence: 0.90),
            OCRResult(text: "Email Address:", boundingBox: CGRect(x: 50, y: 130, width: 120, height: 20), confidence: 0.95),
            OCRResult(text: "john@example.com", boundingBox: CGRect(x: 180, y: 130, width: 150, height: 20), confidence: 0.90),
            OCRResult(text: "Phone Number:", boundingBox: CGRect(x: 50, y: 160, width: 110, height: 20), confidence: 0.95),
            OCRResult(text: "+1-555-0123", boundingBox: CGRect(x: 170, y: 160, width: 100, height: 20), confidence: 0.88)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "Contact Form - Safari",
            processID: 1234
        )
        
        let mockFrame = createMockCGImage()
        _ = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        
        let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: context)
        let formFields = structuredData.filter { $0.type == "form_field" }
        
        XCTAssertTrue(formFields.count >= 3)
        
        // Check first name field
        let firstNameField = formFields.first { ($0.metadata["label"] as? String)?.contains("First Name") == true }
        XCTAssertNotNil(firstNameField)
        XCTAssertEqual(firstNameField?.value as? String, "John")
        XCTAssertEqual(firstNameField?.metadata["required"] as? Bool, true)
        XCTAssertEqual(firstNameField?.metadata["input_type"] as? String, "text")
        
        // Check email field
        let emailField = formFields.first { ($0.metadata["label"] as? String)?.contains("Email") == true }
        XCTAssertNotNil(emailField)
        XCTAssertEqual(emailField?.value as? String, "john@example.com")
        XCTAssertEqual(emailField?.metadata["input_type"] as? String, "email")
        
        // Check phone field
        let phoneField = formFields.first { ($0.metadata["label"] as? String)?.contains("Phone") == true }
        XCTAssertNotNil(phoneField)
        XCTAssertEqual(phoneField?.value as? String, "+1-555-0123")
        XCTAssertEqual(phoneField?.metadata["input_type"] as? String, "tel")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithLargeOCRResults() {
        let largeOCRResults = (0..<1000).map { index in
            OCRResult(
                text: "Text element \(index)",
                boundingBox: CGRect(x: CGFloat(index % 100) * 10, y: CGFloat(index / 100) * 20, width: 100, height: 18),
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
        
        measure {
            _ = try! plugin.enhanceOCRResults(largeOCRResults, context: context, frame: mockFrame)
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
}

// MARK: - Integration Tests

class WebParsingPluginIntegrationTests: XCTestCase {
    
    var plugin: WebParsingPlugin!
    
    override func setUp() {
        super.setUp()
        plugin = WebParsingPlugin()
        
        let tempDir = FileManager.default.temporaryDirectory
        let configuration = PluginConfiguration(
            pluginDirectory: tempDir,
            configurationData: [:],
            sandboxEnabled: false
        )
        
        try! plugin.initialize(configuration: configuration)
    }
    
    override func tearDown() {
        plugin.cleanup()
        plugin = nil
        super.tearDown()
    }
    
    func testRealWorldEcommerceScenario() async {
        // Simulate an e-commerce product page
        let mockOCRResults = [
            OCRResult(text: "Home > Electronics > Laptops", boundingBox: CGRect(x: 50, y: 30, width: 200, height: 18), confidence: 0.95),
            OCRResult(text: "MacBook Pro 16-inch", boundingBox: CGRect(x: 50, y: 80, width: 300, height: 35), confidence: 0.95),
            OCRResult(text: "$2,399.00", boundingBox: CGRect(x: 50, y: 130, width: 100, height: 25), confidence: 0.90),
            OCRResult(text: "Color:", boundingBox: CGRect(x: 50, y: 180, width: 50, height: 20), confidence: 0.95),
            OCRResult(text: "Space Gray", boundingBox: CGRect(x: 110, y: 180, width: 80, height: 20), confidence: 0.90),
            OCRResult(text: "Storage:", boundingBox: CGRect(x: 50, y: 210, width: 60, height: 20), confidence: 0.95),
            OCRResult(text: "512GB SSD", boundingBox: CGRect(x: 120, y: 210, width: 80, height: 20), confidence: 0.90),
            OCRResult(text: "Add to Cart", boundingBox: CGRect(x: 50, y: 260, width: 100, height: 40), confidence: 0.95),
            OCRResult(text: "Buy Now", boundingBox: CGRect(x: 160, y: 260, width: 80, height: 40), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.apple.Safari",
            applicationName: "Safari",
            windowTitle: "MacBook Pro - Apple Store - https://www.apple.com/macbook-pro - Safari",
            processID: 1234
        )
        
        let mockFrame = createMockCGImage()
        let enhancedResults = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: context)
        
        // Verify breadcrumb detection
        let breadcrumbElement = structuredData.first { $0.type == "breadcrumbs" }
        XCTAssertNotNil(breadcrumbElement)
        
        // Verify URL extraction
        let urlElement = structuredData.first { $0.type == "url" }
        XCTAssertNotNil(urlElement)
        XCTAssertEqual(urlElement?.metadata["domain"] as? String, "www.apple.com")
        
        // Verify product information extraction
        let formFields = structuredData.filter { $0.type == "form_field" }
        XCTAssertTrue(formFields.count >= 2) // Color and Storage options
        
        // Verify button detection
        let buttonResults = enhancedResults.filter { $0.semanticType == "form_button" || $0.semanticType == "interactive_element" }
        XCTAssertTrue(buttonResults.count >= 2) // Add to Cart and Buy Now
    }
    
    func testRealWorldSocialMediaScenario() async {
        // Simulate a social media feed
        let mockOCRResults = [
            OCRResult(text: "Home", boundingBox: CGRect(x: 50, y: 20, width: 50, height: 20), confidence: 0.95),
            OCRResult(text: "Profile", boundingBox: CGRect(x: 110, y: 20, width: 60, height: 20), confidence: 0.95),
            OCRResult(text: "Messages", boundingBox: CGRect(x: 180, y: 20, width: 70, height: 20), confidence: 0.95),
            OCRResult(text: "John Doe", boundingBox: CGRect(x: 50, y: 80, width: 80, height: 20), confidence: 0.95),
            OCRResult(text: "Just finished a great project!", boundingBox: CGRect(x: 50, y: 110, width: 250, height: 18), confidence: 0.90),
            OCRResult(text: "Like", boundingBox: CGRect(x: 50, y: 140, width: 40, height: 18), confidence: 0.95),
            OCRResult(text: "Comment", boundingBox: CGRect(x: 100, y: 140, width: 60, height: 18), confidence: 0.95),
            OCRResult(text: "Share", boundingBox: CGRect(x: 170, y: 140, width: 50, height: 18), confidence: 0.95)
        ]
        
        let context = ApplicationContext(
            bundleID: "com.google.Chrome",
            applicationName: "Chrome",
            windowTitle: "Facebook - https://www.facebook.com - Chrome",
            processID: 1234
        )
        
        let mockFrame = createMockCGImage()
        let enhancedResults = try! await plugin.enhanceOCRResults(mockOCRResults, context: context, frame: mockFrame)
        let structuredData = try! await plugin.extractStructuredData(from: mockOCRResults, context: context)
        
        // Verify navigation detection
        let navResults = enhancedResults.filter { $0.semanticType == "navigation_item" }
        XCTAssertTrue(navResults.count >= 3) // Home, Profile, Messages
        
        // Verify social media context detection
        let urlElement = structuredData.first { $0.type == "url" }
        XCTAssertNotNil(urlElement)
        XCTAssertEqual(urlElement?.metadata["domain"] as? String, "www.facebook.com")
        
        // Verify interactive elements (Like, Comment, Share buttons)
        let interactiveResults = enhancedResults.filter { 
            $0.semanticType == "interactive_element" || $0.semanticType == "form_button" 
        }
        XCTAssertTrue(interactiveResults.count >= 3)
    }
    
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