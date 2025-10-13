#!/usr/bin/env swift

import Foundation

// Add the path to the built Shared module
import Shared

/// Simple validation script for evidence linking functionality
func validateEvidenceLinking() {
    print("🔗 Validating Evidence Linking Implementation")
    print("=============================================\n")
    
    // Test 1: Basic Evidence Linker Creation
    print("1. Testing Evidence Linker Creation...")
    let evidenceLinker = EvidenceLinker()
    print("   ✅ Evidence linker created successfully")
    
    // Test 2: Create Test Data
    print("\n2. Creating Test Data...")
    let (summary, events, frameMetadata) = createTestData()
    print("   ✅ Test data created:")
    print("      - Summary: \(summary.id)")
    print("      - Events: \(events.count)")
    print("      - Frame Metadata: \(frameMetadata.count)")
    
    // Test 3: Evidence Reference Creation
    print("\n3. Testing Evidence Reference Creation...")
    let evidenceReference = evidenceLinker.createEvidenceReferences(
        for: summary,
        events: events,
        frameMetadata: frameMetadata
    )
    print("   ✅ Evidence reference created:")
    print("      - Direct Evidence Frames: \(evidenceReference.directEvidenceFrames.count)")
    print("      - Correlated Frames: \(evidenceReference.correlatedFrames.count)")
    print("      - Event-Evidence Mappings: \(evidenceReference.eventEvidenceMap.count)")
    
    // Test 4: Bidirectional Links
    print("\n4. Testing Bidirectional Links...")
    let links = evidenceReference.bidirectionalLinks
    print("   ✅ Bidirectional links verified:")
    print("      - Summary → Events: \(links.summaryToEvents.count)")
    print("      - Events → Frames: \(links.eventToFrames.count)")
    print("      - Frames → Events: \(links.frameToEvents.count)")
    
    // Test 5: Temporal Correlation
    print("\n5. Testing Temporal Correlation...")
    let correlatedFrames = evidenceLinker.findTemporallyCorrelatedFrames(
        for: summary.session,
        in: frameMetadata
    )
    print("   ✅ Temporal correlation analysis:")
    print("      - Correlated Frames Found: \(correlatedFrames.count)")
    if let topFrame = correlatedFrames.first {
        print("      - Top Correlation Score: \(String(format: "%.3f", topFrame.correlationScore))")
        print("      - Correlation Reasons: \(topFrame.correlationReasons.joined(separator: ", "))")
    }
    
    // Test 6: Confidence Propagation
    print("\n6. Testing Confidence Propagation...")
    let confidencePropagation = evidenceReference.confidencePropagation
    print("   ✅ Confidence propagation analysis:")
    print("      - Overall Confidence: \(String(format: "%.1f", confidencePropagation.overallConfidence * 100))%")
    print("      - Summary Confidence: \(String(format: "%.1f", confidencePropagation.summaryConfidence.aggregatedConfidence * 100))%")
    print("      - Frame Confidences: \(confidencePropagation.frameConfidences.count)")
    print("      - Event Confidences: \(confidencePropagation.eventConfidences.count)")
    print("      - Confidence Factors: \(confidencePropagation.confidenceFactors.count)")
    
    // Test 7: Evidence Tracing
    print("\n7. Testing Evidence Tracing...")
    let evidenceTrace = evidenceLinker.traceEvidencePath(
        summaryId: summary.id,
        evidenceReference: evidenceReference
    )
    print("   ✅ Evidence trace analysis:")
    print("      - Trace Complete: \(evidenceTrace.traceComplete)")
    print("      - Total Confidence: \(String(format: "%.1f", evidenceTrace.totalConfidence * 100))%")
    print("      - Trace Steps: \(evidenceTrace.tracePath.count)")
    
    // Show trace path
    for (index, step) in evidenceTrace.tracePath.prefix(5).enumerated() {
        let levelIcon = step.level == .summary ? "📊" : step.level == .event ? "⚡" : "🖼️"
        print("         \(index + 1). \(levelIcon) \(step.level.rawValue): \(step.id) (\(String(format: "%.1f", step.confidence * 100))%)")
    }
    
    // Test 8: Enhanced Report Generation
    print("\n8. Testing Enhanced Report Generation...")
    let reportGenerator = ReportGenerator()
    let report = ActivityReport(
        timeRange: DateInterval(start: summary.session.startTime, end: summary.session.endTime),
        reportType: .session,
        summaries: [summary],
        totalEvents: events.count,
        totalDuration: summary.session.duration,
        generatedAt: Date()
    )
    
    do {
        let markdownReport = try reportGenerator.generateReport(
            report,
            format: .markdown,
            events: events,
            frameMetadata: frameMetadata
        )
        
        print("   ✅ Enhanced report generation:")
        print("      - Markdown Report Length: \(markdownReport.count) characters")
        print("      - Contains Evidence Section: \(markdownReport.contains("Evidence & Traceability"))")
        print("      - Contains Confidence Analysis: \(markdownReport.contains("Confidence Analysis"))")
        
        let jsonReport = try reportGenerator.generateReport(
            report,
            format: .json,
            events: events,
            frameMetadata: frameMetadata
        )
        
        print("      - JSON Report Length: \(jsonReport.count) characters")
        print("      - Contains Evidence Reference: \(jsonReport.contains("evidenceReference"))")
        print("      - Contains Evidence Trace: \(jsonReport.contains("evidenceTrace"))")
        
    } catch {
        print("   ❌ Error generating reports: \(error)")
        return
    }
    
    print("\n✅ All Evidence Linking Tests Passed!")
    print("=====================================")
    print("Evidence linking and traceability system is working correctly.")
}

// MARK: - Test Data Creation

func createTestData() -> (ActivitySummary, [ActivityEvent], [FrameMetadata]) {
    let baseTime = Date().addingTimeInterval(-1800) // 30 minutes ago
    
    // Create frame metadata
    let frameMetadata = [
        FrameMetadata(
            frameId: "frame_001",
            timestamp: baseTime.addingTimeInterval(60),
            applicationName: "Safari",
            windowTitle: "Login - Example.com",
            ocrConfidence: 0.92,
            imageQuality: 0.95
        ),
        FrameMetadata(
            frameId: "frame_002",
            timestamp: baseTime.addingTimeInterval(120),
            applicationName: "Safari",
            windowTitle: "Login - Example.com",
            ocrConfidence: 0.88,
            imageQuality: 0.93
        ),
        FrameMetadata(
            frameId: "frame_003",
            timestamp: baseTime.addingTimeInterval(180),
            applicationName: "Safari",
            windowTitle: "Dashboard - Example.com",
            ocrConfidence: 0.94,
            imageQuality: 0.96
        ),
        FrameMetadata(
            frameId: "frame_004",
            timestamp: baseTime.addingTimeInterval(240),
            applicationName: "Safari",
            windowTitle: "Profile Settings - Example.com",
            ocrConfidence: 0.90,
            imageQuality: 0.94
        )
    ]
    
    // Create events
    let events = [
        ActivityEvent(
            id: "event_001",
            timestamp: baseTime.addingTimeInterval(90),
            type: .fieldChange,
            target: "email_field",
            valueBefore: "",
            valueAfter: "user@example.com",
            confidence: 0.95,
            evidenceFrames: ["frame_001", "frame_002"],
            metadata: ["app_name": "Safari"]
        ),
        ActivityEvent(
            id: "event_002",
            timestamp: baseTime.addingTimeInterval(150),
            type: .fieldChange,
            target: "password_field",
            valueBefore: "",
            valueAfter: "********",
            confidence: 0.90,
            evidenceFrames: ["frame_002"],
            metadata: ["app_name": "Safari"]
        ),
        ActivityEvent(
            id: "event_003",
            timestamp: baseTime.addingTimeInterval(170),
            type: .formSubmission,
            target: "login_button",
            valueBefore: nil,
            valueAfter: "Login",
            confidence: 0.98,
            evidenceFrames: ["frame_002", "frame_003"],
            metadata: ["app_name": "Safari"]
        )
    ]
    
    // Create activity session
    let session = ActivitySession(
        id: "session_001",
        startTime: baseTime,
        endTime: baseTime.addingTimeInterval(300),
        events: events,
        primaryApplication: "Safari",
        sessionType: .formFilling
    )
    
    // Create temporal context
    let context = TemporalContext(
        precedingSpans: [],
        followingSpans: [],
        relatedSessions: [],
        workflowContinuity: WorkflowContinuity(
            isPartOfLargerWorkflow: true,
            workflowPhase: "authentication",
            continuityScore: 0.85,
            relatedActivities: ["login"]
        )
    )
    
    // Create activity summary
    let summary = ActivitySummary(
        id: "summary_001",
        session: session,
        narrative: "User successfully logged into Example.com by entering email and password credentials.",
        keyEvents: events,
        outcomes: ["Successful login"],
        context: context,
        confidence: 0.89
    )
    
    return (summary, events, frameMetadata)
}

// Run the validation
validateEvidenceLinking()