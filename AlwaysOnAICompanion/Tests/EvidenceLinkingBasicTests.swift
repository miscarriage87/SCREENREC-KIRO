import XCTest
@testable import Shared

/// Basic tests for evidence linking functionality
class EvidenceLinkingBasicTests: XCTestCase {
    
    func testEvidenceLinkerCreation() {
        // Test that we can create an evidence linker
        let evidenceLinker = EvidenceLinker()
        XCTAssertNotNil(evidenceLinker)
    }
    
    func testBasicEvidenceReferenceCreation() {
        // Given
        let evidenceLinker = EvidenceLinker()
        let (summary, events, frameMetadata) = createSimpleTestData()
        
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
        XCTAssertGreaterThan(evidenceReference.confidencePropagation.summaryConfidence.aggregatedConfidence, 0.0)
    }
    
    func testBidirectionalLinking() {
        // Given
        let evidenceLinker = EvidenceLinker()
        let (summary, events, frameMetadata) = createSimpleTestData()
        
        // When
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        // Then
        let links = evidenceReference.bidirectionalLinks
        
        // Verify summary to events mapping
        XCTAssertEqual(Set(links.summaryToEvents), Set(summary.keyEvents.map { $0.id }))
        
        // Verify event to summary mapping
        for eventId in links.summaryToEvents {
            XCTAssertEqual(links.eventToSummary[eventId], summary.id)
        }
        
        // Verify bidirectional consistency
        for (frameId, eventIds) in links.frameToEvents {
            for eventId in eventIds {
                let eventFrames = links.eventToFrames[eventId] ?? []
                XCTAssertTrue(eventFrames.contains(frameId))
            }
        }
    }
    
    func testTemporalCorrelation() {
        // Given
        let evidenceLinker = EvidenceLinker()
        let (summary, _, frameMetadata) = createSimpleTestData()
        
        // When
        let correlatedFrames = evidenceLinker.findTemporallyCorrelatedFrames(
            for: summary.session,
            in: frameMetadata
        )
        
        // Then
        XCTAssertFalse(correlatedFrames.isEmpty)
        
        // Verify all frames are within session time range
        for frame in correlatedFrames {
            XCTAssertGreaterThanOrEqual(frame.timestamp, summary.session.startTime)
            XCTAssertLessThanOrEqual(frame.timestamp, summary.session.endTime)
        }
        
        // Verify correlation scores are valid
        for frame in correlatedFrames {
            XCTAssertGreaterThanOrEqual(frame.correlationScore, 0.0)
            XCTAssertLessThanOrEqual(frame.correlationScore, 1.0)
        }
    }
    
    func testEvidenceTracing() {
        // Given
        let evidenceLinker = EvidenceLinker()
        let (summary, events, frameMetadata) = createSimpleTestData()
        
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
    }
    
    func testEnhancedReportGeneration() {
        // Given
        let reportGenerator = ReportGenerator()
        let (summary, events, frameMetadata) = createSimpleTestData()
        
        let report = ActivityReport(
            timeRange: DateInterval(start: summary.session.startTime, end: summary.session.endTime),
            reportType: .session,
            summaries: [summary],
            totalEvents: events.count,
            totalDuration: summary.session.duration,
            generatedAt: Date()
        )
        
        // When & Then
        XCTAssertNoThrow {
            let markdownReport = try reportGenerator.generateReport(
                report,
                format: .markdown,
                events: events,
                frameMetadata: frameMetadata
            )
            
            XCTAssertFalse(markdownReport.isEmpty)
            XCTAssertTrue(markdownReport.contains("Evidence & Traceability"))
            
            let jsonReport = try reportGenerator.generateReport(
                report,
                format: .json,
                events: events,
                frameMetadata: frameMetadata
            )
            
            XCTAssertFalse(jsonReport.isEmpty)
            XCTAssertTrue(jsonReport.contains("evidenceReference"))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSimpleTestData() -> (ActivitySummary, [ActivityEvent], [FrameMetadata]) {
        let baseTime = Date().addingTimeInterval(-600) // 10 minutes ago
        
        // Create frame metadata
        let frameMetadata = [
            FrameMetadata(
                frameId: "frame_1",
                timestamp: baseTime.addingTimeInterval(60),
                applicationName: "Safari",
                windowTitle: "Test Page",
                ocrConfidence: 0.9,
                imageQuality: 0.95
            ),
            FrameMetadata(
                frameId: "frame_2",
                timestamp: baseTime.addingTimeInterval(120),
                applicationName: "Safari",
                windowTitle: "Test Page",
                ocrConfidence: 0.85,
                imageQuality: 0.9
            )
        ]
        
        // Create events
        let events = [
            ActivityEvent(
                id: "event_1",
                timestamp: baseTime.addingTimeInterval(90),
                type: .fieldChange,
                target: "test_field",
                valueBefore: "",
                valueAfter: "test_value",
                confidence: 0.9,
                evidenceFrames: ["frame_1", "frame_2"],
                metadata: ["app_name": "Safari"]
            )
        ]
        
        // Create session
        let session = ActivitySession(
            id: "session_1",
            startTime: baseTime,
            endTime: baseTime.addingTimeInterval(180),
            events: events,
            primaryApplication: "Safari",
            sessionType: .dataEntry
        )
        
        // Create context
        let context = TemporalContext(
            precedingSpans: [],
            followingSpans: [],
            relatedSessions: [],
            workflowContinuity: WorkflowContinuity(
                isPartOfLargerWorkflow: false,
                workflowPhase: nil,
                continuityScore: 0.8,
                relatedActivities: []
            )
        )
        
        // Create summary
        let summary = ActivitySummary(
            id: "summary_1",
            session: session,
            narrative: "Test activity summary",
            keyEvents: events,
            outcomes: ["Test completed"],
            context: context,
            confidence: 0.85
        )
        
        return (summary, events, frameMetadata)
    }
}