import Foundation

/// Activity summarization engine that processes events and spans into narrative summaries
public class ActivitySummarizer {
    
    /// Configuration for summarization behavior
    public struct Configuration {
        /// Minimum duration for an activity session (seconds)
        public let minSessionDuration: TimeInterval
        /// Maximum gap between events to consider them part of the same session (seconds)
        public let maxEventGap: TimeInterval
        /// Minimum number of events required for a meaningful summary
        public let minEventsForSummary: Int
        /// Maximum number of events to include in detailed analysis
        public let maxEventsForAnalysis: Int
        
        public init(
            minSessionDuration: TimeInterval = 60, // 1 minute
            maxEventGap: TimeInterval = 300, // 5 minutes
            minEventsForSummary: Int = 3,
            maxEventsForAnalysis: Int = 100
        ) {
            self.minSessionDuration = minSessionDuration
            self.maxEventGap = maxEventGap
            self.minEventsForSummary = minEventsForSummary
            self.maxEventsForAnalysis = maxEventsForAnalysis
        }
    }
    
    private let configuration: Configuration
    private let templateEngine: SummaryTemplateEngine
    private let contextAnalyzer: TemporalContextAnalyzer
    private let sessionGrouper: ActivitySessionGrouper
    
    /// Initialize the activity summarizer
    /// - Parameter configuration: Configuration for summarization behavior
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.templateEngine = SummaryTemplateEngine()
        self.contextAnalyzer = TemporalContextAnalyzer()
        
        // Convert ActivitySummarizer configuration to ActivitySessionGrouper configuration
        let grouperConfig = ActivitySessionGrouper.Configuration(
            maxEventGap: configuration.maxEventGap,
            minSessionDuration: configuration.minSessionDuration,
            minEventsPerSession: configuration.minEventsForSummary,
            maxEventsPerSession: configuration.maxEventsForAnalysis,
            contextSimilarityThreshold: 0.7
        )
        self.sessionGrouper = ActivitySessionGrouper(configuration: grouperConfig)
    }
    
    /// Process events and spans into narrative summaries
    /// - Parameters:
    ///   - events: Array of detected events to summarize
    ///   - existingSpans: Existing spans for context
    ///   - timeRange: Time range to analyze
    /// - Returns: Array of generated activity summaries
    public func summarizeActivity(
        events: [ActivityEvent],
        existingSpans: [Span] = [],
        timeRange: DateInterval
    ) throws -> [ActivitySummary] {
        
        // Filter events to the specified time range
        let filteredEvents = events.filter { event in
            timeRange.contains(event.timestamp)
        }
        
        guard !filteredEvents.isEmpty else {
            return []
        }
        
        // Group related events into coherent activity sessions
        let activitySessions = try sessionGrouper.groupEventsIntoSessions(filteredEvents)
        
        // Filter sessions that meet minimum requirements
        let validSessions = activitySessions.filter { session in
            session.duration >= configuration.minSessionDuration &&
            session.events.count >= configuration.minEventsForSummary
        }
        
        var summaries: [ActivitySummary] = []
        
        for session in validSessions {
            // Analyze temporal context for workflow continuity
            let context = try contextAnalyzer.analyzeTemporalContext(
                session: session,
                existingSpans: existingSpans
            )
            
            // Generate narrative summary using templates
            let summary = try templateEngine.generateSummary(
                session: session,
                context: context
            )
            
            summaries.append(summary)
        }
        
        return summaries
    }
    
    /// Generate a comprehensive report for a time period
    /// - Parameters:
    ///   - events: Events to include in the report
    ///   - spans: Existing spans for context
    ///   - timeRange: Time range for the report
    ///   - reportType: Type of report to generate
    /// - Returns: Generated activity report
    public func generateReport(
        events: [ActivityEvent],
        spans: [Span],
        timeRange: DateInterval,
        reportType: ActivityReportType = .daily
    ) throws -> ActivityReport {
        
        let summaries = try summarizeActivity(
            events: events,
            existingSpans: spans,
            timeRange: timeRange
        )
        
        return ActivityReport(
            timeRange: timeRange,
            reportType: reportType,
            summaries: summaries,
            totalEvents: events.count,
            totalDuration: timeRange.duration,
            generatedAt: Date()
        )
    }
}

/// Represents a detected event for summarization
public struct ActivityEvent {
    public let id: String
    public let timestamp: Date
    public let type: ActivityEventType
    public let target: String
    public let valueBefore: String?
    public let valueAfter: String?
    public let confidence: Float
    public let evidenceFrames: [String]
    public let metadata: [String: String]
    
    public init(
        id: String,
        timestamp: Date,
        type: ActivityEventType,
        target: String,
        valueBefore: String? = nil,
        valueAfter: String? = nil,
        confidence: Float,
        evidenceFrames: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.target = target
        self.valueBefore = valueBefore
        self.valueAfter = valueAfter
        self.confidence = confidence
        self.evidenceFrames = evidenceFrames
        self.metadata = metadata
    }
}

/// Types of activity events that can be summarized
public enum ActivityEventType: String, CaseIterable {
    case fieldChange = "field_change"
    case formSubmission = "form_submission"
    case modalAppearance = "modal_appearance"
    case errorDisplay = "error_display"
    case navigation = "navigation"
    case dataEntry = "data_entry"
    case appSwitch = "app_switch"
    case click = "click"
}

/// Represents a coherent activity session
public struct ActivitySession {
    public let id: String
    public let startTime: Date
    public let endTime: Date
    public let events: [ActivityEvent]
    public let primaryApplication: String?
    public let sessionType: ActivitySessionType
    
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    public init(
        id: String = UUID().uuidString,
        startTime: Date,
        endTime: Date,
        events: [ActivityEvent],
        primaryApplication: String? = nil,
        sessionType: ActivitySessionType
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.events = events
        self.primaryApplication = primaryApplication
        self.sessionType = sessionType
    }
}

/// Types of activity sessions
public enum ActivitySessionType: String, CaseIterable {
    case dataEntry = "data_entry"
    case formFilling = "form_filling"
    case navigation = "navigation"
    case research = "research"
    case communication = "communication"
    case development = "development"
    case mixed = "mixed"
}

/// Temporal context information for maintaining workflow continuity
public struct TemporalContext {
    public let precedingSpans: [Span]
    public let followingSpans: [Span]
    public let relatedSessions: [ActivitySession]
    public let workflowContinuity: WorkflowContinuity
    
    public init(
        precedingSpans: [Span] = [],
        followingSpans: [Span] = [],
        relatedSessions: [ActivitySession] = [],
        workflowContinuity: WorkflowContinuity
    ) {
        self.precedingSpans = precedingSpans
        self.followingSpans = followingSpans
        self.relatedSessions = relatedSessions
        self.workflowContinuity = workflowContinuity
    }
}

/// Workflow continuity analysis
public struct WorkflowContinuity {
    public let isPartOfLargerWorkflow: Bool
    public let workflowPhase: String?
    public let continuityScore: Float
    public let relatedActivities: [String]
    
    public init(
        isPartOfLargerWorkflow: Bool,
        workflowPhase: String? = nil,
        continuityScore: Float,
        relatedActivities: [String] = []
    ) {
        self.isPartOfLargerWorkflow = isPartOfLargerWorkflow
        self.workflowPhase = workflowPhase
        self.continuityScore = continuityScore
        self.relatedActivities = relatedActivities
    }
}

/// Generated activity summary
public struct ActivitySummary {
    public let id: String
    public let session: ActivitySession
    public let narrative: String
    public let keyEvents: [ActivityEvent]
    public let outcomes: [String]
    public let context: TemporalContext
    public let confidence: Float
    public let generatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        session: ActivitySession,
        narrative: String,
        keyEvents: [ActivityEvent],
        outcomes: [String] = [],
        context: TemporalContext,
        confidence: Float,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.session = session
        self.narrative = narrative
        self.keyEvents = keyEvents
        self.outcomes = outcomes
        self.context = context
        self.confidence = confidence
        self.generatedAt = generatedAt
    }
}

/// Types of activity reports
public enum ActivityReportType: String, CaseIterable {
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case session = "session"
    case custom = "custom"
}

/// Comprehensive activity report
public struct ActivityReport {
    public let timeRange: DateInterval
    public let reportType: ActivityReportType
    public let summaries: [ActivitySummary]
    public let totalEvents: Int
    public let totalDuration: TimeInterval
    public let generatedAt: Date
    
    public init(
        timeRange: DateInterval,
        reportType: ActivityReportType,
        summaries: [ActivitySummary],
        totalEvents: Int,
        totalDuration: TimeInterval,
        generatedAt: Date
    ) {
        self.timeRange = timeRange
        self.reportType = reportType
        self.summaries = summaries
        self.totalEvents = totalEvents
        self.totalDuration = totalDuration
        self.generatedAt = generatedAt
    }
}