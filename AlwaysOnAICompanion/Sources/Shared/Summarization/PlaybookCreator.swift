import Foundation

/// Creates step-by-step action sequences (playbooks) from activity summaries
public class PlaybookCreator {
    
    /// Configuration for playbook generation
    public struct Configuration {
        /// Minimum number of events required for a playbook
        public let minEventsForPlaybook: Int
        /// Maximum number of steps to include in a playbook
        public let maxStepsInPlaybook: Int
        /// Include timing information in steps
        public let includeTiming: Bool
        /// Include confidence scores for steps
        public let includeConfidence: Bool
        /// Group similar consecutive actions
        public let groupSimilarActions: Bool
        
        public init(
            minEventsForPlaybook: Int = 3,
            maxStepsInPlaybook: Int = 50,
            includeTiming: Bool = true,
            includeConfidence: Bool = false,
            groupSimilarActions: Bool = true
        ) {
            self.minEventsForPlaybook = minEventsForPlaybook
            self.maxStepsInPlaybook = maxStepsInPlaybook
            self.includeTiming = includeTiming
            self.includeConfidence = includeConfidence
            self.groupSimilarActions = groupSimilarActions
        }
    }
    
    private let configuration: Configuration
    
    /// Initialize the playbook creator
    /// - Parameter configuration: Configuration for playbook generation
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    /// Create a comprehensive playbook from multiple activity summaries
    /// - Parameter summaries: Array of activity summaries to convert
    /// - Returns: Generated playbook
    public func createPlaybook(from summaries: [ActivitySummary]) throws -> Playbook {
        
        // Filter summaries that have enough events for meaningful playbooks
        let validSummaries = summaries.filter { summary in
            summary.session.events.count >= configuration.minEventsForPlaybook
        }
        
        guard !validSummaries.isEmpty else {
            throw PlaybookCreationError.insufficientData("No summaries with enough events for playbook creation")
        }
        
        // Determine playbook type based on session types
        let playbookType = determinePlaybookType(from: validSummaries)
        
        // Generate playbook metadata
        let metadata = generatePlaybookMetadata(from: validSummaries, type: playbookType)
        
        // Create step sequences for each summary
        var allSteps: [PlaybookStep] = []
        
        for (summaryIndex, summary) in validSummaries.enumerated() {
            let steps = try createStepsFromSummary(summary, sectionIndex: summaryIndex)
            allSteps.append(contentsOf: steps)
        }
        
        // Group and optimize steps if configured
        if configuration.groupSimilarActions {
            allSteps = groupSimilarSteps(allSteps)
        }
        
        // Limit steps if necessary
        if allSteps.count > configuration.maxStepsInPlaybook {
            allSteps = Array(allSteps.prefix(configuration.maxStepsInPlaybook))
        }
        
        return Playbook(
            id: UUID().uuidString,
            title: metadata.title,
            description: metadata.description,
            type: playbookType,
            steps: allSteps,
            prerequisites: metadata.prerequisites,
            expectedOutcomes: metadata.expectedOutcomes,
            estimatedDuration: metadata.estimatedDuration,
            difficulty: metadata.difficulty,
            createdAt: Date(),
            sourceSummaries: validSummaries.map { $0.id }
        )
    }
    
    /// Create a single-session playbook from one activity summary
    /// - Parameter summary: Activity summary to convert
    /// - Returns: Generated playbook
    public func createSingleSessionPlaybook(from summary: ActivitySummary) throws -> Playbook {
        return try createPlaybook(from: [summary])
    }
    
    /// Format playbook as Markdown
    /// - Parameter playbook: Playbook to format
    /// - Returns: Markdown-formatted playbook
    public func formatAsMarkdown(_ playbook: Playbook) throws -> String {
        var markdown = ""
        
        // Title and metadata
        markdown += "# \(playbook.title)\n\n"
        markdown += "\(playbook.description)\n\n"
        
        // Metadata table
        markdown += "## Playbook Information\n\n"
        markdown += "| Property | Value |\n"
        markdown += "|----------|-------|\n"
        markdown += "| Type | \(playbook.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) |\n"
        markdown += "| Estimated Duration | \(formatDuration(playbook.estimatedDuration)) |\n"
        markdown += "| Difficulty | \(playbook.difficulty.rawValue.capitalized) |\n"
        markdown += "| Steps | \(playbook.steps.count) |\n\n"
        
        // Prerequisites
        if !playbook.prerequisites.isEmpty {
            markdown += "## Prerequisites\n\n"
            for prerequisite in playbook.prerequisites {
                markdown += "- \(prerequisite)\n"
            }
            markdown += "\n"
        }
        
        // Steps
        markdown += "## Steps\n\n"
        
        for (index, step) in playbook.steps.enumerated() {
            let stepNumber = index + 1
            markdown += "\(stepNumber). **\(step.action)**\n"
            
            if let details = step.details, !details.isEmpty {
                markdown += "   \(details)\n"
            }
            
            if let target = step.target {
                markdown += "   - Target: `\(target)`\n"
            }
            
            if let expectedValue = step.expectedValue {
                markdown += "   - Expected Value: `\(expectedValue)`\n"
            }
            
            if configuration.includeTiming, let duration = step.estimatedDuration {
                markdown += "   - Duration: ~\(formatDuration(duration))\n"
            }
            
            if configuration.includeConfidence {
                markdown += "   - Confidence: \(String(format: "%.0f", step.confidence * 100))%\n"
            }
            
            if !step.notes.isEmpty {
                markdown += "   - Notes: \(step.notes.joined(separator: ", "))\n"
            }
            
            markdown += "\n"
        }
        
        // Expected outcomes
        if !playbook.expectedOutcomes.isEmpty {
            markdown += "## Expected Outcomes\n\n"
            for outcome in playbook.expectedOutcomes {
                markdown += "- \(outcome)\n"
            }
            markdown += "\n"
        }
        
        return markdown
    }
    
    /// Format playbook as JSON
    /// - Parameter playbook: Playbook to format
    /// - Returns: JSON-formatted playbook
    public func formatAsJSON(_ playbook: Playbook) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(playbook)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
    
    /// Format playbook as CSV (steps only)
    /// - Parameter playbook: Playbook to format
    /// - Returns: CSV-formatted steps
    public func formatAsCSV(_ playbook: Playbook) throws -> String {
        var csv = ""
        
        // CSV header
        var headers = ["step_number", "action", "target", "expected_value", "details"]
        
        if configuration.includeTiming {
            headers.append("estimated_duration_seconds")
        }
        
        if configuration.includeConfidence {
            headers.append("confidence")
        }
        
        headers.append("notes")
        
        csv += headers.joined(separator: ",") + "\n"
        
        // CSV data rows
        for (index, step) in playbook.steps.enumerated() {
            var row = [
                String(index + 1),
                "\"" + step.action.replacingOccurrences(of: "\"", with: "\"\"") + "\"",
                step.target ?? "",
                step.expectedValue ?? "",
                "\"" + (step.details?.replacingOccurrences(of: "\"", with: "\"\"") ?? "") + "\""
            ]
            
            if configuration.includeTiming {
                row.append(step.estimatedDuration != nil ? String(format: "%.1f", step.estimatedDuration!) : "")
            }
            
            if configuration.includeConfidence {
                row.append(String(format: "%.3f", step.confidence))
            }
            
            row.append("\"" + step.notes.joined(separator: "; ").replacingOccurrences(of: "\"", with: "\"\"") + "\"")
            
            csv += row.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    /// Format playbook as HTML
    /// - Parameter playbook: Playbook to format
    /// - Returns: HTML-formatted playbook
    public func formatAsHTML(_ playbook: Playbook) throws -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(playbook.title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
                .header { border-bottom: 2px solid #007AFF; padding-bottom: 20px; margin-bottom: 30px; }
                .metadata { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
                .step { border-left: 4px solid #007AFF; padding: 15px; margin: 15px 0; background: #fafafa; }
                .step-number { font-weight: bold; color: #007AFF; }
                .step-details { margin: 10px 0; color: #666; }
                .prerequisites, .outcomes { background: #e7f3ff; padding: 15px; border-radius: 8px; margin: 20px 0; }
                .code { background: #f1f1f1; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
            </style>
        </head>
        <body>
        """
        
        // Header
        html += "<div class=\"header\">"
        html += "<h1>\(playbook.title)</h1>"
        html += "<p>\(playbook.description)</p>"
        html += "</div>"
        
        // Metadata
        html += "<div class=\"metadata\">"
        html += "<h2>Playbook Information</h2>"
        html += "<ul>"
        html += "<li><strong>Type:</strong> \(playbook.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)</li>"
        html += "<li><strong>Estimated Duration:</strong> \(formatDuration(playbook.estimatedDuration))</li>"
        html += "<li><strong>Difficulty:</strong> \(playbook.difficulty.rawValue.capitalized)</li>"
        html += "<li><strong>Steps:</strong> \(playbook.steps.count)</li>"
        html += "</ul>"
        html += "</div>"
        
        // Prerequisites
        if !playbook.prerequisites.isEmpty {
            html += "<div class=\"prerequisites\">"
            html += "<h2>Prerequisites</h2>"
            html += "<ul>"
            for prerequisite in playbook.prerequisites {
                html += "<li>\(prerequisite)</li>"
            }
            html += "</ul>"
            html += "</div>"
        }
        
        // Steps
        html += "<h2>Steps</h2>"
        
        for (index, step) in playbook.steps.enumerated() {
            html += "<div class=\"step\">"
            html += "<div class=\"step-number\">Step \(index + 1)</div>"
            html += "<h3>\(step.action)</h3>"
            
            if let details = step.details, !details.isEmpty {
                html += "<p>\(details)</p>"
            }
            
            html += "<div class=\"step-details\">"
            
            if let target = step.target {
                html += "<p><strong>Target:</strong> <span class=\"code\">\(target)</span></p>"
            }
            
            if let expectedValue = step.expectedValue {
                html += "<p><strong>Expected Value:</strong> <span class=\"code\">\(expectedValue)</span></p>"
            }
            
            if configuration.includeTiming, let duration = step.estimatedDuration {
                html += "<p><strong>Duration:</strong> ~\(formatDuration(duration))</p>"
            }
            
            if configuration.includeConfidence {
                html += "<p><strong>Confidence:</strong> \(String(format: "%.0f", step.confidence * 100))%</p>"
            }
            
            if !step.notes.isEmpty {
                html += "<p><strong>Notes:</strong> \(step.notes.joined(separator: ", "))</p>"
            }
            
            html += "</div>"
            html += "</div>"
        }
        
        // Expected outcomes
        if !playbook.expectedOutcomes.isEmpty {
            html += "<div class=\"outcomes\">"
            html += "<h2>Expected Outcomes</h2>"
            html += "<ul>"
            for outcome in playbook.expectedOutcomes {
                html += "<li>\(outcome)</li>"
            }
            html += "</ul>"
            html += "</div>"
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - Private Methods
    
    private func determinePlaybookType(from summaries: [ActivitySummary]) -> PlaybookType {
        let sessionTypes = summaries.map { $0.session.sessionType }
        let uniqueTypes = Set(sessionTypes)
        
        if uniqueTypes.count == 1 {
            // Single session type
            switch uniqueTypes.first! {
            case .formFilling:
                return .formWorkflow
            case .dataEntry:
                return .dataEntry
            case .navigation:
                return .navigation
            case .research:
                return .research
            case .communication:
                return .communication
            case .development:
                return .development
            case .mixed:
                return .general
            }
        } else {
            // Multiple session types
            if uniqueTypes.contains(.formFilling) && uniqueTypes.contains(.dataEntry) {
                return .formWorkflow
            } else if uniqueTypes.contains(.development) {
                return .development
            } else {
                return .general
            }
        }
    }
    
    private func generatePlaybookMetadata(
        from summaries: [ActivitySummary],
        type: PlaybookType
    ) -> PlaybookMetadata {
        
        let totalDuration = summaries.reduce(0) { $0 + $1.session.duration }
        let totalEvents = summaries.reduce(0) { $0 + $1.session.events.count }
        
        // Generate title based on type and content
        let title = generatePlaybookTitle(type: type, summaries: summaries)
        
        // Generate description
        let description = generatePlaybookDescription(type: type, summaries: summaries)
        
        // Extract prerequisites from context
        let prerequisites = extractPrerequisites(from: summaries)
        
        // Extract expected outcomes
        let expectedOutcomes = summaries.flatMap { $0.outcomes }
        
        // Determine difficulty based on complexity
        let difficulty = determineDifficulty(events: totalEvents, duration: totalDuration)
        
        return PlaybookMetadata(
            title: title,
            description: description,
            prerequisites: prerequisites,
            expectedOutcomes: Array(Set(expectedOutcomes)), // Remove duplicates
            estimatedDuration: totalDuration,
            difficulty: difficulty
        )
    }
    
    private func createStepsFromSummary(_ summary: ActivitySummary, sectionIndex: Int) throws -> [PlaybookStep] {
        let chronologicalEvents = summary.session.events.sorted { $0.timestamp < $1.timestamp }
        var steps: [PlaybookStep] = []
        
        // Add section header if multiple summaries
        if sectionIndex > 0 {
            steps.append(PlaybookStep(
                id: UUID().uuidString,
                action: "Begin \(summary.session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ")) phase",
                details: "Starting the next phase of the workflow",
                target: nil,
                expectedValue: nil,
                estimatedDuration: nil,
                confidence: 1.0,
                notes: ["Section \(sectionIndex + 1)"]
            ))
        }
        
        for event in chronologicalEvents {
            let step = createStepFromEvent(event)
            steps.append(step)
        }
        
        return steps
    }
    
    private func createStepFromEvent(_ event: ActivityEvent) -> PlaybookStep {
        let action = generateStepAction(for: event)
        let details = generateStepDetails(for: event)
        let estimatedDuration = estimateStepDuration(for: event)
        let notes = generateStepNotes(for: event)
        
        return PlaybookStep(
            id: UUID().uuidString,
            action: action,
            details: details,
            target: event.target,
            expectedValue: event.valueAfter,
            estimatedDuration: configuration.includeTiming ? estimatedDuration : nil,
            confidence: event.confidence,
            notes: notes
        )
    }
    
    private func generateStepAction(for event: ActivityEvent) -> String {
        switch event.type {
        case .fieldChange:
            if event.valueAfter != nil {
                return "Enter value in \(event.target)"
            } else {
                return "Modify \(event.target)"
            }
            
        case .formSubmission:
            return "Submit the form"
            
        case .modalAppearance:
            return "Handle dialog or modal"
            
        case .errorDisplay:
            return "Address error message"
            
        case .navigation:
            return "Navigate to \(event.target)"
            
        case .dataEntry:
            return "Enter data in \(event.target)"
            
        case .appSwitch:
            return "Switch to \(event.target)"
            
        case .click:
            return "Click on \(event.target)"
        }
    }
    
    private func generateStepDetails(for event: ActivityEvent) -> String? {
        switch event.type {
        case .fieldChange:
            if let before = event.valueBefore, let after = event.valueAfter {
                return "Change the value from '\(before)' to '\(after)'"
            } else if let after = event.valueAfter {
                return "Set the value to '\(after)'"
            } else {
                return "Modify the field as needed"
            }
            
        case .formSubmission:
            return "Click the submit button to complete the form"
            
        case .modalAppearance:
            if let value = event.valueAfter {
                return "Interact with the dialog: \(value)"
            } else {
                return "Handle the dialog that appears"
            }
            
        case .errorDisplay:
            if let error = event.valueAfter {
                return "Resolve the error: \(error)"
            } else {
                return "Check for and resolve any errors"
            }
            
        case .navigation:
            return "Use navigation controls to reach the target location"
            
        case .dataEntry:
            if let value = event.valueAfter {
                return "Input the value '\(value)'"
            } else {
                return "Enter the appropriate data"
            }
            
        case .appSwitch:
            return "Use Alt+Tab (Windows) or Cmd+Tab (Mac) to switch applications"
            
        case .click:
            return "Use mouse or trackpad to click on the element"
        }
    }
    
    private func estimateStepDuration(for event: ActivityEvent) -> TimeInterval? {
        // Estimate based on event type complexity
        switch event.type {
        case .click:
            return 2.0 // 2 seconds
        case .fieldChange, .dataEntry:
            let textLength = event.valueAfter?.count ?? 10
            return max(3.0, Double(textLength) * 0.2) // 0.2 seconds per character, minimum 3 seconds
        case .navigation:
            return 5.0 // 5 seconds
        case .appSwitch:
            return 3.0 // 3 seconds
        case .formSubmission:
            return 2.0 // 2 seconds
        case .modalAppearance:
            return 4.0 // 4 seconds to read and respond
        case .errorDisplay:
            return 10.0 // 10 seconds to understand and resolve
        }
    }
    
    private func generateStepNotes(for event: ActivityEvent) -> [String] {
        var notes: [String] = []
        
        if event.confidence < 0.8 {
            notes.append("Low confidence - verify this step")
        }
        
        if !event.evidenceFrames.isEmpty {
            notes.append("Evidence in frames: \(event.evidenceFrames.joined(separator: ", "))")
        }
        
        switch event.type {
        case .errorDisplay:
            notes.append("Error handling required")
        case .modalAppearance:
            notes.append("Dialog interaction")
        case .formSubmission:
            notes.append("Form completion")
        default:
            break
        }
        
        return notes
    }
    
    private func groupSimilarSteps(_ steps: [PlaybookStep]) -> [PlaybookStep] {
        var groupedSteps: [PlaybookStep] = []
        var currentGroup: [PlaybookStep] = []
        
        for step in steps {
            if let lastStep = currentGroup.last,
               areSimilarSteps(lastStep, step) {
                currentGroup.append(step)
            } else {
                // Process current group
                if !currentGroup.isEmpty {
                    if currentGroup.count > 1 {
                        let groupedStep = mergeSteps(currentGroup)
                        groupedSteps.append(groupedStep)
                    } else {
                        groupedSteps.append(currentGroup.first!)
                    }
                }
                
                // Start new group
                currentGroup = [step]
            }
        }
        
        // Process final group
        if !currentGroup.isEmpty {
            if currentGroup.count > 1 {
                let groupedStep = mergeSteps(currentGroup)
                groupedSteps.append(groupedStep)
            } else {
                groupedSteps.append(currentGroup.first!)
            }
        }
        
        return groupedSteps
    }
    
    private func areSimilarSteps(_ step1: PlaybookStep, _ step2: PlaybookStep) -> Bool {
        // Group consecutive data entry or field change steps
        let dataEntryActions = ["Enter value", "Enter data", "Modify"]
        
        let isStep1DataEntry = dataEntryActions.contains { step1.action.contains($0) }
        let isStep2DataEntry = dataEntryActions.contains { step2.action.contains($0) }
        
        return isStep1DataEntry && isStep2DataEntry
    }
    
    private func mergeSteps(_ steps: [PlaybookStep]) -> PlaybookStep {
        let targets = steps.compactMap { $0.target }.joined(separator: ", ")
        let avgConfidence = steps.map { $0.confidence }.reduce(0, +) / Float(steps.count)
        let totalDuration = steps.compactMap { $0.estimatedDuration }.reduce(0, +)
        
        return PlaybookStep(
            id: UUID().uuidString,
            action: "Complete data entry for multiple fields",
            details: "Enter data in the following fields: \(targets)",
            target: targets,
            expectedValue: nil,
            estimatedDuration: totalDuration > 0 ? totalDuration : nil,
            confidence: avgConfidence,
            notes: ["Grouped \(steps.count) similar steps"]
        )
    }
    
    private func generatePlaybookTitle(type: PlaybookType, summaries: [ActivitySummary]) -> String {
        let primaryApp = summaries.first?.session.primaryApplication ?? "Application"
        
        switch type {
        case .formWorkflow:
            return "Form Completion Workflow in \(primaryApp)"
        case .dataEntry:
            return "Data Entry Process in \(primaryApp)"
        case .navigation:
            return "Navigation Guide for \(primaryApp)"
        case .research:
            return "Research Workflow in \(primaryApp)"
        case .communication:
            return "Communication Process in \(primaryApp)"
        case .development:
            return "Development Workflow in \(primaryApp)"
        case .general:
            return "General Workflow in \(primaryApp)"
        }
    }
    
    private func generatePlaybookDescription(type: PlaybookType, summaries: [ActivitySummary]) -> String {
        let sessionCount = summaries.count
        let totalEvents = summaries.reduce(0) { $0 + $1.session.events.count }
        
        return "This playbook recreates a \(type.rawValue.replacingOccurrences(of: "_", with: " ")) workflow " +
               "based on \(sessionCount) recorded session\(sessionCount == 1 ? "" : "s") " +
               "with \(totalEvents) total actions. Follow these steps to reproduce the same workflow."
    }
    
    private func extractPrerequisites(from summaries: [ActivitySummary]) -> [String] {
        var prerequisites: [String] = []
        
        // Extract from context
        for summary in summaries {
            for span in summary.context.precedingSpans {
                prerequisites.append("Complete: \(span.title)")
            }
        }
        
        // Add application-specific prerequisites
        let apps = Set(summaries.compactMap { $0.session.primaryApplication })
        for app in apps {
            prerequisites.append("Have \(app) installed and accessible")
        }
        
        // Add general prerequisites
        if summaries.contains(where: { $0.session.sessionType == .formFilling }) {
            prerequisites.append("Have required form data available")
        }
        
        return Array(Set(prerequisites)) // Remove duplicates
    }
    
    private func determineDifficulty(events: Int, duration: TimeInterval) -> PlaybookDifficulty {
        let eventsPerMinute = Double(events) / (duration / 60.0)
        
        if events < 10 && duration < 300 { // Less than 10 events and 5 minutes
            return .beginner
        } else if events < 25 && eventsPerMinute < 2.0 {
            return .intermediate
        } else {
            return .advanced
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
}

// MARK: - Data Models

/// Represents a complete playbook with steps and metadata
public struct Playbook: Codable {
    public let id: String
    public let title: String
    public let description: String
    public let type: PlaybookType
    public let steps: [PlaybookStep]
    public let prerequisites: [String]
    public let expectedOutcomes: [String]
    public let estimatedDuration: TimeInterval
    public let difficulty: PlaybookDifficulty
    public let createdAt: Date
    public let sourceSummaries: [String]
    
    public init(
        id: String,
        title: String,
        description: String,
        type: PlaybookType,
        steps: [PlaybookStep],
        prerequisites: [String],
        expectedOutcomes: [String],
        estimatedDuration: TimeInterval,
        difficulty: PlaybookDifficulty,
        createdAt: Date,
        sourceSummaries: [String]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.steps = steps
        self.prerequisites = prerequisites
        self.expectedOutcomes = expectedOutcomes
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.createdAt = createdAt
        self.sourceSummaries = sourceSummaries
    }
}

/// Individual step in a playbook
public struct PlaybookStep: Codable {
    public let id: String
    public let action: String
    public let details: String?
    public let target: String?
    public let expectedValue: String?
    public let estimatedDuration: TimeInterval?
    public let confidence: Float
    public let notes: [String]
    
    public init(
        id: String,
        action: String,
        details: String? = nil,
        target: String? = nil,
        expectedValue: String? = nil,
        estimatedDuration: TimeInterval? = nil,
        confidence: Float,
        notes: [String] = []
    ) {
        self.id = id
        self.action = action
        self.details = details
        self.target = target
        self.expectedValue = expectedValue
        self.estimatedDuration = estimatedDuration
        self.confidence = confidence
        self.notes = notes
    }
}

/// Types of playbooks that can be generated
public enum PlaybookType: String, CaseIterable, Codable {
    case formWorkflow = "form_workflow"
    case dataEntry = "data_entry"
    case navigation = "navigation"
    case research = "research"
    case communication = "communication"
    case development = "development"
    case general = "general"
}

/// Difficulty levels for playbooks
public enum PlaybookDifficulty: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
}

/// Metadata for playbook generation
private struct PlaybookMetadata {
    let title: String
    let description: String
    let prerequisites: [String]
    let expectedOutcomes: [String]
    let estimatedDuration: TimeInterval
    let difficulty: PlaybookDifficulty
}

/// Errors that can occur during playbook creation
public enum PlaybookCreationError: Error, LocalizedError {
    case insufficientData(String)
    case invalidSummaryData(String)
    case stepGenerationFailed(String)
    case formatNotSupported(String)
    
    public var errorDescription: String? {
        switch self {
        case .insufficientData(let message):
            return "Insufficient data for playbook creation: \(message)"
        case .invalidSummaryData(let message):
            return "Invalid summary data: \(message)"
        case .stepGenerationFailed(let message):
            return "Step generation failed: \(message)"
        case .formatNotSupported(let format):
            return "Format not supported: \(format)"
        }
    }
}