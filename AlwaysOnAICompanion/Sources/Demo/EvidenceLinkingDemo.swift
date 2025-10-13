import Foundation
import Shared

/// Demo showcasing evidence linking and traceability functionality
public class EvidenceLinkingDemo {
    
    private let evidenceLinker: EvidenceLinker
    private let reportGenerator: ReportGenerator
    
    public init() {
        self.evidenceLinker = EvidenceLinker()
        self.reportGenerator = ReportGenerator()
    }
    
    /// Run comprehensive evidence linking demonstration
    public func runDemo() {
        print("🔗 Evidence Linking and Traceability Demo")
        print("==========================================\n")
        
        // Create test data
        let (summary, events, frameMetadata) = createTestData()
        
        // Demonstrate evidence reference creation
        demonstrateEvidenceReferences(summary: summary, events: events, frameMetadata: frameMetadata)
        
        // Demonstrate bidirectional linking
        demonstrateBidirectionalLinking(summary: summary, events: events, frameMetadata: frameMetadata)
        
        // Demonstrate temporal correlation
        demonstrateTemporalCorrelation(summary: summary, frameMetadata: frameMetadata)
        
        // Demonstrate confidence propagation
        demonstrateConfidencePropagation(summary: summary, events: events, frameMetadata: frameMetadata)
        
        // Demonstrate evidence tracing
        demonstrateEvidenceTracing(summary: summary, events: events, frameMetadata: frameMetadata)
        
        // Demonstrate enhanced report generation
        demonstrateEnhancedReports(summary: summary, events: events, frameMetadata: frameMetadata)
        
        print("\n✅ Evidence linking demo completed successfully!")
    }
    
    private func demonstrateEvidenceReferences(
        summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata]
    ) {
        print("1. Evidence Reference Creation")
        print("------------------------------")
        
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        print("Summary ID: \(evidenceReference.summaryId)")
        print("Session ID: \(evidenceReference.sessionId)")
        print("Direct Evidence Frames: \(evidenceReference.directEvidenceFrames.count)")
        print("Correlated Frames: \(evidenceReference.correlatedFrames.count)")
        print("Event-Evidence Mappings: \(evidenceReference.eventEvidenceMap.count)")
        
        // Show evidence mapping details
        print("\nEvidence Mapping Details:")
        for (eventId, frameIds) in evidenceReference.eventEvidenceMap {
            print("  Event \(eventId): \(frameIds.joined(separator: ", "))")
        }
        
        print("\nCorrelated Frames (Top 3):")
        for correlatedFrame in evidenceReference.correlatedFrames.prefix(3) {
            print("  \(correlatedFrame.frameId): Score \(String(format: "%.2f", correlatedFrame.correlationScore))")
            print("    Reasons: \(correlatedFrame.correlationReasons.joined(separator: ", "))")
        }
        
        print()
    }
    
    private func demonstrateBidirectionalLinking(
        summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata]
    ) {
        print("2. Bidirectional Linking")
        print("------------------------")
        
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        let links = evidenceReference.bidirectionalLinks
        
        print("Summary → Events: \(links.summaryToEvents.count) events")
        print("Events → Summary: \(links.eventToSummary.count) mappings")
        print("Events → Frames: \(links.eventToFrames.count) mappings")
        print("Frames → Events: \(links.frameToEvents.count) mappings")
        
        // Demonstrate bidirectional navigation
        print("\nBidirectional Navigation Example:")
        if let firstEventId = links.summaryToEvents.first {
            print("  Summary → Event: \(firstEventId)")
            
            if let frameIds = links.eventToFrames[firstEventId] {
                print("  Event → Frames: \(frameIds.joined(separator: ", "))")
                
                if let firstFrameId = frameIds.first,
                   let backToEvents = links.frameToEvents[firstFrameId] {
                    print("  Frame → Events: \(backToEvents.joined(separator: ", "))")
                }
            }
        }
        
        print()
    }
    
    private func demonstrateTemporalCorrelation(
        summary: ActivitySummary,
        frameMetadata: [FrameMetadata]
    ) {
        print("3. Temporal Correlation Analysis")
        print("--------------------------------")
        
        let correlatedFrames = evidenceLinker.findTemporallyCorrelatedFrames(
            for: summary.session,
            in: frameMetadata
        )
        
        print("Total Correlated Frames: \(correlatedFrames.count)")
        print("Session Duration: \(formatDuration(summary.session.duration))")
        
        print("\nCorrelation Analysis:")
        for (index, frame) in correlatedFrames.enumerated() {
            let timeOffset = frame.timestamp.timeIntervalSince(summary.session.startTime)
            print("  \(index + 1). Frame \(frame.frameId)")
            print("     Score: \(String(format: "%.3f", frame.correlationScore))")
            print("     Time Offset: +\(String(format: "%.1f", timeOffset))s")
            print("     App: \(frame.applicationName)")
            print("     Reasons: \(frame.correlationReasons.joined(separator: ", "))")
        }
        
        print()
    }
    
    private func demonstrateConfidencePropagation(
        summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata]
    ) {
        print("4. Confidence Propagation")
        print("-------------------------")
        
        let confidencePropagation = evidenceLinker.calculateConfidencePropagation(
            summary: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        print("Overall Confidence: \(String(format: "%.1f", confidencePropagation.overallConfidence * 100))%")
        print("Summary Confidence: \(String(format: "%.1f", confidencePropagation.summaryConfidence.aggregatedConfidence * 100))%")
        
        print("\nConfidence Breakdown:")
        print("  Frame Confidence Avg: \(String(format: "%.1f", confidencePropagation.summaryConfidence.frameConfidenceAverage * 100))%")
        print("  Event Confidence Avg: \(String(format: "%.1f", confidencePropagation.summaryConfidence.eventConfidenceAverage * 100))%")
        print("  Temporal Consistency: \(String(format: "%.1f", confidencePropagation.summaryConfidence.temporalConsistency * 100))%")
        print("  Spatial Consistency: \(String(format: "%.1f", confidencePropagation.summaryConfidence.spatialConsistency * 100))%")
        print("  Evidence Completeness: \(String(format: "%.1f", confidencePropagation.summaryConfidence.evidenceCompleteness * 100))%")
        
        print("\nConfidence Factors:")
        for factor in confidencePropagation.confidenceFactors {
            let impact = factor.impact >= 0 ? "+\(String(format: "%.2f", factor.impact))" : String(format: "%.2f", factor.impact)
            print("  \(factor.name): \(impact) - \(factor.description)")
        }
        
        print("\nFrame-Level Confidence:")
        for frameConfidence in confidencePropagation.frameConfidences.prefix(3) {
            print("  \(frameConfidence.frameId):")
            print("    OCR: \(String(format: "%.1f", frameConfidence.ocrConfidence * 100))%")
            print("    Quality: \(String(format: "%.1f", frameConfidence.imageQuality * 100))%")
            print("    Stability: \(String(format: "%.1f", frameConfidence.temporalStability * 100))%")
            print("    Relevance: \(String(format: "%.1f", frameConfidence.contextRelevance * 100))%")
        }
        
        print()
    }
    
    private func demonstrateEvidenceTracing(
        summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata]
    ) {
        print("5. Evidence Tracing")
        print("-------------------")
        
        let evidenceReference = evidenceLinker.createEvidenceReferences(
            for: summary,
            events: events,
            frameMetadata: frameMetadata
        )
        
        let evidenceTrace = evidenceLinker.traceEvidencePath(
            summaryId: summary.id,
            evidenceReference: evidenceReference
        )
        
        print("Trace Complete: \(evidenceTrace.traceComplete ? "✅" : "❌")")
        print("Total Confidence: \(String(format: "%.1f", evidenceTrace.totalConfidence * 100))%")
        print("Trace Steps: \(evidenceTrace.tracePath.count)")
        
        print("\nEvidence Trace Path:")
        for (index, step) in evidenceTrace.tracePath.enumerated() {
            let levelIcon = step.level == .summary ? "📊" : step.level == .event ? "⚡" : "🖼️"
            print("  \(index + 1). \(levelIcon) \(step.level.rawValue.capitalized): \(step.id)")
            print("     Type: \(step.evidenceType.rawValue)")
            print("     Confidence: \(String(format: "%.1f", step.confidence * 100))%")
            print("     Description: \(step.description)")
        }
        
        print()
    }
    
    private func demonstrateEnhancedReports(
        summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata]
    ) {
        print("6. Enhanced Report Generation")
        print("-----------------------------")
        
        let report = ActivityReport(
            timeRange: DateInterval(start: summary.session.startTime, end: summary.session.endTime),
            reportType: .session,
            summaries: [summary],
            totalEvents: events.count,
            totalDuration: summary.session.duration,
            generatedAt: Date()
        )
        
        do {
            // Generate Markdown report with evidence
            let markdownReport = try reportGenerator.generateReport(
                report,
                format: .markdown,
                events: events,
                frameMetadata: frameMetadata
            )
            
            print("Markdown Report Generated:")
            print("Length: \(markdownReport.count) characters")
            print("Contains Evidence Section: \(markdownReport.contains("Evidence & Traceability") ? "✅" : "❌")")
            print("Contains Confidence Analysis: \(markdownReport.contains("Confidence Analysis") ? "✅" : "❌")")
            
            // Show excerpt of evidence section
            if let evidenceRange = markdownReport.range(of: "#### Evidence & Traceability") {
                let evidenceStart = evidenceRange.lowerBound
                let excerptEnd = markdownReport.index(evidenceStart, offsetBy: min(300, markdownReport.distance(from: evidenceStart, to: markdownReport.endIndex)))
                let excerpt = String(markdownReport[evidenceStart..<excerptEnd])
                print("\nEvidence Section Excerpt:")
                print(excerpt + "...")
            }
            
            // Generate JSON report with evidence
            let jsonReport = try reportGenerator.generateReport(
                report,
                format: .json,
                events: events,
                frameMetadata: frameMetadata
            )
            
            print("\nJSON Report Generated:")
            print("Length: \(jsonReport.count) characters")
            print("Contains Evidence Reference: \(jsonReport.contains("evidenceReference") ? "✅" : "❌")")
            print("Contains Evidence Trace: \(jsonReport.contains("evidenceTrace") ? "✅" : "❌")")
            
        } catch {
            print("❌ Error generating reports: \(error)")
        }
        
        print()
    }
    
    // MARK: - Test Data Creation
    
    private func createTestData() -> (ActivitySummary, [ActivityEvent], [FrameMetadata]) {
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
            ),
            FrameMetadata(
                frameId: "frame_005",
                timestamp: baseTime.addingTimeInterval(300),
                applicationName: "Safari",
                windowTitle: "Profile Settings - Example.com",
                ocrConfidence: 0.87,
                imageQuality: 0.92
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
                metadata: ["app_name": "Safari", "field_type": "email"]
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
                metadata: ["app_name": "Safari", "field_type": "password"]
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
                metadata: ["app_name": "Safari", "action": "submit"]
            ),
            ActivityEvent(
                id: "event_004",
                timestamp: baseTime.addingTimeInterval(250),
                type: .navigation,
                target: "profile_link",
                valueBefore: "Dashboard",
                valueAfter: "Profile Settings",
                confidence: 0.85,
                evidenceFrames: ["frame_003", "frame_004"],
                metadata: ["app_name": "Safari", "navigation_type": "click"]
            ),
            ActivityEvent(
                id: "event_005",
                timestamp: baseTime.addingTimeInterval(310),
                type: .fieldChange,
                target: "display_name_field",
                valueBefore: "John Doe",
                valueAfter: "John Smith",
                confidence: 0.92,
                evidenceFrames: ["frame_004", "frame_005"],
                metadata: ["app_name": "Safari", "field_type": "text"]
            )
        ]
        
        // Create activity session
        let session = ActivitySession(
            id: "session_001",
            startTime: baseTime,
            endTime: baseTime.addingTimeInterval(360),
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
                workflowPhase: "account_management",
                continuityScore: 0.85,
                relatedActivities: ["login", "profile_update"]
            )
        )
        
        // Create activity summary
        let summary = ActivitySummary(
            id: "summary_001",
            session: session,
            narrative: "User successfully logged into Example.com and updated their profile display name from 'John Doe' to 'John Smith'. The session involved form filling activities including email entry, password authentication, and profile modification.",
            keyEvents: Array(events.prefix(4)), // Use first 4 events as key events
            outcomes: ["Successful login", "Profile updated", "Display name changed"],
            context: context,
            confidence: 0.89
        )
        
        return (summary, events, frameMetadata)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

/// Convenience function to run the evidence linking demo
public func runEvidenceLinkingDemo() {
    let demo = EvidenceLinkingDemo()
    demo.runDemo()
}