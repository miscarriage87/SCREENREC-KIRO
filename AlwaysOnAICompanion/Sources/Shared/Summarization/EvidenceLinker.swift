import Foundation

/// Evidence linking and traceability system that connects summaries back to source frames
public class EvidenceLinker {
    
    /// Configuration for evidence linking behavior
    public struct Configuration {
        /// Maximum temporal distance for correlation analysis (seconds)
        public let maxTemporalDistance: TimeInterval
        /// Minimum confidence threshold for evidence links
        public let minEvidenceConfidence: Float
        /// Maximum number of evidence frames to track per event
        public let maxEvidenceFrames: Int
        /// Confidence decay factor for temporal distance
        public let temporalDecayFactor: Float
        
        public init(
            maxTemporalDistance: TimeInterval = 300, // 5 minutes
            minEvidenceConfidence: Float = 0.5,
            maxEvidenceFrames: Int = 10,
            temporalDecayFactor: Float = 0.1
        ) {
            self.maxTemporalDistance = maxTemporalDistance
            self.minEvidenceConfidence = minEvidenceConfidence
            self.maxEvidenceFrames = maxEvidenceFrames
            self.temporalDecayFactor = temporalDecayFactor
        }
    }
    
    private let configuration: Configuration
    
    /// Initialize the evidence linker
    /// - Parameter configuration: Configuration for evidence linking behavior
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    /// Create evidence references that link summaries back to source frames
    /// - Parameters:
    ///   - summary: Activity summary to create evidence for
    ///   - events: All events in the time range
    ///   - frameMetadata: Frame metadata for evidence lookup
    /// - Returns: Evidence reference system
    public func createEvidenceReferences(
        for summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata]
    ) -> EvidenceReference {
        
        // Collect all evidence frames from key events
        var evidenceFrames: Set<String> = Set()
        var eventEvidenceMap: [String: [String]] = [:]
        
        for event in summary.keyEvents {
            evidenceFrames.formUnion(event.evidenceFrames)
            eventEvidenceMap[event.id] = event.evidenceFrames
        }
        
        // Find related frames through temporal correlation
        let correlatedFrames = findTemporallyCorrelatedFrames(
            for: summary.session,
            in: frameMetadata
        )
        
        // Create bidirectional links
        let bidirectionalLinks = createBidirectionalLinks(
            summary: summary,
            events: events,
            evidenceFrames: Array(evidenceFrames),
            correlatedFrames: correlatedFrames
        )
        
        // Calculate confidence propagation
        let confidencePropagation = calculateConfidencePropagation(
            summary: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        return EvidenceReference(
            summaryId: summary.id,
            sessionId: summary.session.id,
            directEvidenceFrames: Array(evidenceFrames),
            correlatedFrames: correlatedFrames,
            eventEvidenceMap: eventEvidenceMap,
            bidirectionalLinks: bidirectionalLinks,
            confidencePropagation: confidencePropagation,
            createdAt: Date()
        )
    }
    
    /// Create bidirectional linking between events, frames, and reports
    /// - Parameters:
    ///   - summary: Activity summary
    ///   - events: All events
    ///   - evidenceFrames: Direct evidence frame IDs
    ///   - correlatedFrames: Temporally correlated frames
    /// - Returns: Bidirectional link structure
    public func createBidirectionalLinks(
        summary: ActivitySummary,
        events: [ActivityEvent],
        evidenceFrames: [String],
        correlatedFrames: [CorrelatedFrame]
    ) -> BidirectionalLinks {
        
        var frameToEvents: [String: [String]] = [:]
        var eventToFrames: [String: [String]] = [:]
        var summaryToEvents: [String] = []
        var eventToSummary: [String: String] = [:]
        
        // Map events to summary
        for event in summary.keyEvents {
            summaryToEvents.append(event.id)
            eventToSummary[event.id] = summary.id
            
            // Map event to its evidence frames
            eventToFrames[event.id] = event.evidenceFrames
            
            // Map frames back to events
            for frameId in event.evidenceFrames {
                if frameToEvents[frameId] == nil {
                    frameToEvents[frameId] = []
                }
                frameToEvents[frameId]?.append(event.id)
            }
        }
        
        // Add correlated frames to the mapping
        for correlatedFrame in correlatedFrames {
            if frameToEvents[correlatedFrame.frameId] == nil {
                frameToEvents[correlatedFrame.frameId] = []
            }
            // Link correlated frames to all events in the session
            for eventId in summaryToEvents {
                frameToEvents[correlatedFrame.frameId]?.append(eventId)
            }
        }
        
        return BidirectionalLinks(
            frameToEvents: frameToEvents,
            eventToFrames: eventToFrames,
            summaryToEvents: summaryToEvents,
            eventToSummary: eventToSummary
        )
    }
    
    /// Add temporal correlation analysis to strengthen evidence connections
    /// - Parameters:
    ///   - session: Activity session to analyze
    ///   - frameMetadata: Available frame metadata
    /// - Returns: Array of temporally correlated frames
    public func findTemporallyCorrelatedFrames(
        for session: ActivitySession,
        in frameMetadata: [FrameMetadata]
    ) -> [CorrelatedFrame] {
        
        var correlatedFrames: [CorrelatedFrame] = []
        
        // Filter frames within the session time range
        let sessionFrames = frameMetadata.filter { frame in
            frame.timestamp >= session.startTime &&
            frame.timestamp <= session.endTime
        }
        
        // Sort frames by timestamp
        let sortedFrames = sessionFrames.sorted { $0.timestamp < $1.timestamp }
        
        // Analyze temporal patterns
        for (index, frame) in sortedFrames.enumerated() {
            var correlationScore: Float = 0.0
            var correlationReasons: [String] = []
            
            // Check proximity to session events
            let proximityScore = calculateEventProximityScore(
                frame: frame,
                session: session
            )
            correlationScore += proximityScore * 0.4
            
            if proximityScore > 0.5 {
                correlationReasons.append("temporal_proximity_to_events")
            }
            
            // Check application context consistency
            if let primaryApp = session.primaryApplication,
               frame.applicationName == primaryApp {
                correlationScore += 0.3
                correlationReasons.append("application_context_match")
            }
            
            // Check for scene transitions (if we have adjacent frames)
            if index > 0 {
                let previousFrame = sortedFrames[index - 1]
                let sceneTransitionScore = calculateSceneTransitionScore(
                    from: previousFrame,
                    to: frame
                )
                correlationScore += sceneTransitionScore * 0.2
                
                if sceneTransitionScore > 0.7 {
                    correlationReasons.append("significant_scene_transition")
                }
            }
            
            // Check for workflow continuity
            let workflowScore = calculateWorkflowContinuityScore(
                frame: frame,
                session: session
            )
            correlationScore += workflowScore * 0.1
            
            if workflowScore > 0.6 {
                correlationReasons.append("workflow_continuity")
            }
            
            // Only include frames above minimum confidence
            if correlationScore >= configuration.minEvidenceConfidence {
                let correlatedFrame = CorrelatedFrame(
                    frameId: frame.frameId,
                    timestamp: frame.timestamp,
                    correlationScore: correlationScore,
                    correlationReasons: correlationReasons,
                    applicationName: frame.applicationName,
                    windowTitle: frame.windowTitle
                )
                correlatedFrames.append(correlatedFrame)
            }
        }
        
        // Sort by correlation score and limit results
        correlatedFrames.sort { $0.correlationScore > $1.correlationScore }
        return Array(correlatedFrames.prefix(configuration.maxEvidenceFrames))
    }
    
    /// Calculate confidence propagation from raw data through to final summaries
    /// - Parameters:
    ///   - summary: Activity summary
    ///   - events: All events
    ///   - frameMetadata: Frame metadata
    /// - Returns: Confidence propagation analysis
    public func calculateConfidencePropagation(
        summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata]
    ) -> ConfidencePropagation {
        
        // Calculate base confidence from frame data
        let frameConfidences = calculateFrameConfidences(
            evidenceFrames: summary.keyEvents.flatMap { $0.evidenceFrames },
            frameMetadata: frameMetadata
        )
        
        // Calculate event confidence aggregation
        let eventConfidences = summary.keyEvents.map { event in
            EventConfidence(
                eventId: event.id,
                rawConfidence: event.confidence,
                evidenceFrameCount: event.evidenceFrames.count,
                temporalConsistency: calculateTemporalConsistency(event: event),
                spatialConsistency: calculateSpatialConsistency(event: event, frameMetadata: frameMetadata)
            )
        }
        
        // Calculate summary-level confidence
        let summaryConfidence = calculateSummaryConfidence(
            summary: summary,
            eventConfidences: eventConfidences,
            frameConfidences: frameConfidences
        )
        
        return ConfidencePropagation(
            frameConfidences: frameConfidences,
            eventConfidences: eventConfidences,
            summaryConfidence: summaryConfidence,
            overallConfidence: summary.confidence,
            confidenceFactors: analyzeConfidenceFactors(
                summary: summary,
                eventConfidences: eventConfidences
            )
        )
    }
    
    /// Trace evidence path from summary back to source frames
    /// - Parameters:
    ///   - summaryId: ID of the summary to trace
    ///   - evidenceReference: Evidence reference system
    /// - Returns: Complete evidence trace
    public func traceEvidencePath(
        summaryId: String,
        evidenceReference: EvidenceReference
    ) -> EvidenceTrace {
        
        guard evidenceReference.summaryId == summaryId else {
            return EvidenceTrace(
                summaryId: summaryId,
                tracePath: [],
                totalConfidence: 0.0,
                traceComplete: false
            )
        }
        
        var tracePath: [EvidenceTraceStep] = []
        var totalConfidence: Float = 0.0
        
        // Start from summary level
        let summaryStep = EvidenceTraceStep(
            level: .summary,
            id: summaryId,
            confidence: evidenceReference.confidencePropagation.summaryConfidence.aggregatedConfidence,
            evidenceType: .narrative,
            description: "Activity summary generated from session events"
        )
        tracePath.append(summaryStep)
        totalConfidence += summaryStep.confidence * 0.1
        
        // Trace through events
        for eventId in evidenceReference.bidirectionalLinks.summaryToEvents {
            if let eventConfidence = evidenceReference.confidencePropagation.eventConfidences.first(where: { $0.eventId == eventId }) {
                let eventStep = EvidenceTraceStep(
                    level: .event,
                    id: eventId,
                    confidence: eventConfidence.rawConfidence,
                    evidenceType: .interaction,
                    description: "Detected interaction event"
                )
                tracePath.append(eventStep)
                totalConfidence += eventStep.confidence * 0.3
                
                // Trace through frames for this event
                if let frameIds = evidenceReference.bidirectionalLinks.eventToFrames[eventId] {
                    for frameId in frameIds {
                        if let frameConfidence = evidenceReference.confidencePropagation.frameConfidences.first(where: { $0.frameId == frameId }) {
                            let frameStep = EvidenceTraceStep(
                                level: .frame,
                                id: frameId,
                                confidence: frameConfidence.ocrConfidence,
                                evidenceType: .visual,
                                description: "Source frame with OCR data"
                            )
                            tracePath.append(frameStep)
                            totalConfidence += frameStep.confidence * 0.6
                        }
                    }
                }
            }
        }
        
        // Normalize total confidence
        let stepCount = Float(tracePath.count)
        if stepCount > 0 {
            totalConfidence = totalConfidence / stepCount
        }
        
        return EvidenceTrace(
            summaryId: summaryId,
            tracePath: tracePath,
            totalConfidence: totalConfidence,
            traceComplete: !tracePath.isEmpty
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateEventProximityScore(
        frame: FrameMetadata,
        session: ActivitySession
    ) -> Float {
        var proximityScore: Float = 0.0
        
        for event in session.events {
            let timeDifference = abs(frame.timestamp.timeIntervalSince(event.timestamp))
            
            if timeDifference <= configuration.maxTemporalDistance {
                let normalizedDistance = Float(timeDifference / configuration.maxTemporalDistance)
                let eventProximity = 1.0 - normalizedDistance
                proximityScore = max(proximityScore, eventProximity)
            }
        }
        
        return proximityScore
    }
    
    private func calculateSceneTransitionScore(
        from previousFrame: FrameMetadata,
        to currentFrame: FrameMetadata
    ) -> Float {
        // Simple heuristic based on application and window changes
        var transitionScore: Float = 0.0
        
        // Application change indicates significant transition
        if previousFrame.applicationName != currentFrame.applicationName {
            transitionScore += 0.5
        }
        
        // Window title change within same app
        if previousFrame.applicationName == currentFrame.applicationName &&
           previousFrame.windowTitle != currentFrame.windowTitle {
            transitionScore += 0.3
        }
        
        // Time gap indicates potential transition
        let timeDifference = currentFrame.timestamp.timeIntervalSince(previousFrame.timestamp)
        if timeDifference > 5.0 { // 5 seconds
            transitionScore += 0.2
        }
        
        return min(transitionScore, 1.0)
    }
    
    private func calculateWorkflowContinuityScore(
        frame: FrameMetadata,
        session: ActivitySession
    ) -> Float {
        // Analyze workflow patterns within the session
        var continuityScore: Float = 0.0
        
        // Check if frame is within a consistent application workflow
        let sessionApps = Set(session.events.compactMap { $0.metadata["app_name"] })
        if sessionApps.contains(frame.applicationName) {
            continuityScore += 0.4
        }
        
        // Check temporal consistency
        let sessionDuration = session.endTime.timeIntervalSince(session.startTime)
        let frameOffset = frame.timestamp.timeIntervalSince(session.startTime)
        
        if frameOffset >= 0 && frameOffset <= sessionDuration {
            continuityScore += 0.6
        }
        
        return continuityScore
    }
    
    private func calculateFrameConfidences(
        evidenceFrames: [String],
        frameMetadata: [FrameMetadata]
    ) -> [FrameConfidence] {
        
        return evidenceFrames.compactMap { frameId in
            guard let frame = frameMetadata.first(where: { $0.frameId == frameId }) else {
                return nil
            }
            
            return FrameConfidence(
                frameId: frameId,
                ocrConfidence: frame.ocrConfidence ?? 0.8, // Default if not available
                imageQuality: frame.imageQuality ?? 0.9,
                temporalStability: calculateTemporalStability(frame: frame, allFrames: frameMetadata),
                contextRelevance: calculateContextRelevance(frame: frame)
            )
        }
    }
    
    private func calculateTemporalConsistency(event: ActivityEvent) -> Float {
        // Analyze consistency of event timing
        let evidenceCount = Float(event.evidenceFrames.count)
        
        // More evidence frames generally indicate higher consistency
        let evidenceScore = min(evidenceCount / 5.0, 1.0) // Normalize to max 5 frames
        
        // Event confidence contributes to temporal consistency
        let confidenceScore = event.confidence
        
        return (evidenceScore * 0.4) + (confidenceScore * 0.6)
    }
    
    private func calculateSpatialConsistency(
        event: ActivityEvent,
        frameMetadata: [FrameMetadata]
    ) -> Float {
        // Analyze spatial consistency of event evidence
        let relevantFrames = frameMetadata.filter { frame in
            event.evidenceFrames.contains(frame.frameId)
        }
        
        if relevantFrames.isEmpty {
            return 0.0
        }
        
        // Check application consistency
        let apps = Set(relevantFrames.map { $0.applicationName })
        let appConsistency = apps.count == 1 ? 1.0 : 0.5
        
        // Check window consistency
        let windows = Set(relevantFrames.map { $0.windowTitle })
        let windowConsistency = windows.count <= 2 ? 1.0 : 0.7
        
        return Float((appConsistency + windowConsistency) / 2.0)
    }
    
    private func calculateSummaryConfidence(
        summary: ActivitySummary,
        eventConfidences: [EventConfidence],
        frameConfidences: [FrameConfidence]
    ) -> SummaryConfidence {
        
        let avgEventConfidence = eventConfidences.isEmpty ? 0.0 :
            eventConfidences.map { $0.rawConfidence }.reduce(0, +) / Float(eventConfidences.count)
        
        let avgFrameConfidence = frameConfidences.isEmpty ? 0.0 :
            frameConfidences.map { $0.ocrConfidence }.reduce(0, +) / Float(frameConfidences.count)
        
        let temporalConsistency = eventConfidences.isEmpty ? 0.0 :
            eventConfidences.map { $0.temporalConsistency }.reduce(0, +) / Float(eventConfidences.count)
        
        let spatialConsistency = eventConfidences.isEmpty ? 0.0 :
            eventConfidences.map { $0.spatialConsistency }.reduce(0, +) / Float(eventConfidences.count)
        
        let aggregatedConfidence = (
            avgEventConfidence * 0.4 +
            avgFrameConfidence * 0.3 +
            temporalConsistency * 0.2 +
            spatialConsistency * 0.1
        )
        
        return SummaryConfidence(
            aggregatedConfidence: aggregatedConfidence,
            eventConfidenceAverage: avgEventConfidence,
            frameConfidenceAverage: avgFrameConfidence,
            temporalConsistency: temporalConsistency,
            spatialConsistency: spatialConsistency,
            evidenceCompleteness: calculateEvidenceCompleteness(summary: summary)
        )
    }
    
    private func calculateTemporalStability(
        frame: FrameMetadata,
        allFrames: [FrameMetadata]
    ) -> Float {
        // Find nearby frames in time
        let timeWindow: TimeInterval = 30.0 // 30 seconds
        let nearbyFrames = allFrames.filter { otherFrame in
            abs(otherFrame.timestamp.timeIntervalSince(frame.timestamp)) <= timeWindow &&
            otherFrame.frameId != frame.frameId
        }
        
        if nearbyFrames.isEmpty {
            return 0.5 // Neutral stability if no nearby frames
        }
        
        // Check consistency with nearby frames
        let sameAppFrames = nearbyFrames.filter { $0.applicationName == frame.applicationName }
        let appStability = Float(sameAppFrames.count) / Float(nearbyFrames.count)
        
        return appStability
    }
    
    private func calculateContextRelevance(frame: FrameMetadata) -> Float {
        // Analyze contextual relevance of the frame
        var relevance: Float = 0.5 // Base relevance
        
        // Interactive applications are more relevant
        let interactiveApps = ["Safari", "Chrome", "Firefox", "Xcode", "Terminal", "Finder"]
        if interactiveApps.contains(frame.applicationName) {
            relevance += 0.3
        }
        
        // Frames with meaningful window titles are more relevant
        if !frame.windowTitle.isEmpty && frame.windowTitle != frame.applicationName {
            relevance += 0.2
        }
        
        return min(relevance, 1.0)
    }
    
    private func calculateEvidenceCompleteness(summary: ActivitySummary) -> Float {
        let totalEvents = summary.session.events.count
        let keyEventsCount = summary.keyEvents.count
        
        if totalEvents == 0 {
            return 0.0
        }
        
        return Float(keyEventsCount) / Float(totalEvents)
    }
    
    private func analyzeConfidenceFactors(
        summary: ActivitySummary,
        eventConfidences: [EventConfidence]
    ) -> [ConfidenceFactor] {
        
        var factors: [ConfidenceFactor] = []
        
        // Event count factor
        let eventCount = eventConfidences.count
        if eventCount >= 5 {
            factors.append(ConfidenceFactor(
                name: "sufficient_events",
                impact: 0.2,
                description: "Sufficient number of events for reliable analysis"
            ))
        } else if eventCount < 3 {
            factors.append(ConfidenceFactor(
                name: "insufficient_events",
                impact: -0.3,
                description: "Limited number of events may affect reliability"
            ))
        }
        
        // Temporal consistency factor
        let avgTemporalConsistency = eventConfidences.isEmpty ? 0.0 :
            eventConfidences.map { $0.temporalConsistency }.reduce(0, +) / Float(eventConfidences.count)
        
        if avgTemporalConsistency > 0.8 {
            factors.append(ConfidenceFactor(
                name: "high_temporal_consistency",
                impact: 0.15,
                description: "Events show strong temporal consistency"
            ))
        } else if avgTemporalConsistency < 0.5 {
            factors.append(ConfidenceFactor(
                name: "low_temporal_consistency",
                impact: -0.2,
                description: "Events show weak temporal consistency"
            ))
        }
        
        // Session duration factor
        let sessionDuration = summary.session.duration
        if sessionDuration > 300 { // 5 minutes
            factors.append(ConfidenceFactor(
                name: "substantial_session",
                impact: 0.1,
                description: "Session duration provides substantial context"
            ))
        } else if sessionDuration < 60 { // 1 minute
            factors.append(ConfidenceFactor(
                name: "brief_session",
                impact: -0.1,
                description: "Brief session may limit context"
            ))
        }
        
        return factors
    }
}

// MARK: - Data Structures

/// Represents frame metadata for evidence linking
public struct FrameMetadata {
    public let frameId: String
    public let timestamp: Date
    public let applicationName: String
    public let windowTitle: String
    public let ocrConfidence: Float?
    public let imageQuality: Float?
    
    public init(
        frameId: String,
        timestamp: Date,
        applicationName: String,
        windowTitle: String,
        ocrConfidence: Float? = nil,
        imageQuality: Float? = nil
    ) {
        self.frameId = frameId
        self.timestamp = timestamp
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.ocrConfidence = ocrConfidence
        self.imageQuality = imageQuality
    }
}

/// Evidence reference system linking summaries to source data
public struct EvidenceReference: Codable {
    public let summaryId: String
    public let sessionId: String
    public let directEvidenceFrames: [String]
    public let correlatedFrames: [CorrelatedFrame]
    public let eventEvidenceMap: [String: [String]]
    public let bidirectionalLinks: BidirectionalLinks
    public let confidencePropagation: ConfidencePropagation
    public let createdAt: Date
    
    public init(
        summaryId: String,
        sessionId: String,
        directEvidenceFrames: [String],
        correlatedFrames: [CorrelatedFrame],
        eventEvidenceMap: [String: [String]],
        bidirectionalLinks: BidirectionalLinks,
        confidencePropagation: ConfidencePropagation,
        createdAt: Date
    ) {
        self.summaryId = summaryId
        self.sessionId = sessionId
        self.directEvidenceFrames = directEvidenceFrames
        self.correlatedFrames = correlatedFrames
        self.eventEvidenceMap = eventEvidenceMap
        self.bidirectionalLinks = bidirectionalLinks
        self.confidencePropagation = confidencePropagation
        self.createdAt = createdAt
    }
}

/// Temporally correlated frame with correlation analysis
public struct CorrelatedFrame: Codable {
    public let frameId: String
    public let timestamp: Date
    public let correlationScore: Float
    public let correlationReasons: [String]
    public let applicationName: String
    public let windowTitle: String
    
    public init(
        frameId: String,
        timestamp: Date,
        correlationScore: Float,
        correlationReasons: [String],
        applicationName: String,
        windowTitle: String
    ) {
        self.frameId = frameId
        self.timestamp = timestamp
        self.correlationScore = correlationScore
        self.correlationReasons = correlationReasons
        self.applicationName = applicationName
        self.windowTitle = windowTitle
    }
}

/// Bidirectional links between different data levels
public struct BidirectionalLinks: Codable {
    public let frameToEvents: [String: [String]]
    public let eventToFrames: [String: [String]]
    public let summaryToEvents: [String]
    public let eventToSummary: [String: String]
    
    public init(
        frameToEvents: [String: [String]],
        eventToFrames: [String: [String]],
        summaryToEvents: [String],
        eventToSummary: [String: String]
    ) {
        self.frameToEvents = frameToEvents
        self.eventToFrames = eventToFrames
        self.summaryToEvents = summaryToEvents
        self.eventToSummary = eventToSummary
    }
}

/// Confidence propagation analysis through the data pipeline
public struct ConfidencePropagation: Codable {
    public let frameConfidences: [FrameConfidence]
    public let eventConfidences: [EventConfidence]
    public let summaryConfidence: SummaryConfidence
    public let overallConfidence: Float
    public let confidenceFactors: [ConfidenceFactor]
    
    public init(
        frameConfidences: [FrameConfidence],
        eventConfidences: [EventConfidence],
        summaryConfidence: SummaryConfidence,
        overallConfidence: Float,
        confidenceFactors: [ConfidenceFactor]
    ) {
        self.frameConfidences = frameConfidences
        self.eventConfidences = eventConfidences
        self.summaryConfidence = summaryConfidence
        self.overallConfidence = overallConfidence
        self.confidenceFactors = confidenceFactors
    }
}

/// Frame-level confidence analysis
public struct FrameConfidence: Codable {
    public let frameId: String
    public let ocrConfidence: Float
    public let imageQuality: Float
    public let temporalStability: Float
    public let contextRelevance: Float
    
    public init(
        frameId: String,
        ocrConfidence: Float,
        imageQuality: Float,
        temporalStability: Float,
        contextRelevance: Float
    ) {
        self.frameId = frameId
        self.ocrConfidence = ocrConfidence
        self.imageQuality = imageQuality
        self.temporalStability = temporalStability
        self.contextRelevance = contextRelevance
    }
}

/// Event-level confidence analysis
public struct EventConfidence: Codable {
    public let eventId: String
    public let rawConfidence: Float
    public let evidenceFrameCount: Int
    public let temporalConsistency: Float
    public let spatialConsistency: Float
    
    public init(
        eventId: String,
        rawConfidence: Float,
        evidenceFrameCount: Int,
        temporalConsistency: Float,
        spatialConsistency: Float
    ) {
        self.eventId = eventId
        self.rawConfidence = rawConfidence
        self.evidenceFrameCount = evidenceFrameCount
        self.temporalConsistency = temporalConsistency
        self.spatialConsistency = spatialConsistency
    }
}

/// Summary-level confidence analysis
public struct SummaryConfidence: Codable {
    public let aggregatedConfidence: Float
    public let eventConfidenceAverage: Float
    public let frameConfidenceAverage: Float
    public let temporalConsistency: Float
    public let spatialConsistency: Float
    public let evidenceCompleteness: Float
    
    public init(
        aggregatedConfidence: Float,
        eventConfidenceAverage: Float,
        frameConfidenceAverage: Float,
        temporalConsistency: Float,
        spatialConsistency: Float,
        evidenceCompleteness: Float
    ) {
        self.aggregatedConfidence = aggregatedConfidence
        self.eventConfidenceAverage = eventConfidenceAverage
        self.frameConfidenceAverage = frameConfidenceAverage
        self.temporalConsistency = temporalConsistency
        self.spatialConsistency = spatialConsistency
        self.evidenceCompleteness = evidenceCompleteness
    }
}

/// Factor affecting confidence calculation
public struct ConfidenceFactor: Codable {
    public let name: String
    public let impact: Float
    public let description: String
    
    public init(name: String, impact: Float, description: String) {
        self.name = name
        self.impact = impact
        self.description = description
    }
}

/// Complete evidence trace from summary to source frames
public struct EvidenceTrace: Codable {
    public let summaryId: String
    public let tracePath: [EvidenceTraceStep]
    public let totalConfidence: Float
    public let traceComplete: Bool
    
    public init(
        summaryId: String,
        tracePath: [EvidenceTraceStep],
        totalConfidence: Float,
        traceComplete: Bool
    ) {
        self.summaryId = summaryId
        self.tracePath = tracePath
        self.totalConfidence = totalConfidence
        self.traceComplete = traceComplete
    }
}

/// Individual step in evidence trace
public struct EvidenceTraceStep: Codable {
    public let level: EvidenceLevel
    public let id: String
    public let confidence: Float
    public let evidenceType: EvidenceType
    public let description: String
    
    public init(
        level: EvidenceLevel,
        id: String,
        confidence: Float,
        evidenceType: EvidenceType,
        description: String
    ) {
        self.level = level
        self.id = id
        self.confidence = confidence
        self.evidenceType = evidenceType
        self.description = description
    }
}

/// Levels in the evidence hierarchy
public enum EvidenceLevel: String, CaseIterable, Codable {
    case summary = "summary"
    case event = "event"
    case frame = "frame"
}

/// Types of evidence
public enum EvidenceType: String, CaseIterable, Codable {
    case narrative = "narrative"
    case interaction = "interaction"
    case visual = "visual"
}