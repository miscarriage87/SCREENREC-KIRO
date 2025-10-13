import Foundation
import Shared

/// Demo program to test the Activity Summarization Engine
struct ActivitySummarizerDemo {
    static func runDemo() async {
        print("🤖 Activity Summarization Engine Demo")
        print("=====================================\n")
        
        do {
            try await runDemoInternal()
        } catch {
            print("❌ Demo failed with error: \(error)")
        }
    }
    
    static func runDemoInternal() async throws {
        // Create sample events for demonstration
        let baseTime = Date()
        let sampleEvents = createSampleEvents(baseTime: baseTime)
        
        // Create sample spans for context
        let sampleSpans = createSampleSpans(baseTime: baseTime)
        
        // Initialize the activity summarizer
        let summarizer = ActivitySummarizer()
        
        print("1. Testing Event Grouping and Session Creation")
        print("==============================================")
        
        let timeRange = DateInterval(
            start: baseTime.addingTimeInterval(-60),
            end: baseTime.addingTimeInterval(300)
        )
        
        let summaries = try summarizer.summarizeActivity(
            events: sampleEvents,
            existingSpans: sampleSpans,
            timeRange: timeRange
        )
        
        print("✅ Generated \(summaries.count) activity summaries")
        
        for (index, summary) in summaries.enumerated() {
            print("\n📋 Summary \(index + 1):")
            print("   Session Type: \(summary.session.sessionType.rawValue)")
            print("   Duration: \(formatDuration(summary.session.duration))")
            print("   Events: \(summary.session.events.count)")
            print("   Primary App: \(summary.session.primaryApplication ?? "Unknown")")
            print("   Confidence: \(String(format: "%.1f", summary.confidence * 100))%")
            print("   Workflow Continuity: \(summary.context.workflowContinuity.isPartOfLargerWorkflow)")
            
            if let phase = summary.context.workflowContinuity.workflowPhase {
                print("   Workflow Phase: \(phase)")
            }
        }
        
        print("\n2. Testing Template Engine")
        print("==========================")
        
        if let firstSummary = summaries.first {
            let templateEngine = SummaryTemplateEngine()
            
            // Test different template types
            let templateTypes: [SummaryTemplateEngine.TemplateType] = [.narrative, .structured, .playbook, .timeline, .executive]
            
            for templateType in templateTypes {
                print("\n📝 \(templateType.rawValue.capitalized) Template:")
                print("   " + String(repeating: "-", count: templateType.rawValue.count + 10))
                
                let templatedSummary = try templateEngine.generateSummary(
                    session: firstSummary.session,
                    context: firstSummary.context,
                    templateType: templateType
                )
                
                // Show first few lines of the narrative
                let lines = templatedSummary.narrative.components(separatedBy: .newlines)
                let previewLines = Array(lines.prefix(3))
                
                for line in previewLines {
                    if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("   \(line)")
                    }
                }
                
                if lines.count > 3 {
                    print("   ... (\(lines.count - 3) more lines)")
                }
                
                print("   Confidence: \(String(format: "%.1f", templatedSummary.confidence * 100))%")
            }
        }
        
        print("\n3. Testing Report Generation")
        print("============================")
        
        let report = try summarizer.generateReport(
            events: sampleEvents,
            spans: sampleSpans,
            timeRange: timeRange,
            reportType: .daily
        )
        
        print("📊 Daily Report Generated:")
        print("   Time Range: \(formatDate(report.timeRange.start)) - \(formatDate(report.timeRange.end))")
        print("   Total Events: \(report.totalEvents)")
        print("   Total Duration: \(formatDuration(report.totalDuration))")
        print("   Summaries: \(report.summaries.count)")
        print("   Generated At: \(formatDate(report.generatedAt))")
        
        print("\n4. Testing Session Grouper")
        print("===========================")
        
        let grouperConfig = ActivitySessionGrouper.Configuration()
        let grouper = ActivitySessionGrouper(configuration: grouperConfig)
        
        let sessions = try grouper.groupEventsIntoSessions(sampleEvents)
        
        print("🔗 Session Grouping Results:")
        print("   Input Events: \(sampleEvents.count)")
        print("   Generated Sessions: \(sessions.count)")
        
        for (index, session) in sessions.enumerated() {
            print("\n   Session \(index + 1):")
            print("     Type: \(session.sessionType.rawValue)")
            print("     Events: \(session.events.count)")
            print("     Duration: \(formatDuration(session.duration))")
            print("     App: \(session.primaryApplication ?? "Unknown")")
        }
        
        print("\n5. Testing Temporal Context Analysis")
        print("====================================")
        
        let contextAnalyzer = TemporalContextAnalyzer()
        
        if let firstSession = sessions.first {
            let context = try contextAnalyzer.analyzeTemporalContext(
                session: firstSession,
                existingSpans: sampleSpans
            )
            
            print("🕒 Temporal Context Analysis:")
            print("   Preceding Spans: \(context.precedingSpans.count)")
            print("   Following Spans: \(context.followingSpans.count)")
            print("   Part of Larger Workflow: \(context.workflowContinuity.isPartOfLargerWorkflow)")
            print("   Continuity Score: \(String(format: "%.1f", context.workflowContinuity.continuityScore * 100))%")
            
            if let phase = context.workflowContinuity.workflowPhase {
                print("   Workflow Phase: \(phase)")
            }
            
            if !context.workflowContinuity.relatedActivities.isEmpty {
                print("   Related Activities: \(context.workflowContinuity.relatedActivities.joined(separator: ", "))")
            }
        }
        
        print("\n✅ Activity Summarization Engine Demo Complete!")
        print("All components are working correctly. 🎉")
    }
    
    static func createSampleEvents(baseTime: Date) -> [ActivityEvent] {
        return [
            ActivityEvent(
                id: "event1",
                timestamp: baseTime,
                type: .fieldChange,
                target: "email_field",
                valueBefore: "",
                valueAfter: "user@example.com",
                confidence: 0.9,
                evidenceFrames: ["frame1"],
                metadata: ["app_name": "Safari", "window_title": "Login Page"]
            ),
            ActivityEvent(
                id: "event2",
                timestamp: baseTime.addingTimeInterval(30),
                type: .fieldChange,
                target: "password_field",
                valueBefore: "",
                valueAfter: "********",
                confidence: 0.85,
                evidenceFrames: ["frame2"],
                metadata: ["app_name": "Safari", "window_title": "Login Page"]
            ),
            ActivityEvent(
                id: "event3",
                timestamp: baseTime.addingTimeInterval(60),
                type: .formSubmission,
                target: "login_form",
                valueAfter: "submitted",
                confidence: 0.95,
                evidenceFrames: ["frame3"],
                metadata: ["app_name": "Safari", "window_title": "Login Page"]
            ),
            ActivityEvent(
                id: "event4",
                timestamp: baseTime.addingTimeInterval(90),
                type: .navigation,
                target: "dashboard",
                valueAfter: "dashboard_page",
                confidence: 0.8,
                evidenceFrames: ["frame4"],
                metadata: ["app_name": "Safari", "window_title": "Dashboard"]
            ),
            ActivityEvent(
                id: "event5",
                timestamp: baseTime.addingTimeInterval(120),
                type: .click,
                target: "profile_button",
                confidence: 0.75,
                evidenceFrames: ["frame5"],
                metadata: ["app_name": "Safari", "window_title": "Dashboard"]
            )
        ]
    }
    
    static func createSampleSpans(baseTime: Date) -> [Span] {
        return [
            Span(
                kind: "research",
                startTime: baseTime.addingTimeInterval(-1800), // 30 minutes before
                endTime: baseTime.addingTimeInterval(-300), // 5 minutes before
                title: "Research authentication methods",
                summaryMarkdown: "Researched different authentication approaches for the application",
                tags: ["research", "authentication", "security"]
            ),
            Span(
                kind: "profile_setup",
                startTime: baseTime.addingTimeInterval(200), // After the events
                endTime: baseTime.addingTimeInterval(500),
                title: "Complete user profile setup",
                summaryMarkdown: "Filled out user profile information and preferences",
                tags: ["profile", "setup", "user_data"]
            )
        ]
    }
    
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}