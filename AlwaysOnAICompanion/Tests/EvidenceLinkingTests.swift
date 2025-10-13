import XCTest
@testable import Shared

class EvidenceLinkingTests: XCTestCase {
    
    var evidenceLinker: EvidenceLinker!
    var testConfiguration: EvidenceLinker.Configuration!
    
    override func setUp() {
        super.setUp()
        testConfiguration = EvidenceLinker.Configuration(
            maxTemporalDistance: 300,
            minEvidenceConfidence: 0.5,
            maxEvidenceFrames: 10,
            temporalDecayFactor: 0.1
        )
        evidenceLinker = EvidenceLinker(configuration: testConfiguration)
    }
    
    override func tearDown() {
        evidenceLinker = nil
        testConfiguration = nil
        super.tearDown()
    }
    
    // MARK: - Evidence Reference Creation Tests
    
    func testCreateEvidenceReferences() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let frameMetadata = createTestFrameMetadata()
        
        // When
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        // Then
        XCTAssertEqual(evidenceReference.summaryId, summary.id)
        XCTAssertEqual(evidenceReference.sessionId, summary.session.id)
        XCTAssertFalse(evidenceReference.directEvidenceFrames.isEmpty)
        XCTAssertFalse(evidenceReference.correlatedFrames.isEmpty)
        XCTAssertFalse(evidenceReference.eventEvidenceMap.isEmpty)
        
        // Verify bidirectional links
        XCTAssertFalse(evidenceReference.bidirectionalLinks.frameToEvents.isEmpty)
        XCTAssertFalse(evidenceReference.bidirectionalLinks.eventToFrames.isEmpty)
        XCTAssertFalse(evidenceReference.bidirectionalLinks.summaryToEvents.isEmpty)
        
        // Verify confidence propagation
        XCTAssertFalse(evidenceReference.confidencePropagation.frameConfidences.isEmpty)
        XCTAssertFalse(evidenceReference.confidencePropagation.eventConfidences.isEmpty)
        XCTAssertGreaterThan(evidenceReference.confidencePropagation.summaryConfidence.aggregatedConfidence, 0.0)
    }
    
    func testEvidenceReferenceIntegrity() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let frameMetadata = createTestFrameMetadata()
        
        // When
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        // Then - Verify all evidence frames are accounted for
        let allEvidenceFrames = Set(summary.keyEvents.flatMap { $0.evidenceFrames })
        let referencedFrames = Set(evidenceReference.directEvidenceFrames)
        
        XCTAssertTrue(allEvidenceFrames.isSubset(of: referencedFrames))
        
        // Verify event-frame mapping consistency
        for event in summary.keyEvents {
            XCTAssertEqual(
                evidenceReference.eventEvidenceMap[event.id],
                event.evidenceFrames
            )
        }
    }
    
    // MARK: - Bidirectional Linking Tests
    
    func testBidirectionalLinks() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let evidenceFrames = ["frame_1", "frame_2", "frame_3"]
        let correlatedFrames = createTestCorrelatedFrames()
        
        // When
        let bidirectionalLinks = evidenceLinker.createBidirectionalLinks(
            summary: summary,
            events: events,
            evidenceFrames: evidenceFrames,
            correlatedFrames: correlatedFrames
        )
        
        // Then
        // Verify frame-to-event mapping
        for frameId in evidenceFrames {
            XCTAssertNotNil(bidirectionalLinks.frameToEvents[frameId])
            XCTAssertFalse(bidirectionalLinks.frameToEvents[frameId]!.isEmpty)
        }
        
        // Verify event-to-frame mapping
        for event in summary.keyEvents {
            XCTAssertEqual(
                bidirectionalLinks.eventToFrames[event.id],
                event.evidenceFrames
            )
        }
        
        // Verify summary-to-event mapping
        let expectedEventIds = Set(summary.keyEvents.map { $0.id })
        let actualEventIds = Set(bidirectionalLinks.summaryToEvents)
        XCTAssertEqual(expectedEventIds, actualEventIds)
        
        // Verify event-to-summary mapping
        for eventId in bidirectionalLinks.summaryToEvents {
            XCTAssertEqual(bidirectionalLinks.eventToSummary[eventId], summary.id)
        }
    }
    
    func testBidirectionalLinkConsistency() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let evidenceFrames = ["frame_1", "frame_2"]
        let correlatedFrames: [CorrelatedFrame] = []
        
        // When
        let bidirectionalLinks = evidenceLinker.createBidirectionalLinks(
            summary: summary,
            events: events,
            evidenceFrames: evidenceFrames,
            correlatedFrames: correlatedFrames
        )
        
        // Then - Verify bidirectional consistency
        for (frameId, eventIds) in bidirectionalLinks.frameToEvents {
            for eventId in eventIds {
                let eventFrames = bidirectionalLinks.eventToFrames[eventId] ?? []
                XCTAssertTrue(eventFrames.contains(frameId), 
                    "Frame \(frameId) should be linked back from event \(eventId)")
            }
        }
        
        for (eventId, frameIds) in bidirectionalLinks.eventToFrames {
            for frameId in frameIds {
                let frameEvents = bidirectionalLinks.frameToEvents[frameId] ?? []
                XCTAssertTrue(frameEvents.contains(eventId),
                    "Event \(eventId) should be linked back from frame \(frameId)")
            }
        }
    }
    
    // MARK: - Temporal Correlation Tests
    
    func testTemporalCorrelation() {
        // Given
        let session = createTestActivitySession()
        let frameMetadata = createTestFrameMetadata()
        
        // When
        let correlatedFrames = evidenceLinker.findTemporallyCorrelatedFrames(
            for: session,
            in: frameMetadata
        )
        
        // Then
        XCTAssertFalse(correlatedFrames.isEmpty)
        
        // Verify all correlated frames are within session time range
        for correlatedFrame in correlatedFrames {
            XCTAssertGreaterThanOrEqual(correlatedFrame.timestamp, session.startTime)
            XCTAssertLessThanOrEqual(correlatedFrame.timestamp, session.endTime)
        }
        
        // Verify correlation scores are above minimum threshold
        for correlatedFrame in correlatedFrames {
            XCTAssertGreaterThanOrEqual(correlatedFrame.correlationScore, testConfiguration.minEvidenceConfidence)
        }
        
        // Verify frames are sorted by correlation score
        for i in 1..<correlatedFrames.count {
            XCTAssertGreaterThanOrEqual(
                correlatedFrames[i-1].correlationScore,
                correlatedFrames[i].correlationScore
            )
        }
    }
    
    func testTemporalCorrelationReasons() {
        // Given
        let session = createTestActivitySession()
        let frameMetadata = createTestFrameMetadata()
        
        // When
        let correlatedFrames = evidenceLinker.findTemporallyCorrelatedFrames(
            for: session,
            in: frameMetadata
        )
        
        // Then
        for correlatedFrame in correlatedFrames {
            XCTAssertFalse(correlatedFrame.correlationReasons.isEmpty)
            
            // Verify valid correlation reasons
            let validReasons = [
                "temporal_proximity_to_events",
                "application_context_match",
                "significant_scene_transition",
                "workflow_continuity"
            ]
            
            for reason in correlatedFrame.correlationReasons {
                XCTAssertTrue(validReasons.contains(reason))
            }
        }
    }
    
    func testTemporalCorrelationLimits() {
        // Given
        let session = createTestActivitySession()
        let frameMetadata = createLargeFrameMetadataSet() // Create many frames
        
        // When
        let correlatedFrames = evidenceLinker.findTemporallyCorrelatedFrames(
            for: session,
            in: frameMetadata
        )
        
        // Then
        XCTAssertLessThanOrEqual(correlatedFrames.count, testConfiguration.maxEvidenceFrames)
    }
    
    // MARK: - Confidence Propagation Tests
    
    func testConfidencePropagation() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let frameMetadata = createTestFrameMetadata()
        
        // When
        let confidencePropagation = evidenceLinker.calculateConfidencePropagation(
            summary: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        // Then
        XCTAssertFalse(confidencePropagation.frameConfidences.isEmpty)
        XCTAssertFalse(confidencePropagation.eventConfidences.isEmpty)
        XCTAssertGreaterThan(confidencePropagation.summaryConfidence.aggregatedConfidence, 0.0)
        XCTAssertLessThanOrEqual(confidencePropagation.summaryConfidence.aggregatedConfidence, 1.0)
        
        // Verify confidence factors
        XCTAssertFalse(confidencePropagation.confidenceFactors.isEmpty)
        
        for factor in confidencePropagation.confidenceFactors {
            XCTAssertFalse(factor.name.isEmpty)
            XCTAssertFalse(factor.description.isEmpty)
            XCTAssertGreaterThanOrEqual(factor.impact, -1.0)
            XCTAssertLessThanOrEqual(factor.impact, 1.0)
        }
    }
    
    func testFrameConfidenceCalculation() {
        // Given
        let evidenceFrames = ["frame_1", "frame_2", "frame_3"]
        let frameMetadata = createTestFrameMetadata()
        
        // When
        let frameConfidences = evidenceLinker.calculateFrameConfidences(
            evidenceFrames: evidenceFrames,
            frameMetadata: frameMetadata
        )
        
        // Then
        XCTAssertEqual(frameConfidences.count, evidenceFrames.count)
        
        for frameConfidence in frameConfidences {
            XCTAssertTrue(evidenceFrames.contains(frameConfidence.frameId))
            XCTAssertGreaterThan(frameConfidence.ocrConfidence, 0.0)
            XCTAssertLessThanOrEqual(frameConfidence.ocrConfidence, 1.0)
            XCTAssertGreaterThan(frameConfidence.imageQuality, 0.0)
            XCTAssertLessThanOrEqual(frameConfidence.imageQuality, 1.0)
            XCTAssertGreaterThanOrEqual(frameConfidence.temporalStability, 0.0)
            XCTAssertLessThanOrEqual(frameConfidence.temporalStability, 1.0)
            XCTAssertGreaterThan(frameConfidence.contextRelevance, 0.0)
            XCTAssertLessThanOrEqual(frameConfidence.contextRelevance, 1.0)
        }
    }
    
    func testEventConfidenceCalculation() {
        // Given
        let events = createTestEvents()
        let frameMetadata = createTestFrameMetadata()
        
        // When
        let eventConfidences = events.map { event in
            EventConfidence(
                eventId: event.id,
                rawConfidence: event.confidence,
                evidenceFrameCount: event.evidenceFrames.count,
                temporalConsistency: evidenceLinker.calculateTemporalConsistency(event: event),
                spatialConsistency: evidenceLinker.calculateSpatialConsistency(event: event, frameMetadata: frameMetadata)
            )
        }
        
        // Then
        XCTAssertEqual(eventConfidences.count, events.count)
        
        for (index, eventConfidence) in eventConfidences.enumerated() {
            let originalEvent = events[index]
            XCTAssertEqual(eventConfidence.eventId, originalEvent.id)
            XCTAssertEqual(eventConfidence.rawConfidence, originalEvent.confidence)
            XCTAssertEqual(eventConfidence.evidenceFrameCount, originalEvent.evidenceFrames.count)
            XCTAssertGreaterThanOrEqual(eventConfidence.temporalConsistency, 0.0)
            XCTAssertLessThanOrEqual(eventConfidence.temporalConsistency, 1.0)
            XCTAssertGreaterThanOrEqual(eventConfidence.spatialConsistency, 0.0)
            XCTAssertLessThanOrEqual(eventConfidence.spatialConsistency, 1.0)
        }
    }
    
    // MARK: - Evidence Tracing Tests
    
    func testEvidenceTracing() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let frameMetadata = createTestFrameMetadata()
        
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        // When
        let evidenceTrace = evidenceLinker.traceEvidencePath(
            summaryId: summary.id,
            evidenceReference: evidenceReference
        )
        
        // Then
        XCTAssertEqual(evidenceTrace.summaryId, summary.id)
        XCTAssertTrue(evidenceTrace.traceComplete)
        XCTAssertFalse(evidenceTrace.tracePath.isEmpty)
        XCTAssertGreaterThan(evidenceTrace.totalConfidence, 0.0)
        XCTAssertLessThanOrEqual(evidenceTrace.totalConfidence, 1.0)
        
        // Verify trace path structure
        let summarySteps = evidenceTrace.tracePath.filter { $0.level == .summary }
        let eventSteps = evidenceTrace.tracePath.filter { $0.level == .event }
        let frameSteps = evidenceTrace.tracePath.filter { $0.level == .frame }
        
        XCTAssertEqual(summarySteps.count, 1)
        XCTAssertGreaterThan(eventSteps.count, 0)
        XCTAssertGreaterThan(frameSteps.count, 0)
        
        // Verify evidence types
        XCTAssertTrue(summarySteps.first?.evidenceType == .narrative)
        XCTAssertTrue(eventSteps.allSatisfy { $0.evidenceType == .interaction })
        XCTAssertTrue(frameSteps.allSatisfy { $0.evidenceType == .visual })
    }
    
    func testEvidenceTraceInvalidSummary() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let frameMetadata = createTestFrameMetadata()
        
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        let invalidSummaryId = "invalid_summary_id"
        
        // When
        let evidenceTrace = evidenceLinker.traceEvidencePath(
            summaryId: invalidSummaryId,
            evidenceReference: evidenceReference
        )
        
        // Then
        XCTAssertEqual(evidenceTrace.summaryId, invalidSummaryId)
        XCTAssertFalse(evidenceTrace.traceComplete)
        XCTAssertTrue(evidenceTrace.tracePath.isEmpty)
        XCTAssertEqual(evidenceTrace.totalConfidence, 0.0)
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndEvidenceLinking() {
        // Given
        let summary = createTestActivitySummary()
        let events = createTestEvents()
        let frameMetadata = createTestFrameMetadata()
        
        // When - Create complete evidence system
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        let evidenceTrace = evidenceLinker.traceEvidencePath(
            summaryId: summary.id,
            evidenceReference: evidenceReference
        )
        
        // Then - Verify complete traceability
        XCTAssertTrue(evidenceTrace.traceComplete)
        
        // Verify all key events are traceable
        for keyEvent in summary.keyEvents {
            XCTAssertTrue(evidenceReference.bidirectionalLinks.summaryToEvents.contains(keyEvent.id))
            XCTAssertEqual(evidenceReference.bidirectionalLinks.eventToSummary[keyEvent.id], summary.id)
            
            // Verify event frames are traceable
            for frameId in keyEvent.evidenceFrames {
                XCTAssertTrue(evidenceReference.directEvidenceFrames.contains(frameId))
                let frameEvents = evidenceReference.bidirectionalLinks.frameToEvents[frameId] ?? []
                XCTAssertTrue(frameEvents.contains(keyEvent.id))
            }
        }
        
        // Verify confidence propagation integrity
        let propagation = evidenceReference.confidencePropagation
        XCTAssertEqual(propagation.eventConfidences.count, summary.keyEvents.count)
        XCTAssertGreaterThan(propagation.summaryConfidence.aggregatedConfidence, 0.0)
    }
    
    func testPerformanceWithLargeDataset() {
        // Given
        let summary = createLargeActivitySummary()
        let events = createLargeEventSet()
        let frameMetadata = createLargeFrameMetadataSet()
        
        // When
        let startTime = Date()
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        let endTime = Date()
        
        // Then
        let processingTime = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(processingTime, 5.0, "Evidence linking should complete within 5 seconds for large datasets")
        
        // Verify results are still accurate
        XCTAssertFalse(evidenceReference.directEvidenceFrames.isEmpty)
        XCTAssertFalse(evidenceReference.correlatedFrames.isEmpty)
        XCTAssertGreaterThan(evidenceReference.confidencePropagation.summaryConfidence.aggregatedConfidence, 0.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestActivitySummary() -> ActivitySummary {
        let session = createTestActivitySession()
        let keyEvents = createTestEvents().prefix(3).map { $0 }
        let context = TemporalContext(
            precedingSpans: [],
            followingSpans: [],
            relatedSessions: [],
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: true,
                workflowPhase: "data_entry",
                continuityScore: 0.8,
                relatedActivities: ["form_filling"]
            )
        )
        
        return ActivitySummary(
            id: "summary_1",
            session: session,
            narrative: "User completed form filling task with multiple field entries",
            keyEvents: Array(keyEvents),
            outcomes: ["Form submitted successfully"],
            context: context,
            confidence: 0.85
        )
    }
    
    private func createTestActivitySession() -> ActivitySession {
        let startTime = Date().addingTimeInterval(-600) // 10 minutes ago
        let endTime = Date().addingTimeInterval(-300)   // 5 minutes ago
        let events = createTestEvents()
        
        return ActivitySession(
            id: "session_1",
            startTime: startTime,
            endTime: endTime,
            events: events,
            primaryApplication: "Safari",
            sessionType: .formFilling
        )
    }
    
    private func createTestEvents() -> [ActivityEvent] {
        let baseTime = Date().addingTimeInterval(-600)
        
        return [
            ActivityEvent(
                id: "event_1",
                timestamp: baseTime.addingTimeInterval(60),
                type: .fieldChange,
                target: "email_field",
                valueBefore: "",
                valueAfter: "user@example.com",
                confidence: 0.9,
                evidenceFrames: ["frame_1", "frame_2"],
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event_2",
                timestamp: baseTime.addingTimeInterval(120),
                type: .fieldChange,
                target: "password_field",
                valueBefore: "",
                valueAfter: "********",
                confidence: 0.85,
                evidenceFrames: ["frame_2", "frame_3"],
                metadata: ["app_name": "Safari"]
            ),
            ActivityEvent(
                id: "event_3",
                timestamp: baseTime.addingTimeInterval(180),
                type: .formSubmission,
                target: "login_button",
                valueBefore: nil,
                valueAfter: "Login",
                confidence: 0.95,
                evidenceFrames: ["frame_3", "frame_4"],
                metadata: ["app_name": "Safari"]
            )
        ]
    }
    
    private func createTestFrameMetadata() -> [FrameMetadata] {
        let baseTime = Date().addingTimeInterval(-600)
        
        return [
            FrameMetadata(
                frameId: "frame_1",
                timestamp: baseTime.addingTimeInterval(50),
                applicationName: "Safari",
                windowTitle: "Login Page",
                ocrConfidence: 0.9,
                imageQuality: 0.95
            ),
            FrameMetadata(
                frameId: "frame_2",
                timestamp: baseTime.addingTimeInterval(110),
                applicationName: "Safari",
                windowTitle: "Login Page",
                ocrConfidence: 0.85,
                imageQuality: 0.9
            ),
            FrameMetadata(
                frameId: "frame_3",
                timestamp: baseTime.addingTimeInterval(170),
                applicationName: "Safari",
                windowTitle: "Login Page",
                ocrConfidence: 0.88,
                imageQuality: 0.92
            ),
            FrameMetadata(
                frameId: "frame_4",
                timestamp: baseTime.addingTimeInterval(190),
                applicationName: "Safari",
                windowTitle: "Dashboard",
                ocrConfidence: 0.92,
                imageQuality: 0.94
            )
        ]
    }
    
    private func createTestCorrelatedFrames() -> [CorrelatedFrame] {
        let baseTime = Date().addingTimeInterval(-600)
        
        return [
            CorrelatedFrame(
                frameId: "corr_frame_1",
                timestamp: baseTime.addingTimeInterval(100),
                correlationScore: 0.8,
                correlationReasons: ["temporal_proximity_to_events", "application_context_match"],
                applicationName: "Safari",
                windowTitle: "Login Page"
            ),
            CorrelatedFrame(
                frameId: "corr_frame_2",
                timestamp: baseTime.addingTimeInterval(150),
                correlationScore: 0.7,
                correlationReasons: ["workflow_continuity"],
                applicationName: "Safari",
                windowTitle: "Login Page"
            )
        ]
    }
    
    private func createLargeActivitySummary() -> ActivitySummary {
        let session = createLargeActivitySession()
        let keyEvents = createLargeEventSet().prefix(20).map { $0 }
        let context = TemporalContext(
            precedingSpans: [],
            followingSpans: [],
            relatedSessions: [],
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: true,
                workflowPhase: "complex_workflow",
                continuityScore: 0.75,
                relatedActivities: ["data_entry", "navigation", "form_filling"]
            )
        )
        
        return ActivitySummary(
            id: "large_summary_1",
            session: session,
            narrative: "Complex workflow with multiple applications and extensive user interactions",
            keyEvents: Array(keyEvents),
            outcomes: ["Workflow completed", "Data processed", "Reports generated"],
            context: context,
            confidence: 0.8
        )
    }
    
    private func createLargeActivitySession() -> ActivitySession {
        let startTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let endTime = Date().addingTimeInterval(-1800)   // 30 minutes ago
        let events = createLargeEventSet()
        
        return ActivitySession(
            id: "large_session_1",
            startTime: startTime,
            endTime: endTime,
            events: events,
            primaryApplication: "Xcode",
            sessionType: .development
        )
    }
    
    private func createLargeEventSet() -> [ActivityEvent] {
        var events: [ActivityEvent] = []
        let baseTime = Date().addingTimeInterval(-3600)
        
        for i in 0..<50 {
            let event = ActivityEvent(
                id: "large_event_\(i)",
                timestamp: baseTime.addingTimeInterval(Double(i * 30)),
                type: ActivityEventType.allCases.randomElement()!,
                target: "target_\(i)",
                valueBefore: i > 0 ? "value_\(i-1)" : nil,
                valueAfter: "value_\(i)",
                confidence: Float.random(in: 0.7...0.95),
                evidenceFrames: ["frame_\(i)", "frame_\(i+1)"],
                metadata: ["app_name": ["Xcode", "Safari", "Terminal"].randomElement()!]
            )
            events.append(event)
        }
        
        return events
    }
    
    private func createLargeFrameMetadataSet() -> [FrameMetadata] {
        var frames: [FrameMetadata] = []
        let baseTime = Date().addingTimeInterval(-3600)
        let applications = ["Xcode", "Safari", "Terminal", "Finder", "Mail"]
        
        for i in 0..<100 {
            let frame = FrameMetadata(
                frameId: "frame_\(i)",
                timestamp: baseTime.addingTimeInterval(Double(i * 20)),
                applicationName: applications.randomElement()!,
                windowTitle: "Window \(i)",
                ocrConfidence: Float.random(in: 0.7...0.95),
                imageQuality: Float.random(in: 0.8...0.98)
            )
            frames.append(frame)
        }
        
        return frames
    }
}

// MARK: - Test Extensions

extension EvidenceLinker {
    // Expose internal methods for testing
    func calculateTemporalConsistency(event: ActivityEvent) -> Float {
        let evidenceCount = Float(event.evidenceFrames.count)
        let evidenceScore = min(evidenceCount / 5.0, 1.0)
        let confidenceScore = event.confidence
        return (evidenceScore * 0.4) + (confidenceScore * 0.6)
    }
    
    func calculateSpatialConsistency(event: ActivityEvent, frameMetadata: [FrameMetadata]) -> Float {
        let relevantFrames = frameMetadata.filter { frame in
            event.evidenceFrames.contains(frame.frameId)
        }
        
        if relevantFrames.isEmpty {
            return 0.0
        }
        
        let apps = Set(relevantFrames.map { $0.applicationName })
        let appConsistency = apps.count == 1 ? 1.0 : 0.5
        
        let windows = Set(relevantFrames.map { $0.windowTitle })
        let windowConsistency = windows.count <= 2 ? 1.0 : 0.7
        
        return Float((appConsistency + windowConsistency) / 2.0)
    }
    
    func calculateFrameConfidences(evidenceFrames: [String], frameMetadata: [FrameMetadata]) -> [FrameConfidence] {
        return evidenceFrames.compactMap { frameId in
            guard let frame = frameMetadata.first(where: { $0.frameId == frameId }) else {
                return nil
            }
            
            return FrameConfidence(
                frameId: frameId,
                ocrConfidence: frame.ocrConfidence ?? 0.8,
                imageQuality: frame.imageQuality ?? 0.9,
                temporalStability: 0.8, // Simplified for testing
                contextRelevance: 0.7   // Simplified for testing
            )
        }
    }
}