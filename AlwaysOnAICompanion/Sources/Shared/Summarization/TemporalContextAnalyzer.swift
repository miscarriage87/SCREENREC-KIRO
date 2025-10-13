import Foundation

/// Analyzes temporal context to maintain workflow continuity in summaries
public class TemporalContextAnalyzer {
    
    /// Configuration for temporal analysis
    public struct Configuration {
        /// Time window to look for preceding context (seconds)
        public let precedingContextWindow: TimeInterval
        /// Time window to look for following context (seconds)
        public let followingContextWindow: TimeInterval
        /// Minimum similarity score to consider activities related
        public let minSimilarityScore: Float
        /// Maximum number of related spans to include in context
        public let maxRelatedSpans: Int
        
        public init(
            precedingContextWindow: TimeInterval = 3600, // 1 hour
            followingContextWindow: TimeInterval = 1800, // 30 minutes
            minSimilarityScore: Float = 0.6,
            maxRelatedSpans: Int = 5
        ) {
            self.precedingContextWindow = precedingContextWindow
            self.followingContextWindow = followingContextWindow
            self.minSimilarityScore = minSimilarityScore
            self.maxRelatedSpans = maxRelatedSpans
        }
    }
    
    private let configuration: Configuration
    
    /// Initialize the temporal context analyzer
    /// - Parameter configuration: Configuration for analysis behavior
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    /// Analyze temporal context for an activity session
    /// - Parameters:
    ///   - session: The activity session to analyze
    ///   - existingSpans: Existing spans for context analysis
    /// - Returns: Temporal context information
    public func analyzeTemporalContext(
        session: ActivitySession,
        existingSpans: [Span]
    ) throws -> TemporalContext {
        
        // Find preceding spans within the context window
        let precedingSpans = findPrecedingSpans(
            for: session,
            in: existingSpans
        )
        
        // Find following spans within the context window
        let followingSpans = findFollowingSpans(
            for: session,
            in: existingSpans
        )
        
        // Analyze workflow continuity
        let workflowContinuity = analyzeWorkflowContinuity(
            session: session,
            precedingSpans: precedingSpans,
            followingSpans: followingSpans
        )
        
        // Find related sessions based on similarity
        let relatedSessions = findRelatedSessions(
            session: session,
            spans: existingSpans
        )
        
        return TemporalContext(
            precedingSpans: precedingSpans,
            followingSpans: followingSpans,
            relatedSessions: relatedSessions,
            workflowContinuity: workflowContinuity
        )
    }
    
    /// Find spans that precede the given session
    private func findPrecedingSpans(
        for session: ActivitySession,
        in spans: [Span]
    ) -> [Span] {
        
        let contextStart = session.startTime.addingTimeInterval(-configuration.precedingContextWindow)
        
        let precedingSpans = spans.filter { span in
            span.endTime >= contextStart && span.endTime <= session.startTime
        }
        
        // Sort by end time (most recent first) and limit results
        return Array(precedingSpans
            .sorted { $0.endTime > $1.endTime }
            .prefix(configuration.maxRelatedSpans))
    }
    
    /// Find spans that follow the given session
    private func findFollowingSpans(
        for session: ActivitySession,
        in spans: [Span]
    ) -> [Span] {
        
        let contextEnd = session.endTime.addingTimeInterval(configuration.followingContextWindow)
        
        let followingSpans = spans.filter { span in
            span.startTime >= session.endTime && span.startTime <= contextEnd
        }
        
        // Sort by start time (earliest first) and limit results
        return Array(followingSpans
            .sorted { $0.startTime < $1.startTime }
            .prefix(configuration.maxRelatedSpans))
    }
    
    /// Analyze workflow continuity for the session
    private func analyzeWorkflowContinuity(
        session: ActivitySession,
        precedingSpans: [Span],
        followingSpans: [Span]
    ) -> WorkflowContinuity {
        
        // Analyze if this session is part of a larger workflow
        let isPartOfLargerWorkflow = !precedingSpans.isEmpty || !followingSpans.isEmpty
        
        // Determine workflow phase based on context
        let workflowPhase = determineWorkflowPhase(
            session: session,
            precedingSpans: precedingSpans,
            followingSpans: followingSpans
        )
        
        // Calculate continuity score based on temporal proximity and content similarity
        let continuityScore = calculateContinuityScore(
            session: session,
            precedingSpans: precedingSpans,
            followingSpans: followingSpans
        )
        
        // Extract related activities from context
        let relatedActivities = extractRelatedActivities(
            from: precedingSpans + followingSpans
        )
        
        return WorkflowContinuity(
            isPartOfLargerWorkflow: isPartOfLargerWorkflow,
            workflowPhase: workflowPhase,
            continuityScore: continuityScore,
            relatedActivities: relatedActivities
        )
    }
    
    /// Determine the workflow phase based on context
    private func determineWorkflowPhase(
        session: ActivitySession,
        precedingSpans: [Span],
        followingSpans: [Span]
    ) -> String? {
        
        // Analyze session type and context to determine phase
        switch session.sessionType {
        case .dataEntry:
            if precedingSpans.contains(where: { $0.kind == "research" }) {
                return "data_collection"
            } else if followingSpans.contains(where: { $0.kind == "form_submission" }) {
                return "data_input"
            }
            return "data_entry"
            
        case .formFilling:
            if precedingSpans.isEmpty {
                return "form_initiation"
            } else if followingSpans.contains(where: { $0.kind == "form_submission" }) {
                return "form_completion"
            }
            return "form_filling"
            
        case .navigation:
            if precedingSpans.contains(where: { $0.kind == "research" }) {
                return "information_seeking"
            }
            return "navigation"
            
        case .research:
            if followingSpans.contains(where: { $0.kind == "data_entry" }) {
                return "research_for_action"
            }
            return "information_gathering"
            
        case .communication:
            return "communication"
            
        case .development:
            if precedingSpans.contains(where: { $0.kind == "research" }) {
                return "implementation"
            }
            return "development"
            
        case .mixed:
            return "mixed_activity"
        }
    }
    
    /// Calculate continuity score based on temporal and content factors
    private func calculateContinuityScore(
        session: ActivitySession,
        precedingSpans: [Span],
        followingSpans: [Span]
    ) -> Float {
        
        var score: Float = 0.0
        var factors = 0
        
        // Temporal proximity factor
        if let nearestPreceding = precedingSpans.first {
            let gap = session.startTime.timeIntervalSince(nearestPreceding.endTime)
            let proximityScore = max(0, 1.0 - Float(gap / configuration.precedingContextWindow))
            score += proximityScore
            factors += 1
        }
        
        if let nearestFollowing = followingSpans.first {
            let gap = nearestFollowing.startTime.timeIntervalSince(session.endTime)
            let proximityScore = max(0, 1.0 - Float(gap / configuration.followingContextWindow))
            score += proximityScore
            factors += 1
        }
        
        // Content similarity factor
        let allContextSpans = precedingSpans + followingSpans
        if !allContextSpans.isEmpty {
            let similarityScores = allContextSpans.map { span in
                calculateContentSimilarity(session: session, span: span)
            }
            let avgSimilarity = similarityScores.reduce(0, +) / Float(similarityScores.count)
            score += avgSimilarity
            factors += 1
        }
        
        // Application continuity factor
        if let sessionApp = session.primaryApplication {
            let appContinuity = allContextSpans.contains { span in
                span.tags.contains(sessionApp)
            }
            if appContinuity {
                score += 0.8
                factors += 1
            }
        }
        
        return factors > 0 ? score / Float(factors) : 0.0
    }
    
    /// Calculate content similarity between session and span
    private func calculateContentSimilarity(session: ActivitySession, span: Span) -> Float {
        // Simple keyword-based similarity for now
        // In a more sophisticated implementation, this could use NLP techniques
        
        let sessionKeywords = extractKeywords(from: session)
        let spanKeywords = extractKeywords(from: span)
        
        let intersection = Set(sessionKeywords).intersection(Set(spanKeywords))
        let union = Set(sessionKeywords).union(Set(spanKeywords))
        
        return union.isEmpty ? 0.0 : Float(intersection.count) / Float(union.count)
    }
    
    /// Extract keywords from an activity session
    private func extractKeywords(from session: ActivitySession) -> [String] {
        var keywords: [String] = []
        
        // Add session type as keyword
        keywords.append(session.sessionType.rawValue)
        
        // Add primary application if available
        if let app = session.primaryApplication {
            keywords.append(app.lowercased())
        }
        
        // Extract keywords from event targets and values
        for event in session.events {
            keywords.append(event.type.rawValue)
            
            // Add target keywords
            let targetWords = event.target.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty && $0.count > 2 }
                .map { $0.lowercased() }
            keywords.append(contentsOf: targetWords)
            
            // Add value keywords
            if let value = event.valueAfter {
                let valueWords = value.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty && $0.count > 2 }
                    .map { $0.lowercased() }
                keywords.append(contentsOf: valueWords)
            }
        }
        
        return Array(Set(keywords)) // Remove duplicates
    }
    
    /// Extract keywords from a span
    private func extractKeywords(from span: Span) -> [String] {
        var keywords: [String] = []
        
        // Add span kind and tags
        keywords.append(span.kind.lowercased())
        keywords.append(contentsOf: span.tags.map { $0.lowercased() })
        
        // Extract keywords from title
        let titleWords = span.title.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 }
            .map { $0.lowercased() }
        keywords.append(contentsOf: titleWords)
        
        // Extract keywords from summary if available
        if let summary = span.summaryMarkdown {
            let summaryWords = summary.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty && $0.count > 2 }
                .map { $0.lowercased() }
            keywords.append(contentsOf: Array(summaryWords.prefix(10))) // Limit to first 10 words
        }
        
        return Array(Set(keywords)) // Remove duplicates
    }
    
    /// Extract related activities from context spans
    private func extractRelatedActivities(from spans: [Span]) -> [String] {
        var activities: [String] = []
        
        for span in spans {
            activities.append(span.kind)
            activities.append(contentsOf: span.tags)
        }
        
        // Return unique activities, sorted by frequency
        let activityCounts = Dictionary(grouping: activities, by: { $0 })
            .mapValues { $0.count }
        
        return activityCounts.sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    /// Find related sessions based on similarity
    private func findRelatedSessions(
        session: ActivitySession,
        spans: [Span]
    ) -> [ActivitySession] {
        // For now, return empty array as we don't have access to other sessions
        // In a full implementation, this would compare with other activity sessions
        return []
    }
}