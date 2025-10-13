import Foundation
import CoreGraphics
import Vision
import os.log

/// Plugin for parsing web applications and browser content with DOM structure analysis
public class WebParsingPlugin: BaseParsingPlugin {
    
    // MARK: - Properties
    
    private var urlHistory: [URLHistoryEntry] = []
    private var domStructureCache: [String: DOMStructure] = [:]
    private var pageContextCache: [String: PageContext] = [:]
    
    public init() {
        super.init(
            identifier: "com.alwayson.plugins.web",
            name: "Web Application Parser",
            version: "2.0.0",
            description: "Enhanced parsing for web applications and browser content with DOM analysis and navigation tracking",
            supportedApplications: [
                "com.apple.Safari",
                "com.google.Chrome",
                "com.mozilla.firefox",
                "com.microsoft.edgemac",
                "com.operasoftware.Opera",
                "com.brave.Browser",
                "com.vivaldi.Vivaldi"
            ]
        )
    }
    
    // MARK: - Data Structures
    
    private struct URLHistoryEntry {
        let url: String
        let timestamp: Date
        let pageTitle: String?
        let domain: String
        let navigationType: NavigationType
        
        enum NavigationType {
            case direct, back, forward, refresh, newTab, sameTab
        }
    }
    
    private struct DOMStructure {
        let pageTitle: String?
        let headings: [Heading]
        let forms: [WebForm]
        let navigation: [NavigationElement]
        let contentSections: [ContentSection]
        let interactiveElements: [InteractiveElement]
        
        struct Heading {
            let text: String
            let level: Int // 1-6 for h1-h6
            let boundingBox: CGRect
        }
        
        struct WebForm {
            let id: String
            let action: String?
            let method: String?
            let fields: [FormField]
            let submitButtons: [FormButton]
        }
        
        struct FormField {
            let name: String?
            let type: String
            let label: String?
            let value: String?
            let placeholder: String?
            let required: Bool
            let boundingBox: CGRect
        }
        
        struct FormButton {
            let text: String
            let type: String // submit, button, reset
            let boundingBox: CGRect
        }
        
        struct NavigationElement {
            let text: String
            let href: String?
            let level: Int
            let isActive: Bool
            let boundingBox: CGRect
        }
        
        struct ContentSection {
            let type: String // article, aside, section, main
            let heading: String?
            let content: [String]
            let boundingBox: CGRect
        }
        
        struct InteractiveElement {
            let type: String // button, link, dropdown, tab
            let text: String
            let state: String? // active, disabled, selected
            let boundingBox: CGRect
        }
    }
    
    private struct PageContext {
        let url: String
        let domain: String
        let pageType: PageType
        let applicationContext: WebApplicationContext?
        let breadcrumbs: [String]
        let metadata: [String: Any]
        
        enum PageType {
            case homepage, productPage, searchResults, userProfile, dashboard
            case form, article, listing, checkout, login, error
            case spa(route: String) // Single Page Application
        }
        
        enum WebApplicationContext {
            case ecommerce(category: String?)
            case socialMedia(platform: String)
            case productivity(tool: String)
            case documentation(framework: String?)
            case cms(system: String?)
            case crm(system: String?)
        }
    }
    
    // MARK: - Web-Specific Parsing
    
    public override func enhanceOCRResults(
        _ results: [OCRResult],
        context: ApplicationContext,
        frame: CGImage
    ) async throws -> [EnhancedOCRResult] {
        var enhancedResults = try await super.enhanceOCRResults(results, context: context, frame: frame)
        
        // Track URL and page navigation
        await trackPageNavigation(context: context, results: results)
        
        // Analyze DOM structure from OCR results
        let domStructure = analyzeDOMStructure(from: results, context: context)
        let pageContext = analyzePageContext(from: results, context: context, domStructure: domStructure)
        
        // Cache structures for future reference
        let cacheKey = generateCacheKey(context: context)
        domStructureCache[cacheKey] = domStructure
        pageContextCache[cacheKey] = pageContext
        
        // Detect web-specific elements with enhanced context
        enhancedResults.append(contentsOf: detectWebElements(in: results, domStructure: domStructure, pageContext: pageContext))
        enhancedResults.append(contentsOf: detectFormElements(in: results, domStructure: domStructure))
        enhancedResults.append(contentsOf: detectNavigationElements(in: results, domStructure: domStructure))
        enhancedResults.append(contentsOf: detectContentStructure(in: results, domStructure: domStructure))
        enhancedResults.append(contentsOf: detectInteractiveElements(in: results, domStructure: domStructure))
        
        return enhancedResults
    }
    
    public override func extractStructuredData(
        from results: [OCRResult],
        context: ApplicationContext
    ) async throws -> [StructuredDataElement] {
        var structuredData = try await super.extractStructuredData(from: results, context: context)
        
        let cacheKey = generateCacheKey(context: context)
        let domStructure = domStructureCache[cacheKey]
        let pageContext = pageContextCache[cacheKey]
        
        // Extract URL and navigation data
        structuredData.append(contentsOf: extractURLData(from: context, pageContext: pageContext))
        
        // Extract DOM structure data
        if let dom = domStructure {
            structuredData.append(contentsOf: extractDOMStructureData(from: dom))
        }
        
        // Extract enhanced form data with DOM context
        structuredData.append(contentsOf: extractEnhancedFormData(from: results, domStructure: domStructure))
        
        // Extract table data with web context
        structuredData.append(contentsOf: extractWebTableData(from: results, pageContext: pageContext))
        
        // Extract page metadata
        if let pageCtx = pageContext {
            structuredData.append(contentsOf: extractPageMetadata(from: pageCtx))
        }
        
        // Extract breadcrumb navigation
        structuredData.append(contentsOf: extractBreadcrumbData(from: results))
        
        return structuredData
    }
    
    public override func detectUIElements(
        in frame: CGImage,
        context: ApplicationContext
    ) async throws -> [UIElement] {
        let elements = try await super.detectUIElements(in: frame, context: context)
        
        // This would involve more sophisticated image processing
        // For now, we'll detect based on OCR patterns
        
        return elements
    }
    
    // MARK: - URL Tracking and Navigation
    
    private func trackPageNavigation(context: ApplicationContext, results: [OCRResult]) async {
        guard let currentURL = extractURLFromContext(context) else { return }
        
        let domain = extractDomain(from: currentURL)
        let pageTitle = extractPageTitle(from: results)
        let navigationType = determineNavigationType(currentURL: currentURL, context: context)
        
        let entry = URLHistoryEntry(
            url: currentURL,
            timestamp: Date(),
            pageTitle: pageTitle,
            domain: domain,
            navigationType: navigationType
        )
        
        urlHistory.append(entry)
        
        // Keep only last 100 entries to prevent memory bloat
        if urlHistory.count > 100 {
            urlHistory.removeFirst(urlHistory.count - 100)
        }
    }
    
    private func determineNavigationType(currentURL: String, context: ApplicationContext) -> URLHistoryEntry.NavigationType {
        guard let lastEntry = urlHistory.last else { return .direct }
        
        let currentDomain = extractDomain(from: currentURL)
        let lastDomain = lastEntry.domain
        
        // Check for back/forward navigation patterns
        if urlHistory.count >= 2 {
            let secondLastEntry = urlHistory[urlHistory.count - 2]
            if currentURL == secondLastEntry.url {
                return .back
            }
        }
        
        // Check for same tab vs new tab (would need additional context)
        if currentDomain == lastDomain {
            return .sameTab
        } else {
            return .newTab
        }
    }
    
    // MARK: - DOM Structure Analysis
    
    private func analyzeDOMStructure(from results: [OCRResult], context: ApplicationContext) -> DOMStructure {
        let headings = extractHeadings(from: results)
        let forms = extractWebForms(from: results)
        let navigation = extractNavigationStructure(from: results)
        let contentSections = extractContentSections(from: results)
        let interactiveElements = extractInteractiveElements(from: results)
        let pageTitle = extractPageTitle(from: results)
        
        return DOMStructure(
            pageTitle: pageTitle,
            headings: headings,
            forms: forms,
            navigation: navigation,
            contentSections: contentSections,
            interactiveElements: interactiveElements
        )
    }
    
    private func extractHeadings(from results: [OCRResult]) -> [DOMStructure.Heading] {
        var headings: [DOMStructure.Heading] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect headings based on text characteristics and position
            if let level = determineHeadingLevel(text: text, bounds: result.boundingBox, allResults: results) {
                headings.append(DOMStructure.Heading(
                    text: text,
                    level: level,
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return headings.sorted { $0.boundingBox.origin.y < $1.boundingBox.origin.y }
    }
    
    private func determineHeadingLevel(text: String, bounds: CGRect, allResults: [OCRResult]) -> Int? {
        // Skip very short or very long text
        guard text.count >= 3 && text.count <= 100 else { return nil }
        
        // Skip text that looks like form fields or buttons
        if isFormLabel(text) || isFormButton(text) { return nil }
        
        // Determine level based on position and text characteristics
        let yPosition = bounds.origin.y
        let textLength = text.count
        
        // H1: Usually at top, shorter text
        if yPosition < 150 && textLength < 50 {
            return 1
        }
        
        // H2: Upper portion, medium length
        if yPosition < 300 && textLength < 80 {
            return 2
        }
        
        // H3-H6: Based on relative position and length
        if textLength < 60 {
            return min(6, max(3, Int(yPosition / 100) + 1))
        }
        
        return nil
    }
    
    private func extractWebForms(from results: [OCRResult]) -> [DOMStructure.WebForm] {
        var forms: [DOMStructure.WebForm] = []
        var currentForm: DOMStructure.WebForm?
        var formFields: [DOMStructure.FormField] = []
        var formButtons: [DOMStructure.FormButton] = []
        
        let sortedResults = results.sorted { $0.boundingBox.origin.y < $1.boundingBox.origin.y }
        
        for result in sortedResults {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isFormLabel(text) {
                // Extract field information
                let fieldType = inferInputType(from: text)
                let isRequired = isRequiredField(text)
                let cleanLabel = text.trimmingCharacters(in: CharacterSet(charactersIn: ":*"))
                
                // Look for associated value
                let value = findAssociatedFieldValue(for: result, in: results)
                
                let field = DOMStructure.FormField(
                    name: cleanLabel.lowercased().replacingOccurrences(of: " ", with: "_"),
                    type: fieldType,
                    label: cleanLabel,
                    value: value?.text,
                    placeholder: nil,
                    required: isRequired,
                    boundingBox: result.boundingBox
                )
                
                formFields.append(field)
            } else if isFormButton(text) {
                let buttonType = classifyButtonType(text)
                let button = DOMStructure.FormButton(
                    text: text,
                    type: buttonType,
                    boundingBox: result.boundingBox
                )
                formButtons.append(button)
            }
        }
        
        // Group fields and buttons into forms
        if !formFields.isEmpty || !formButtons.isEmpty {
            let form = DOMStructure.WebForm(
                id: "form_\(UUID().uuidString)",
                action: nil,
                method: nil,
                fields: formFields,
                submitButtons: formButtons
            )
            forms.append(form)
        }
        
        return forms
    }
    
    private func findAssociatedFieldValue(for label: OCRResult, in results: [OCRResult]) -> OCRResult? {
        let labelCenter = CGPoint(x: label.boundingBox.midX, y: label.boundingBox.midY)
        let searchRadius: CGFloat = 200
        
        return results
            .filter { result in
                let distance = sqrt(
                    pow(result.boundingBox.midX - labelCenter.x, 2) +
                    pow(result.boundingBox.midY - labelCenter.y, 2)
                )
                return distance <= searchRadius && 
                       !isFormLabel(result.text) && 
                       !isFormButton(result.text) &&
                       isFieldValue(result.text)
            }
            .min { a, b in
                let distanceA = sqrt(
                    pow(a.boundingBox.midX - labelCenter.x, 2) +
                    pow(a.boundingBox.midY - labelCenter.y, 2)
                )
                let distanceB = sqrt(
                    pow(b.boundingBox.midX - labelCenter.x, 2) +
                    pow(b.boundingBox.midY - labelCenter.y, 2)
                )
                return distanceA < distanceB
            }
    }
    
    private func extractNavigationStructure(from results: [OCRResult]) -> [DOMStructure.NavigationElement] {
        var navElements: [DOMStructure.NavigationElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isNavigationItem(text) {
                let level = determineNavigationLevel(result.boundingBox)
                let isActive = isActiveNavigationItem(text)
                
                let navElement = DOMStructure.NavigationElement(
                    text: text,
                    href: nil, // Would need additional context to determine
                    level: level,
                    isActive: isActive,
                    boundingBox: result.boundingBox
                )
                navElements.append(navElement)
            }
        }
        
        return navElements.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
    }
    
    private func extractContentSections(from results: [OCRResult]) -> [DOMStructure.ContentSection] {
        var sections: [DOMStructure.ContentSection] = []
        
        // Group results by vertical regions to identify content sections
        let sortedResults = results.sorted { $0.boundingBox.origin.y < $1.boundingBox.origin.y }
        var currentSection: [OCRResult] = []
        var lastY: CGFloat = 0
        
        for result in sortedResults {
            let currentY = result.boundingBox.origin.y
            
            // Start new section if there's a significant gap
            if currentY - lastY > 50 && !currentSection.isEmpty {
                if let section = createContentSection(from: currentSection) {
                    sections.append(section)
                }
                currentSection = []
            }
            
            currentSection.append(result)
            lastY = currentY + result.boundingBox.height
        }
        
        // Add final section
        if !currentSection.isEmpty, let section = createContentSection(from: currentSection) {
            sections.append(section)
        }
        
        return sections
    }
    
    private func createContentSection(from results: [OCRResult]) -> DOMStructure.ContentSection? {
        guard !results.isEmpty else { return nil }
        
        let heading = results.first { result in
            determineHeadingLevel(text: result.text, bounds: result.boundingBox, allResults: results) != nil
        }?.text
        
        let content = results
            .filter { !isFormLabel($0.text) && !isFormButton($0.text) }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let boundingBox = results.reduce(results[0].boundingBox) { $0.union($1.boundingBox) }
        
        return DOMStructure.ContentSection(
            type: "section",
            heading: heading,
            content: content,
            boundingBox: boundingBox
        )
    }
    
    private func extractInteractiveElements(from results: [OCRResult]) -> [DOMStructure.InteractiveElement] {
        var elements: [DOMStructure.InteractiveElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let elementType = classifyInteractiveElement(text) {
                let state = determineElementState(text)
                
                let element = DOMStructure.InteractiveElement(
                    type: elementType,
                    text: text,
                    state: state,
                    boundingBox: result.boundingBox
                )
                elements.append(element)
            }
        }
        
        return elements
    }
    
    private func classifyInteractiveElement(_ text: String) -> String? {
        let lowercased = text.lowercased()
        
        if isFormButton(text) {
            return "button"
        } else if isLinkText(text) {
            return "link"
        } else if lowercased.contains("dropdown") || lowercased.contains("select") {
            return "dropdown"
        } else if lowercased.contains("tab") && text.count < 20 {
            return "tab"
        } else if lowercased.contains("checkbox") || text == "☐" || text == "☑" {
            return "checkbox"
        } else if lowercased.contains("radio") || text == "○" || text == "●" {
            return "radio"
        }
        
        return nil
    }
    
    private func determineElementState(_ text: String) -> String? {
        let lowercased = text.lowercased()
        
        if lowercased.contains("active") || lowercased.contains("selected") {
            return "active"
        } else if lowercased.contains("disabled") {
            return "disabled"
        } else if text == "☑" || text == "●" {
            return "checked"
        } else if text == "☐" || text == "○" {
            return "unchecked"
        }
        
        return nil
    }
    
    // MARK: - Page Context Analysis
    
    private func analyzePageContext(from results: [OCRResult], context: ApplicationContext, domStructure: DOMStructure) -> PageContext {
        guard let url = extractURLFromContext(context) else {
            return PageContext(
                url: "",
                domain: "",
                pageType: .homepage,
                applicationContext: nil,
                breadcrumbs: [],
                metadata: [:]
            )
        }
        
        let domain = extractDomain(from: url)
        let pageType = classifyPageType(url: url, domStructure: domStructure, results: results)
        let appContext = classifyWebApplication(domain: domain, url: url, domStructure: domStructure)
        let breadcrumbs = extractBreadcrumbs(from: results)
        let metadata = extractPageMetadataDict(from: results, context: context)
        
        return PageContext(
            url: url,
            domain: domain,
            pageType: pageType,
            applicationContext: appContext,
            breadcrumbs: breadcrumbs,
            metadata: metadata
        )
    }
    
    private func classifyPageType(url: String, domStructure: DOMStructure, results: [OCRResult]) -> PageContext.PageType {
        let lowercasedURL = url.lowercased()
        let hasForm = !domStructure.forms.isEmpty
        
        // Check URL patterns
        if lowercasedURL.contains("/login") || lowercasedURL.contains("/signin") {
            return .login
        } else if lowercasedURL.contains("/search") || lowercasedURL.contains("?q=") {
            return .searchResults
        } else if lowercasedURL.contains("/profile") || lowercasedURL.contains("/account") {
            return .userProfile
        } else if lowercasedURL.contains("/dashboard") {
            return .dashboard
        } else if lowercasedURL.contains("/checkout") || lowercasedURL.contains("/cart") {
            return .checkout
        } else if lowercasedURL.contains("/product/") || lowercasedURL.contains("/item/") {
            return .productPage
        } else if lowercasedURL.contains("/error") || lowercasedURL.contains("/404") {
            return .error
        }
        
        // Check content patterns
        if hasForm {
            return .form
        }
        
        // Check for SPA patterns
        if lowercasedURL.contains("#/") || lowercasedURL.contains("#!/") {
            let route = extractSPARoute(from: url)
            return .spa(route: route)
        }
        
        // Default classification based on content
        let textContent = results.map { $0.text }.joined(separator: " ").lowercased()
        
        if textContent.contains("article") || textContent.contains("blog") {
            return .article
        } else if textContent.contains("list") || textContent.contains("catalog") {
            return .listing
        }
        
        return .homepage
    }
    
    private func extractSPARoute(from url: String) -> String {
        if let range = url.range(of: "#/") {
            return String(url[range.upperBound...])
        } else if let range = url.range(of: "#!/") {
            return String(url[range.upperBound...])
        }
        return ""
    }
    
    private func classifyWebApplication(domain: String, url: String, domStructure: DOMStructure) -> PageContext.WebApplicationContext? {
        let lowercasedDomain = domain.lowercased()
        let lowercasedURL = url.lowercased()
        
        // E-commerce platforms
        if lowercasedDomain.contains("shop") || lowercasedDomain.contains("store") || 
           lowercasedURL.contains("/product") || lowercasedURL.contains("/cart") {
            return .ecommerce(category: extractEcommerceCategory(from: url))
        }
        
        // Social media platforms
        if ["facebook.com", "twitter.com", "linkedin.com", "instagram.com"].contains(where: { lowercasedDomain.contains($0) }) {
            return .socialMedia(platform: extractSocialPlatform(from: domain))
        }
        
        // Productivity tools
        if ["jira", "confluence", "trello", "asana", "notion"].contains(where: { lowercasedDomain.contains($0) }) {
            return .productivity(tool: extractProductivityTool(from: domain))
        }
        
        // CRM systems
        if ["salesforce", "hubspot", "pipedrive"].contains(where: { lowercasedDomain.contains($0) }) {
            return .crm(system: extractCRMSystem(from: domain))
        }
        
        // Documentation sites
        if lowercasedDomain.contains("docs") || lowercasedURL.contains("/docs/") {
            return .documentation(framework: extractDocumentationFramework(from: domain))
        }
        
        return nil
    }
    
    private func extractEcommerceCategory(from url: String) -> String? {
        let categories = ["electronics", "clothing", "books", "home", "sports", "beauty"]
        return categories.first { url.lowercased().contains($0) }
    }
    
    private func extractSocialPlatform(from domain: String) -> String {
        if domain.contains("facebook") { return "Facebook" }
        if domain.contains("twitter") { return "Twitter" }
        if domain.contains("linkedin") { return "LinkedIn" }
        if domain.contains("instagram") { return "Instagram" }
        return domain
    }
    
    private func extractProductivityTool(from domain: String) -> String {
        if domain.contains("jira") { return "Jira" }
        if domain.contains("confluence") { return "Confluence" }
        if domain.contains("trello") { return "Trello" }
        if domain.contains("asana") { return "Asana" }
        if domain.contains("notion") { return "Notion" }
        return domain
    }
    
    private func extractCRMSystem(from domain: String) -> String {
        if domain.contains("salesforce") { return "Salesforce" }
        if domain.contains("hubspot") { return "HubSpot" }
        if domain.contains("pipedrive") { return "Pipedrive" }
        return domain
    }
    
    private func extractDocumentationFramework(from domain: String) -> String? {
        let frameworks = ["react", "vue", "angular", "django", "rails", "laravel"]
        return frameworks.first { domain.lowercased().contains($0) }
    }
    
    private func extractBreadcrumbs(from results: [OCRResult]) -> [String] {
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if isBreadcrumb(text) {
                let separators = [">", "/", "›", "»", "→"]
                for separator in separators {
                    if text.contains(separator) {
                        return text.components(separatedBy: separator)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
                }
            }
        }
        return []
    }
    
    private func extractPageMetadataDict(from results: [OCRResult], context: ApplicationContext) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        metadata["timestamp"] = Date()
        metadata["windowTitle"] = context.windowTitle
        metadata["bundleID"] = context.bundleID
        
        // Extract page title
        if let pageTitle = extractPageTitle(from: results) {
            metadata["pageTitle"] = pageTitle
        }
        
        // Count different element types
        metadata["formCount"] = results.filter { isFormLabel($0.text) }.count
        metadata["buttonCount"] = results.filter { isFormButton($0.text) }.count
        metadata["linkCount"] = results.filter { isLinkText($0.text) }.count
        
        return metadata
    }
    
    private func extractPageTitle(from results: [OCRResult]) -> String? {
        // Look for text that appears to be a page title
        return results
            .filter { result in
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.count > 5 && text.count < 100 && 
                       result.boundingBox.origin.y < 200 &&
                       !isFormLabel(text) && !isFormButton(text)
            }
            .min { $0.boundingBox.origin.y < $1.boundingBox.origin.y }?
            .text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateCacheKey(context: ApplicationContext) -> String {
        return "\(context.bundleID)_\(context.windowTitle.hashValue)"
    }
    
    // MARK: - Web Element Detection
    
    private func detectWebElements(in results: [OCRResult], domStructure: DOMStructure, pageContext: PageContext) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect links with enhanced context
            if isLinkText(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "link",
                    structuredData: [
                        "link_type": determineLinkType(text),
                        "is_external": isExternalLink(text),
                        "page_context": pageContext.pageType,
                        "domain": pageContext.domain
                    ]
                ))
            }
            
            // Detect breadcrumbs
            if isBreadcrumb(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "breadcrumb",
                    structuredData: [
                        "level": extractBreadcrumbLevel(text)
                    ]
                ))
            }
            
            // Detect page titles with DOM context
            if let heading = domStructure.headings.first(where: { $0.boundingBox.intersects(result.boundingBox) }) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "heading",
                    structuredData: [
                        "heading_level": heading.level,
                        "is_page_title": heading.level == 1,
                        "page_type": pageContext.pageType
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectFormElements(in results: [OCRResult], domStructure: DOMStructure) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect form labels with DOM context
            if let field = domStructure.forms.flatMap({ $0.fields }).first(where: { $0.boundingBox.intersects(result.boundingBox) }) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "form_field",
                    structuredData: [
                        "field_name": field.name ?? "",
                        "field_type": field.type,
                        "required": field.required,
                        "has_value": field.value != nil,
                        "placeholder": field.placeholder ?? ""
                    ]
                ))
            } else if isFormLabel(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "form_label",
                    structuredData: [
                        "input_type": inferInputType(from: text),
                        "required": isRequiredField(text)
                    ]
                ))
            }
            
            // Detect form buttons
            if isFormButton(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "form_button",
                    structuredData: [
                        "button_type": classifyButtonType(text),
                        "is_primary": isPrimaryButton(text)
                    ]
                ))
            }
            
            // Detect validation messages
            if isValidationMessage(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "validation_message",
                    structuredData: [
                        "message_type": classifyValidationMessage(text),
                        "severity": determineMessageSeverity(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectNavigationElements(in results: [OCRResult], domStructure: DOMStructure) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect navigation menu items with DOM context
            if let navElement = domStructure.navigation.first(where: { $0.boundingBox.intersects(result.boundingBox) }) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "navigation_item",
                    structuredData: [
                        "nav_level": navElement.level,
                        "is_active": navElement.isActive,
                        "href": navElement.href ?? ""
                    ]
                ))
            } else if isNavigationItem(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "navigation_item",
                    structuredData: [
                        "nav_level": determineNavigationLevel(result.boundingBox),
                        "is_active": isActiveNavigationItem(text)
                    ]
                ))
            }
            
            // Detect pagination
            if isPaginationElement(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "pagination",
                    structuredData: [
                        "pagination_type": classifyPaginationType(text),
                        "page_number": extractPageNumber(text) as Any
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectContentStructure(in results: [OCRResult], domStructure: DOMStructure) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for section in domStructure.contentSections {
            // Find OCR results that fall within this content section
            let sectionResults = results.filter { result in
                section.boundingBox.intersects(result.boundingBox)
            }
            
            for result in sectionResults {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "content_section",
                    structuredData: [
                        "section_type": section.type,
                        "section_heading": section.heading ?? "",
                        "content_length": section.content.joined().count
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectInteractiveElements(in results: [OCRResult], domStructure: DOMStructure) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for element in domStructure.interactiveElements {
            if let result = results.first(where: { $0.boundingBox.intersects(element.boundingBox) }) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "interactive_element",
                    structuredData: [
                        "element_type": element.type,
                        "element_state": element.state ?? "",
                        "is_interactive": true
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Data Extraction
    
    // MARK: - Enhanced Data Extraction Methods
    
    private func extractURLData(from context: ApplicationContext, pageContext: PageContext?) -> [StructuredDataElement] {
        var elements: [StructuredDataElement] = []
        
        if let url = extractURLFromContext(context) {
            let urlElement = StructuredDataElement(
                id: "\(identifier)_url_\(UUID().uuidString)",
                type: "url",
                value: url,
                metadata: [
                    "domain": extractDomain(from: url),
                    "protocol": extractProtocol(from: url),
                    "page_type": pageContext?.pageType ?? "unknown",
                    "app_context": pageContext?.applicationContext ?? "unknown"
                ]
            )
            elements.append(urlElement)
        }
        
        // Add navigation history
        if urlHistory.count > 1 {
            let navigationElement = StructuredDataElement(
                id: "\(identifier)_navigation_\(UUID().uuidString)",
                type: "navigation_history",
                value: urlHistory.suffix(5).map { $0.url },
                metadata: [
                    "navigation_count": urlHistory.count,
                    "last_navigation_type": urlHistory.last?.navigationType ?? "unknown"
                ]
            )
            elements.append(navigationElement)
        }
        
        return elements
    }
    
    private func extractDOMStructureData(from domStructure: DOMStructure) -> [StructuredDataElement] {
        var elements: [StructuredDataElement] = []
        
        // Extract page structure summary
        let structureElement = StructuredDataElement(
            id: "\(identifier)_dom_structure_\(UUID().uuidString)",
            type: "dom_structure",
            value: [
                "headings": domStructure.headings.count,
                "forms": domStructure.forms.count,
                "navigation_items": domStructure.navigation.count,
                "content_sections": domStructure.contentSections.count,
                "interactive_elements": domStructure.interactiveElements.count
            ],
            metadata: [
                "page_title": domStructure.pageTitle ?? "",
                "has_forms": !domStructure.forms.isEmpty,
                "has_navigation": !domStructure.navigation.isEmpty
            ]
        )
        elements.append(structureElement)
        
        // Extract form structures
        for (index, form) in domStructure.forms.enumerated() {
            let formElement = StructuredDataElement(
                id: "\(identifier)_form_\(index)_\(UUID().uuidString)",
                type: "web_form",
                value: form.fields.map { ["name": $0.name ?? "", "type": $0.type, "required": $0.required] },
                metadata: [
                    "form_id": form.id,
                    "field_count": form.fields.count,
                    "submit_buttons": form.submitButtons.count,
                    "action": form.action ?? "",
                    "method": form.method ?? ""
                ]
            )
            elements.append(formElement)
        }
        
        return elements
    }
    
    private func extractEnhancedFormData(from results: [OCRResult], domStructure: DOMStructure?) -> [StructuredDataElement] {
        var elements: [StructuredDataElement] = []
        
        // Use DOM structure if available, otherwise fall back to OCR analysis
        if let dom = domStructure {
            for form in dom.forms {
                for field in form.fields {
                    let fieldElement = StructuredDataElement(
                        id: "\(identifier)_form_field_\(UUID().uuidString)",
                        type: "form_field",
                        value: field.value ?? "",
                        metadata: [
                            "field_name": field.name ?? "",
                            "field_type": field.type,
                            "label": field.label ?? "",
                            "required": field.required,
                            "placeholder": field.placeholder ?? ""
                        ],
                        boundingBox: field.boundingBox
                    )
                    elements.append(fieldElement)
                }
            }
        } else {
            // Fallback to original field pair extraction
            let fieldPairs = extractFieldPairs(from: results)
            elements = fieldPairs.compactMap { pair in
                guard let value = pair.value else { return nil }
                
                let labelText = pair.label.text.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n*"))
                let inputType = inferInputType(from: labelText)
                
                return StructuredDataElement(
                    id: "\(identifier)_form_field_\(UUID().uuidString)",
                    type: "form_field",
                    value: value.text,
                    metadata: [
                        "label": labelText,
                        "input_type": inputType,
                        "required": isRequiredField(pair.label.text),
                        "confidence": min(pair.label.confidence, value.confidence)
                    ],
                    boundingBox: pair.label.boundingBox.union(value.boundingBox)
                )
            }
        }
        
        return elements
    }
    
    private func extractWebTableData(from results: [OCRResult], pageContext: PageContext?) -> [StructuredDataElement] {
        let tableData = extractTableData(from: results)
        
        // Enhance table data with web context
        return tableData.map { element in
            var enhancedMetadata = element.metadata
            enhancedMetadata["page_type"] = pageContext?.pageType ?? "unknown"
            enhancedMetadata["domain"] = pageContext?.domain ?? ""
            
            return StructuredDataElement(
                id: element.id,
                type: element.type,
                value: element.value,
                metadata: enhancedMetadata,
                boundingBox: element.boundingBox
            )
        }
    }
    
    private func extractPageMetadata(from pageContext: PageContext) -> [StructuredDataElement] {
        let metadataElement = StructuredDataElement(
            id: "\(identifier)_page_metadata_\(UUID().uuidString)",
            type: "page_metadata",
            value: pageContext.metadata,
            metadata: [
                "url": pageContext.url,
                "domain": pageContext.domain,
                "page_type": pageContext.pageType,
                "app_context": pageContext.applicationContext ?? "unknown",
                "breadcrumb_count": pageContext.breadcrumbs.count
            ]
        )
        
        return [metadataElement]
    }
    
    private func extractBreadcrumbData(from results: [OCRResult]) -> [StructuredDataElement] {
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if isBreadcrumb(text) {
                let breadcrumbs = extractBreadcrumbs(from: results)
                if !breadcrumbs.isEmpty {
                    let breadcrumbElement = StructuredDataElement(
                        id: "\(identifier)_breadcrumbs_\(UUID().uuidString)",
                        type: "breadcrumbs",
                        value: breadcrumbs,
                        metadata: [
                            "depth": breadcrumbs.count,
                            "current_page": breadcrumbs.last ?? ""
                        ],
                        boundingBox: result.boundingBox
                    )
                    return [breadcrumbElement]
                }
            }
        }
        return []
    }
    
    private func extractTableData(from results: [OCRResult]) -> [StructuredDataElement] {
        // Detect table structures based on alignment and spacing
        let sortedResults = results.sorted { $0.boundingBox.origin.y < $1.boundingBox.origin.y }
        var tableData: [StructuredDataElement] = []
        
        // Group results by rows (similar Y coordinates)
        let rowGroups = groupResultsByRows(sortedResults)
        
        if rowGroups.count >= 2 { // At least header + one data row
            // First row is likely headers
            let headers = rowGroups[0].sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
            
            for (rowIndex, row) in rowGroups.dropFirst().enumerated() {
                let cells = row.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
                
                for (cellIndex, cell) in cells.enumerated() {
                    let header = cellIndex < headers.count ? headers[cellIndex].text : "Column \(cellIndex + 1)"
                    
                    let tableCell = StructuredDataElement(
                        id: "\(identifier)_table_cell_\(rowIndex)_\(cellIndex)",
                        type: "table_cell",
                        value: cell.text,
                        metadata: [
                            "row": rowIndex,
                            "column": cellIndex,
                            "header": header,
                            "confidence": cell.confidence
                        ],
                        boundingBox: cell.boundingBox
                    )
                    tableData.append(tableCell)
                }
            }
        }
        
        return tableData
    }
    
    // MARK: - Helper Methods
    
    private func extractURLFromContext(_ context: ApplicationContext) -> String? {
        // Extract URL from window title (common browser pattern)
        let title = context.windowTitle
        
        // Look for URL patterns in the title
        let urlPattern = #"https?://[^\s]+"#
        if let range = title.range(of: urlPattern, options: .regularExpression) {
            return String(title[range])
        }
        
        return nil
    }
    
    private func extractDomain(from url: String) -> String {
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host else {
            return ""
        }
        return host
    }
    
    private func extractProtocol(from url: String) -> String {
        guard let urlComponents = URLComponents(string: url),
              let scheme = urlComponents.scheme else {
            return ""
        }
        return scheme
    }
    
    private func isLinkText(_ text: String) -> Bool {
        // Common link patterns
        let linkPatterns = [
            "Click here", "Learn more", "Read more", "View details",
            "Download", "Sign up", "Log in", "Register"
        ]
        
        return linkPatterns.contains { text.localizedCaseInsensitiveContains($0) } ||
               text.hasPrefix("http") ||
               text.contains("www.")
    }
    
    private func determineLinkType(_ text: String) -> String {
        if text.hasPrefix("http") || text.contains("www.") {
            return "external"
        } else if text.localizedCaseInsensitiveContains("download") {
            return "download"
        } else if text.localizedCaseInsensitiveContains("sign up") || text.localizedCaseInsensitiveContains("register") {
            return "registration"
        } else if text.localizedCaseInsensitiveContains("log in") || text.localizedCaseInsensitiveContains("login") {
            return "authentication"
        }
        return "navigation"
    }
    
    private func isExternalLink(_ text: String) -> Bool {
        return text.hasPrefix("http") || text.contains("www.")
    }
    
    private func isBreadcrumb(_ text: String) -> Bool {
        return text.contains(">") || text.contains("/") || text.contains("›")
    }
    
    private func extractBreadcrumbLevel(_ text: String) -> Int {
        let separators = [">", "/", "›"]
        for separator in separators {
            if text.contains(separator) {
                return text.components(separatedBy: separator).count
            }
        }
        return 1
    }
    
    private func isPageTitle(_ text: String, _ bounds: CGRect) -> Bool {
        // Page titles are typically larger and near the top
        return text.count > 5 && text.count < 100 && bounds.origin.y < 200
    }
    
    private func isFormLabel(_ text: String) -> Bool {
        let formKeywords = ["Name", "Email", "Password", "Address", "Phone", "Username"]
        return formKeywords.contains { text.localizedCaseInsensitiveContains($0) } ||
               text.hasSuffix(":") ||
               text.hasSuffix("*")
    }
    
    private func inferInputType(from label: String) -> String {
        let lowercased = label.lowercased()
        
        if lowercased.contains("email") {
            return "email"
        } else if lowercased.contains("password") {
            return "password"
        } else if lowercased.contains("phone") || lowercased.contains("tel") {
            return "tel"
        } else if lowercased.contains("date") {
            return "date"
        } else if lowercased.contains("number") || lowercased.contains("amount") {
            return "number"
        }
        
        return "text"
    }
    
    private func isRequiredField(_ text: String) -> Bool {
        return text.contains("*") || text.localizedCaseInsensitiveContains("required")
    }
    
    private func isFormButton(_ text: String) -> Bool {
        let buttonKeywords = ["Submit", "Send", "Save", "Continue", "Next", "Previous", "Cancel", "Reset"]
        return buttonKeywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyButtonType(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("submit") || lowercased.contains("send") {
            return "submit"
        } else if lowercased.contains("cancel") || lowercased.contains("close") {
            return "cancel"
        } else if lowercased.contains("next") || lowercased.contains("continue") {
            return "navigation"
        } else if lowercased.contains("save") {
            return "save"
        }
        
        return "action"
    }
    
    private func isPrimaryButton(_ text: String) -> Bool {
        let primaryKeywords = ["Submit", "Send", "Save", "Continue", "Next", "Sign up", "Log in"]
        return primaryKeywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func isValidationMessage(_ text: String) -> Bool {
        let validationKeywords = ["error", "invalid", "required", "must", "cannot", "please"]
        return validationKeywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyValidationMessage(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("error") || lowercased.contains("invalid") {
            return "error"
        } else if lowercased.contains("required") || lowercased.contains("must") {
            return "required"
        } else if lowercased.contains("success") || lowercased.contains("saved") {
            return "success"
        }
        
        return "info"
    }
    
    private func determineMessageSeverity(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("error") || lowercased.contains("failed") {
            return "error"
        } else if lowercased.contains("warning") || lowercased.contains("caution") {
            return "warning"
        } else if lowercased.contains("success") {
            return "success"
        }
        
        return "info"
    }
    
    private func isNavigationItem(_ text: String) -> Bool {
        let navKeywords = ["Home", "About", "Contact", "Products", "Services", "Blog", "News"]
        return navKeywords.contains { text.localizedCaseInsensitiveContains($0) } ||
               (text.count < 20 && !text.contains(" "))
    }
    
    private func determineNavigationLevel(_ bounds: CGRect) -> Int {
        // Estimate navigation level based on Y position
        if bounds.origin.y < 100 {
            return 1 // Primary navigation
        } else if bounds.origin.y < 200 {
            return 2 // Secondary navigation
        }
        return 3 // Tertiary navigation
    }
    
    private func isActiveNavigationItem(_ text: String) -> Bool {
        // This would require more context, for now return false
        return false
    }
    
    private func isPaginationElement(_ text: String) -> Bool {
        return text.matches(#"\d+"#) || // Page numbers
               text.localizedCaseInsensitiveContains("next") ||
               text.localizedCaseInsensitiveContains("previous") ||
               text.localizedCaseInsensitiveContains("prev") ||
               text == "..." ||
               text == "«" || text == "»"
    }
    
    private func classifyPaginationType(_ text: String) -> String {
        if text.matches(#"\d+"#) {
            return "page_number"
        } else if text.localizedCaseInsensitiveContains("next") {
            return "next"
        } else if text.localizedCaseInsensitiveContains("prev") {
            return "previous"
        }
        return "navigation"
    }
    
    private func extractPageNumber(_ text: String) -> Int? {
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private func groupResultsByRows(_ results: [OCRResult]) -> [[OCRResult]] {
        var rows: [[OCRResult]] = []
        let tolerance: CGFloat = 10.0 // Y-coordinate tolerance for same row
        
        for result in results {
            var addedToRow = false
            
            for i in 0..<rows.count {
                if let firstInRow = rows[i].first {
                    if abs(result.boundingBox.origin.y - firstInRow.boundingBox.origin.y) <= tolerance {
                        rows[i].append(result)
                        addedToRow = true
                        break
                    }
                }
            }
            
            if !addedToRow {
                rows.append([result])
            }
        }
        
        return rows
    }
}

// MARK: - String Extension for Regex

private extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}