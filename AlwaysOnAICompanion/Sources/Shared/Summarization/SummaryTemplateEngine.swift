import Foundation

/// Template engine for generating different types of activity reports
public class SummaryTemplateEngine {
    
    /// Available summary templates
    public enum TemplateType: String, CaseIterable {
        case narrative = "narrative"
        case structured = "structured"
        case playbook = "playbook"
        case timeline = "timeline"
        case executive = "executive"
    }
    
    private let templates: [TemplateType: SummaryTemplate]
    
    /// Initialize the template engine with default templates
    public init() {
        self.templates = [
            .narrative: NarrativeSummaryTemplate(),
            .structured: StructuredSummaryTemplate(),
            .playbook: PlaybookSummaryTemplate(),
            .timeline: TimelineSummaryTemplate(),
            .executive: ExecutiveSummaryTemplate()
        ]
    }
    
    /// Generate a summary using the specified template
    /// - Parameters:
    ///   - session: Activity session to summarize
    ///   - context: Temporal context for the session
    ///   - templateType: Type of template to use
    /// - Returns: Generated activity summary
    public func generateSummary(
        session: ActivitySession,
        context: TemporalContext,
        templateType: TemplateType = .narrative
    ) throws -> ActivitySummary {
        
        guard let template = templates[templateType] else {
            throw SummaryTemplateError.templateNotFound(templateType.rawValue)
        }
        
        let narrative = try template.generateNarrative(session: session, context: context)
        let keyEvents = template.extractKeyEvents(from: session)
        let outcomes = template.extractOutcomes(from: session, context: context)
        let confidence = template.calculateConfidence(for: session, context: context)
        
        return ActivitySummary(
            session: session,
            narrative: narrative,
            keyEvents: keyEvents,
            outcomes: outcomes,
            context: context,
            confidence: confidence
        )
    }
    
    /// Generate multiple summaries using different templates
    /// - Parameters:
    ///   - session: Activity session to summarize
    ///   - context: Temporal context for the session
    ///   - templateTypes: Array of template types to use
    /// - Returns: Dictionary of summaries by template type
    public func generateMultipleSummaries(
        session: ActivitySession,
        context: TemporalContext,
        templateTypes: [TemplateType] = TemplateType.allCases
    ) throws -> [TemplateType: ActivitySummary] {
        
        var summaries: [TemplateType: ActivitySummary] = [:]
        
        for templateType in templateTypes {
            let summary = try generateSummary(
                session: session,
                context: context,
                templateType: templateType
            )
            summaries[templateType] = summary
        }
        
        return summaries
    }
}

/// Errors that can occur during template processing
public enum SummaryTemplateError: Error, LocalizedError {
    case templateNotFound(String)
    case invalidSessionData(String)
    case templateProcessingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let templateType):
            return "Template not found: \(templateType)"
        case .invalidSessionData(let message):
            return "Invalid session data: \(message)"
        case .templateProcessingFailed(let message):
            return "Template processing failed: \(message)"
        }
    }
}

/// Protocol for summary templates
public protocol SummaryTemplate {
    /// Generate narrative text for the session
    func generateNarrative(session: ActivitySession, context: TemporalContext) throws -> String
    
    /// Extract key events from the session
    func extractKeyEvents(from session: ActivitySession) -> [ActivityEvent]
    
    /// Extract outcomes from the session
    func extractOutcomes(from session: ActivitySession, context: TemporalContext) -> [String]
    
    /// Calculate confidence score for the summary
    func calculateConfidence(for session: ActivitySession, context: TemporalContext) -> Float
}

/// Narrative summary template for human-readable stories
public class NarrativeSummaryTemplate: SummaryTemplate {
    
    public func generateNarrative(session: ActivitySession, context: TemporalContext) throws -> String {
        var narrative = ""
        
        // Opening context
        if context.workflowContinuity.isPartOfLargerWorkflow {
            if let phase = context.workflowContinuity.workflowPhase {
                narrative += "Continuing the \(phase) workflow, "
            } else {
                narrative += "As part of an ongoing workflow, "
            }
        }
        
        // Session introduction
        let duration = formatDuration(session.duration)
        let eventCount = session.events.count
        
        narrative += "the user engaged in \(session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ")) "
        
        if let app = session.primaryApplication {
            narrative += "within \(app) "
        }
        
        narrative += "for \(duration), performing \(eventCount) actions.\n\n"
        
        // Key activities
        let keyEvents = extractKeyEvents(from: session)
        if !keyEvents.isEmpty {
            narrative += "Key activities included:\n"
            
            for (index, event) in keyEvents.enumerated() {
                let eventDescription = describeEvent(event)
                narrative += "• \(eventDescription)"
                
                if index < keyEvents.count - 1 {
                    narrative += "\n"
                }
            }
            narrative += "\n\n"
        }
        
        // Outcomes and results
        let outcomes = extractOutcomes(from: session, context: context)
        if !outcomes.isEmpty {
            narrative += "This session resulted in:\n"
            for outcome in outcomes {
                narrative += "• \(outcome)\n"
            }
            narrative += "\n"
        }
        
        // Context and continuity
        if context.workflowContinuity.isPartOfLargerWorkflow {
            narrative += "This activity "
            
            if !context.precedingSpans.isEmpty {
                narrative += "built upon previous work in \(context.precedingSpans.first?.kind ?? "related activities") "
            }
            
            if !context.followingSpans.isEmpty {
                narrative += "and led to subsequent \(context.followingSpans.first?.kind ?? "activities")"
            }
            
            narrative += "."
        }
        
        return narrative.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func extractKeyEvents(from session: ActivitySession) -> [ActivityEvent] {
        // Sort events by importance and confidence
        let sortedEvents = session.events.sorted { event1, event2 in
            let importance1 = getEventImportance(event1.type)
            let importance2 = getEventImportance(event2.type)
            
            if importance1 != importance2 {
                return importance1 > importance2
            }
            
            return event1.confidence > event2.confidence
        }
        
        // Return top 5 most important events
        return Array(sortedEvents.prefix(5))
    }
    
    public func extractOutcomes(from session: ActivitySession, context: TemporalContext) -> [String] {
        var outcomes: [String] = []
        
        // Analyze session events to determine outcomes
        let eventTypes = Set(session.events.map { $0.type })
        
        if eventTypes.contains(.formSubmission) {
            outcomes.append("Form submission completed")
        }
        
        if eventTypes.contains(.dataEntry) {
            let dataEntryEvents = session.events.filter { $0.type == .dataEntry }
            outcomes.append("Data entered in \(dataEntryEvents.count) fields")
        }
        
        if eventTypes.contains(.navigation) {
            let navigationEvents = session.events.filter { $0.type == .navigation }
            outcomes.append("Navigated through \(navigationEvents.count) different screens/pages")
        }
        
        if eventTypes.contains(.errorDisplay) {
            outcomes.append("Encountered and potentially resolved errors")
        }
        
        // Add workflow-specific outcomes
        switch session.sessionType {
        case .formFilling:
            outcomes.append("Form filling process completed")
        case .research:
            outcomes.append("Information gathering session completed")
        case .communication:
            outcomes.append("Communication activities performed")
        case .development:
            outcomes.append("Development work session completed")
        default:
            break
        }
        
        return outcomes
    }
    
    public func calculateConfidence(for session: ActivitySession, context: TemporalContext) -> Float {
        var confidence: Float = 0.0
        var factors = 0
        
        // Event confidence factor
        if !session.events.isEmpty {
            let avgEventConfidence = session.events.map { $0.confidence }.reduce(0, +) / Float(session.events.count)
            confidence += avgEventConfidence
            factors += 1
        }
        
        // Session duration factor (longer sessions generally more reliable)
        let durationScore = min(1.0, Float(session.duration / 300)) // 5 minutes = full score
        confidence += durationScore
        factors += 1
        
        // Context continuity factor
        confidence += context.workflowContinuity.continuityScore
        factors += 1
        
        // Event count factor
        let eventCountScore = min(1.0, Float(session.events.count) / 10.0) // 10 events = full score
        confidence += eventCountScore
        factors += 1
        
        return factors > 0 ? confidence / Float(factors) : 0.0
    }
    
    private func getEventImportance(_ eventType: ActivityEventType) -> Int {
        switch eventType {
        case .formSubmission: return 10
        case .errorDisplay: return 9
        case .modalAppearance: return 8
        case .dataEntry: return 7
        case .fieldChange: return 6
        case .navigation: return 5
        case .appSwitch: return 4
        case .click: return 3
        }
    }
    
    private func describeEvent(_ event: ActivityEvent) -> String {
        switch event.type {
        case .fieldChange:
            if let before = event.valueBefore, let after = event.valueAfter {
                return "Changed \(event.target) from '\(before)' to '\(after)'"
            } else if let after = event.valueAfter {
                return "Set \(event.target) to '\(after)'"
            } else {
                return "Modified \(event.target)"
            }
            
        case .formSubmission:
            return "Submitted form"
            
        case .modalAppearance:
            return "Interacted with dialog: \(event.valueAfter ?? event.target)"
            
        case .errorDisplay:
            return "Encountered error: \(event.valueAfter ?? "Unknown error")"
            
        case .navigation:
            return "Navigated to \(event.target)"
            
        case .dataEntry:
            return "Entered data in \(event.target)"
            
        case .appSwitch:
            return "Switched to \(event.target)"
            
        case .click:
            return "Clicked on \(event.target)"
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

/// Structured summary template for organized data presentation
public class StructuredSummaryTemplate: SummaryTemplate {
    
    public func generateNarrative(session: ActivitySession, context: TemporalContext) throws -> String {
        var narrative = "## Activity Summary\n\n"
        
        // Session metadata
        narrative += "**Session Type:** \(session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)\n"
        narrative += "**Duration:** \(formatDuration(session.duration))\n"
        narrative += "**Events:** \(session.events.count)\n"
        
        if let app = session.primaryApplication {
            narrative += "**Primary Application:** \(app)\n"
        }
        
        narrative += "\n"
        
        // Context information
        if context.workflowContinuity.isPartOfLargerWorkflow {
            narrative += "### Workflow Context\n\n"
            
            if let phase = context.workflowContinuity.workflowPhase {
                narrative += "**Phase:** \(phase.replacingOccurrences(of: "_", with: " ").capitalized)\n"
            }
            
            narrative += "**Continuity Score:** \(String(format: "%.1f", context.workflowContinuity.continuityScore * 100))%\n"
            
            if !context.workflowContinuity.relatedActivities.isEmpty {
                narrative += "**Related Activities:** \(context.workflowContinuity.relatedActivities.joined(separator: ", "))\n"
            }
            
            narrative += "\n"
        }
        
        // Key events
        let keyEvents = extractKeyEvents(from: session)
        if !keyEvents.isEmpty {
            narrative += "### Key Events\n\n"
            
            for event in keyEvents {
                narrative += "- **\(event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized):** "
                narrative += describeEventStructured(event)
                narrative += " (Confidence: \(String(format: "%.1f", event.confidence * 100))%)\n"
            }
            
            narrative += "\n"
        }
        
        // Outcomes
        let outcomes = extractOutcomes(from: session, context: context)
        if !outcomes.isEmpty {
            narrative += "### Outcomes\n\n"
            
            for outcome in outcomes {
                narrative += "- \(outcome)\n"
            }
            
            narrative += "\n"
        }
        
        return narrative
    }
    
    public func extractKeyEvents(from session: ActivitySession) -> [ActivityEvent] {
        // Use the same logic as narrative template
        let narrativeTemplate = NarrativeSummaryTemplate()
        return narrativeTemplate.extractKeyEvents(from: session)
    }
    
    public func extractOutcomes(from session: ActivitySession, context: TemporalContext) -> [String] {
        // Use the same logic as narrative template
        let narrativeTemplate = NarrativeSummaryTemplate()
        return narrativeTemplate.extractOutcomes(from: session, context: context)
    }
    
    public func calculateConfidence(for session: ActivitySession, context: TemporalContext) -> Float {
        // Use the same logic as narrative template
        let narrativeTemplate = NarrativeSummaryTemplate()
        return narrativeTemplate.calculateConfidence(for: session, context: context)
    }
    
    private func describeEventStructured(_ event: ActivityEvent) -> String {
        switch event.type {
        case .fieldChange:
            if let before = event.valueBefore, let after = event.valueAfter {
                return "\(event.target): '\(before)' → '\(after)'"
            } else if let after = event.valueAfter {
                return "\(event.target): '\(after)'"
            } else {
                return "\(event.target) modified"
            }
            
        case .formSubmission:
            return "Form submitted"
            
        case .modalAppearance:
            return "\(event.valueAfter ?? event.target)"
            
        case .errorDisplay:
            return "\(event.valueAfter ?? "Unknown error")"
            
        case .navigation:
            return "→ \(event.target)"
            
        case .dataEntry:
            return "\(event.target): \(event.valueAfter ?? "data entered")"
            
        case .appSwitch:
            return "→ \(event.target)"
            
        case .click:
            return "\(event.target)"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

/// Playbook template for generating step-by-step action sequences
public class PlaybookSummaryTemplate: SummaryTemplate {
    
    public func generateNarrative(session: ActivitySession, context: TemporalContext) throws -> String {
        var playbook = "# Action Playbook\n\n"
        
        playbook += "## Overview\n\n"
        playbook += "This playbook recreates the \(session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ")) workflow "
        
        if let app = session.primaryApplication {
            playbook += "performed in \(app) "
        }
        
        playbook += "over \(formatDuration(session.duration)).\n\n"
        
        // Prerequisites
        if context.workflowContinuity.isPartOfLargerWorkflow {
            playbook += "## Prerequisites\n\n"
            
            if !context.precedingSpans.isEmpty {
                playbook += "Before starting this workflow, ensure you have completed:\n"
                for span in context.precedingSpans.prefix(3) {
                    playbook += "- \(span.title)\n"
                }
                playbook += "\n"
            }
        }
        
        // Step-by-step instructions
        playbook += "## Steps\n\n"
        
        let chronologicalEvents = session.events.sorted { $0.timestamp < $1.timestamp }
        
        for (index, event) in chronologicalEvents.enumerated() {
            let stepNumber = index + 1
            playbook += "\(stepNumber). \(generateStepInstruction(event))\n"
        }
        
        playbook += "\n"
        
        // Expected outcomes
        let outcomes = extractOutcomes(from: session, context: context)
        if !outcomes.isEmpty {
            playbook += "## Expected Outcomes\n\n"
            
            for outcome in outcomes {
                playbook += "- \(outcome)\n"
            }
            
            playbook += "\n"
        }
        
        // Next steps
        if !context.followingSpans.isEmpty {
            playbook += "## Next Steps\n\n"
            playbook += "After completing this workflow, you may proceed to:\n"
            
            for span in context.followingSpans.prefix(3) {
                playbook += "- \(span.title)\n"
            }
        }
        
        return playbook
    }
    
    public func extractKeyEvents(from session: ActivitySession) -> [ActivityEvent] {
        // For playbooks, all events are potentially key events
        return session.events.sorted { $0.timestamp < $1.timestamp }
    }
    
    public func extractOutcomes(from session: ActivitySession, context: TemporalContext) -> [String] {
        // Use the same logic as narrative template
        let narrativeTemplate = NarrativeSummaryTemplate()
        return narrativeTemplate.extractOutcomes(from: session, context: context)
    }
    
    public func calculateConfidence(for session: ActivitySession, context: TemporalContext) -> Float {
        // Playbooks require higher confidence due to step-by-step nature
        let baseConfidence = NarrativeSummaryTemplate().calculateConfidence(for: session, context: context)
        
        // Reduce confidence if events are sparse or unclear
        let eventDensity = Float(session.events.count) / Float(session.duration / 60) // events per minute
        let densityFactor = min(1.0, eventDensity / 2.0) // 2 events per minute = full score
        
        return baseConfidence * 0.8 + densityFactor * 0.2
    }
    
    private func generateStepInstruction(_ event: ActivityEvent) -> String {
        switch event.type {
        case .fieldChange:
            if let after = event.valueAfter {
                return "Enter '\(after)' in the \(event.target) field"
            } else {
                return "Modify the \(event.target) field"
            }
            
        case .formSubmission:
            return "Submit the form by clicking the submit button"
            
        case .modalAppearance:
            return "Handle the dialog that appears: \(event.valueAfter ?? event.target)"
            
        case .errorDisplay:
            return "Address the error message: \(event.valueAfter ?? "Check for errors and resolve them")"
            
        case .navigation:
            return "Navigate to \(event.target)"
            
        case .dataEntry:
            if let value = event.valueAfter {
                return "Enter '\(value)' in \(event.target)"
            } else {
                return "Enter data in \(event.target)"
            }
            
        case .appSwitch:
            return "Switch to \(event.target) application"
            
        case .click:
            return "Click on \(event.target)"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "less than a minute"
        }
    }
}

/// Timeline template for chronological event presentation
public class TimelineSummaryTemplate: SummaryTemplate {
    
    public func generateNarrative(session: ActivitySession, context: TemporalContext) throws -> String {
        var timeline = "# Activity Timeline\n\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        
        timeline += "**Session:** \(formatter.string(from: session.startTime)) - \(formatter.string(from: session.endTime))\n"
        timeline += "**Duration:** \(formatDuration(session.duration))\n\n"
        
        // Context timeline
        if context.workflowContinuity.isPartOfLargerWorkflow {
            timeline += "## Context\n\n"
            
            // Preceding activities
            if !context.precedingSpans.isEmpty {
                timeline += "### Before this session:\n"
                for span in context.precedingSpans.reversed() {
                    timeline += "- \(formatter.string(from: span.endTime)): \(span.title)\n"
                }
                timeline += "\n"
            }
        }
        
        // Main timeline
        timeline += "## Event Timeline\n\n"
        
        let chronologicalEvents = session.events.sorted { $0.timestamp < $1.timestamp }
        
        for event in chronologicalEvents {
            let timeString = formatter.string(from: event.timestamp)
            let description = describeEventForTimeline(event)
            timeline += "**\(timeString)** - \(description)\n"
        }
        
        timeline += "\n"
        
        // Following activities
        if !context.followingSpans.isEmpty {
            timeline += "### After this session:\n"
            for span in context.followingSpans {
                timeline += "- \(formatter.string(from: span.startTime)): \(span.title)\n"
            }
        }
        
        return timeline
    }
    
    public func extractKeyEvents(from session: ActivitySession) -> [ActivityEvent] {
        // For timelines, return all events in chronological order
        return session.events.sorted { $0.timestamp < $1.timestamp }
    }
    
    public func extractOutcomes(from session: ActivitySession, context: TemporalContext) -> [String] {
        // Use the same logic as narrative template
        let narrativeTemplate = NarrativeSummaryTemplate()
        return narrativeTemplate.extractOutcomes(from: session, context: context)
    }
    
    public func calculateConfidence(for session: ActivitySession, context: TemporalContext) -> Float {
        // Use the same logic as narrative template
        let narrativeTemplate = NarrativeSummaryTemplate()
        return narrativeTemplate.calculateConfidence(for: session, context: context)
    }
    
    private func describeEventForTimeline(_ event: ActivityEvent) -> String {
        let confidence = String(format: "%.0f", event.confidence * 100)
        
        switch event.type {
        case .fieldChange:
            if let before = event.valueBefore, let after = event.valueAfter {
                return "Changed \(event.target): '\(before)' → '\(after)' (\(confidence)%)"
            } else if let after = event.valueAfter {
                return "Set \(event.target) to '\(after)' (\(confidence)%)"
            } else {
                return "Modified \(event.target) (\(confidence)%)"
            }
            
        case .formSubmission:
            return "Form submitted (\(confidence)%)"
            
        case .modalAppearance:
            return "Dialog appeared: \(event.valueAfter ?? event.target) (\(confidence)%)"
            
        case .errorDisplay:
            return "Error encountered: \(event.valueAfter ?? "Unknown") (\(confidence)%)"
            
        case .navigation:
            return "Navigated to \(event.target) (\(confidence)%)"
            
        case .dataEntry:
            return "Data entered in \(event.target) (\(confidence)%)"
            
        case .appSwitch:
            return "Switched to \(event.target) (\(confidence)%)"
            
        case .click:
            return "Clicked \(event.target) (\(confidence)%)"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

/// Executive summary template for high-level overview
public class ExecutiveSummaryTemplate: SummaryTemplate {
    
    public func generateNarrative(session: ActivitySession, context: TemporalContext) throws -> String {
        var summary = "# Executive Summary\n\n"
        
        // High-level overview
        summary += "## Overview\n\n"
        summary += "User completed a \(session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ")) session "
        
        if let app = session.primaryApplication {
            summary += "in \(app) "
        }
        
        summary += "lasting \(formatDuration(session.duration)) with \(session.events.count) recorded actions.\n\n"
        
        // Key metrics
        summary += "## Key Metrics\n\n"
        summary += "- **Duration:** \(formatDuration(session.duration))\n"
        summary += "- **Actions:** \(session.events.count)\n"
        summary += "- **Efficiency:** \(calculateEfficiencyMetric(session)) actions/minute\n"
        
        if context.workflowContinuity.isPartOfLargerWorkflow {
            summary += "- **Workflow Integration:** \(String(format: "%.0f", context.workflowContinuity.continuityScore * 100))% continuity\n"
        }
        
        summary += "\n"
        
        // Business impact
        let outcomes = extractOutcomes(from: session, context: context)
        if !outcomes.isEmpty {
            summary += "## Business Impact\n\n"
            
            for outcome in outcomes {
                summary += "- \(outcome)\n"
            }
            
            summary += "\n"
        }
        
        // Recommendations
        summary += "## Recommendations\n\n"
        let recommendations = generateRecommendations(session: session, context: context)
        
        for recommendation in recommendations {
            summary += "- \(recommendation)\n"
        }
        
        return summary
    }
    
    public func extractKeyEvents(from session: ActivitySession) -> [ActivityEvent] {
        // For executive summaries, focus on the most impactful events
        let narrativeTemplate = NarrativeSummaryTemplate()
        let keyEvents = narrativeTemplate.extractKeyEvents(from: session)
        
        // Return only top 3 most important events
        return Array(keyEvents.prefix(3))
    }
    
    public func extractOutcomes(from session: ActivitySession, context: TemporalContext) -> [String] {
        // Use the same logic as narrative template but focus on business outcomes
        let narrativeTemplate = NarrativeSummaryTemplate()
        let outcomes = narrativeTemplate.extractOutcomes(from: session, context: context)
        
        // Transform outcomes to be more business-focused
        return outcomes.map { outcome in
            switch outcome {
            case let o where o.contains("Form submission"):
                return "Process completion achieved"
            case let o where o.contains("Data entered"):
                return "Data collection completed"
            case let o where o.contains("Navigated"):
                return "System navigation performed"
            case let o where o.contains("errors"):
                return "Issue resolution completed"
            default:
                return outcome
            }
        }
    }
    
    public func calculateConfidence(for session: ActivitySession, context: TemporalContext) -> Float {
        // Use the same logic as narrative template
        let narrativeTemplate = NarrativeSummaryTemplate()
        return narrativeTemplate.calculateConfidence(for: session, context: context)
    }
    
    private func calculateEfficiencyMetric(_ session: ActivitySession) -> String {
        let actionsPerMinute = Double(session.events.count) / (session.duration / 60.0)
        return String(format: "%.1f", actionsPerMinute)
    }
    
    private func generateRecommendations(session: ActivitySession, context: TemporalContext) -> [String] {
        var recommendations: [String] = []
        
        // Analyze session for improvement opportunities
        let errorEvents = session.events.filter { $0.type == .errorDisplay }
        if !errorEvents.isEmpty {
            recommendations.append("Consider process optimization to reduce error encounters")
        }
        
        let efficiency = Double(session.events.count) / (session.duration / 60.0)
        if efficiency < 2.0 {
            recommendations.append("Workflow efficiency could be improved through automation or training")
        }
        
        if session.sessionType == .formFilling && session.duration > 600 { // 10 minutes
            recommendations.append("Form completion time suggests potential for UX improvements")
        }
        
        if context.workflowContinuity.continuityScore < 0.5 {
            recommendations.append("Consider improving workflow integration and context preservation")
        }
        
        // Default recommendation if no specific issues found
        if recommendations.isEmpty {
            recommendations.append("Workflow completed successfully with good efficiency")
        }
        
        return recommendations
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}