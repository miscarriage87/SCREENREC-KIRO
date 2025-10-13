import Foundation

/// Multi-format report generator that produces Markdown, CSV, and JSON outputs
public class ReportGenerator {
    
    /// Available report formats
    public enum ReportFormat: String, CaseIterable {
        case markdown = "markdown"
        case csv = "csv"
        case json = "json"
        case html = "html"
    }
    
    /// Report generation configuration
    public struct Configuration {
        /// Include evidence references in reports
        public let includeEvidence: Bool
        /// Maximum number of events to include in detailed reports
        public let maxEventsInReport: Int
        /// Include confidence scores in output
        public let includeConfidenceScores: Bool
        /// Date format for timestamps
        public let dateFormat: String
        /// Include metadata in exports
        public let includeMetadata: Bool
        
        public init(
            includeEvidence: Bool = true,
            maxEventsInReport: Int = 100,
            includeConfidenceScores: Bool = true,
            dateFormat: String = "yyyy-MM-dd HH:mm:ss",
            includeMetadata: Bool = true
        ) {
            self.includeEvidence = includeEvidence
            self.maxEventsInReport = maxEventsInReport
            self.includeConfidenceScores = includeConfidenceScores
            self.dateFormat = dateFormat
            self.includeMetadata = includeMetadata
        }
    }
    
    private let configuration: Configuration
    private let templateEngine: SummaryTemplateEngine
    private let playbookCreator: PlaybookCreator
    private let evidenceLinker: EvidenceLinker
    
    /// Initialize the report generator
    /// - Parameter configuration: Configuration for report generation
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.templateEngine = SummaryTemplateEngine()
        self.playbookCreator = PlaybookCreator()
        self.evidenceLinker = EvidenceLinker()
    }
    
    /// Generate a comprehensive report in the specified format
    /// - Parameters:
    ///   - report: Activity report to format
    ///   - format: Output format for the report
    ///   - templateType: Template type for narrative generation
    ///   - events: All events for evidence linking (optional)
    ///   - frameMetadata: Frame metadata for evidence linking (optional)
    /// - Returns: Formatted report content
    public func generateReport(
        _ report: ActivityReport,
        format: ReportFormat,
        templateType: SummaryTemplateEngine.TemplateType = .narrative,
        events: [ActivityEvent] = [],
        frameMetadata: [FrameMetadata] = []
    ) throws -> String {
        
        switch format {
        case .markdown:
            return try generateMarkdownReport(report, templateType: templateType, events: events, frameMetadata: frameMetadata)
        case .csv:
            return try generateCSVReport(report, events: events, frameMetadata: frameMetadata)
        case .json:
            return try generateJSONReport(report, events: events, frameMetadata: frameMetadata)
        case .html:
            return try generateHTMLReport(report, templateType: templateType, events: events, frameMetadata: frameMetadata)
        }
    }
    
    /// Generate multiple format reports simultaneously
    /// - Parameters:
    ///   - report: Activity report to format
    ///   - formats: Array of formats to generate
    ///   - templateType: Template type for narrative generation
    /// - Returns: Dictionary of formatted reports by format
    public func generateMultipleFormats(
        _ report: ActivityReport,
        formats: [ReportFormat] = ReportFormat.allCases,
        templateType: SummaryTemplateEngine.TemplateType = .narrative
    ) throws -> [ReportFormat: String] {
        
        var results: [ReportFormat: String] = [:]
        
        for format in formats {
            results[format] = try generateReport(report, format: format, templateType: templateType)
        }
        
        return results
    }
    
    /// Generate a playbook report for step-by-step instructions
    /// - Parameters:
    ///   - summaries: Activity summaries to convert to playbooks
    ///   - format: Output format for the playbook
    /// - Returns: Formatted playbook content
    public func generatePlaybook(
        summaries: [ActivitySummary],
        format: ReportFormat = .markdown
    ) throws -> String {
        
        let playbook = try playbookCreator.createPlaybook(from: summaries)
        
        switch format {
        case .markdown:
            return try playbookCreator.formatAsMarkdown(playbook)
        case .json:
            return try playbookCreator.formatAsJSON(playbook)
        case .csv:
            return try playbookCreator.formatAsCSV(playbook)
        case .html:
            return try playbookCreator.formatAsHTML(playbook)
        }
    }
    
    // MARK: - Private Report Generation Methods
    
    private func generateMarkdownReport(
        _ report: ActivityReport,
        templateType: SummaryTemplateEngine.TemplateType,
        events: [ActivityEvent] = [],
        frameMetadata: [FrameMetadata] = []
    ) throws -> String {
        
        var markdown = ""
        
        // Report header
        markdown += "# Activity Report\n\n"
        markdown += generateReportMetadata(report)
        markdown += "\n"
        
        // Executive summary
        if !report.summaries.isEmpty {
            markdown += "## Executive Summary\n\n"
            markdown += generateExecutiveSummary(report)
            markdown += "\n"
        }
        
        // Detailed summaries
        if !report.summaries.isEmpty {
            markdown += "## Activity Details\n\n"
            
            for (index, summary) in report.summaries.enumerated() {
                markdown += "### Session \(index + 1): \(summary.session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)\n\n"
                
                // Use template engine to generate narrative
                let narrativeSummary = try templateEngine.generateSummary(
                    session: summary.session,
                    context: summary.context,
                    templateType: templateType
                )
                
                markdown += narrativeSummary.narrative
                markdown += "\n\n"
                
                // Add evidence references if configured
                if configuration.includeEvidence && !summary.keyEvents.isEmpty {
                    markdown += try generateEvidenceSection(
                        for: summary,
                        events: events,
                        frameMetadata: frameMetadata,
                        format: .markdown
                    )
                }
            }
        }
        
        // Statistics table
        markdown += "## Statistics\n\n"
        markdown += generateStatisticsTable(report)
        markdown += "\n"
        
        return markdown
    }
    
    private func generateCSVReport(_ report: ActivityReport, events: [ActivityEvent] = [], frameMetadata: [FrameMetadata] = []) throws -> String {
        var csv = ""
        
        // CSV header
        var headers = [
            "session_id",
            "session_type",
            "start_time",
            "end_time",
            "duration_seconds",
            "event_count",
            "primary_application"
        ]
        
        if configuration.includeConfidenceScores {
            headers.append("confidence_score")
        }
        
        if configuration.includeMetadata {
            headers.append("outcomes")
        }
        
        if configuration.includeEvidence {
            headers.append("evidence_frames")
            headers.append("evidence_trace_confidence")
        }
        
        csv += headers.joined(separator: ",") + "\n"
        
        // CSV data rows
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = configuration.dateFormat
        
        for summary in report.summaries {
            var row = [
                summary.session.id,
                summary.session.sessionType.rawValue,
                dateFormatter.string(from: summary.session.startTime),
                dateFormatter.string(from: summary.session.endTime),
                String(format: "%.1f", summary.session.duration),
                String(summary.session.events.count),
                summary.session.primaryApplication ?? ""
            ]
            
            if configuration.includeConfidenceScores {
                row.append(String(format: "%.3f", summary.confidence))
            }
            
            if configuration.includeMetadata {
                row.append("\"" + summary.outcomes.joined(separator: "; ") + "\"")
            }
            
            if configuration.includeEvidence && !events.isEmpty && !frameMetadata.isEmpty {
                let evidenceReference = evidenceLinker.createEvidenceReferences(
                    for: summary,
                    events: events,
                    frameMetadata: frameMetadata
                )
                
                let evidenceTrace = evidenceLinker.traceEvidencePath(
                    summaryId: summary.id,
                    evidenceReference: evidenceReference
                )
                
                row.append("\"" + evidenceReference.directEvidenceFrames.joined(separator: "; ") + "\"")
                row.append(String(format: "%.3f", evidenceTrace.totalConfidence))
            } else if configuration.includeEvidence {
                row.append("\"" + summary.keyEvents.flatMap { $0.evidenceFrames }.joined(separator: "; ") + "\"")
                row.append("0.000")
            }
            
            csv += row.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    private func generateJSONReport(_ report: ActivityReport, events: [ActivityEvent] = [], frameMetadata: [FrameMetadata] = []) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Generate evidence references for each summary if data is available
        var evidenceReferences: [String: EvidenceReference] = [:]
        if !events.isEmpty && !frameMetadata.isEmpty {
            for summary in report.summaries {
                let evidenceReference = evidenceLinker.createEvidenceReferences(
                    for: summary,
                    events: events,
                    frameMetadata: frameMetadata
                )
                evidenceReferences[summary.id] = evidenceReference
            }
        }
        
        let reportData = ReportData(
            metadata: ReportMetadata(
                timeRange: report.timeRange,
                reportType: report.reportType.rawValue,
                totalEvents: report.totalEvents,
                totalDuration: report.totalDuration,
                generatedAt: report.generatedAt,
                summaryCount: report.summaries.count
            ),
            summaries: report.summaries.map { summary in
                let evidenceReference = evidenceReferences[summary.id]
                let evidenceTrace = evidenceReference.map { ref in
                    evidenceLinker.traceEvidencePath(summaryId: summary.id, evidenceReference: ref)
                }
                
                return SummaryData(
                    id: summary.id,
                    sessionId: summary.session.id,
                    sessionType: summary.session.sessionType.rawValue,
                    startTime: summary.session.startTime,
                    endTime: summary.session.endTime,
                    duration: summary.session.duration,
                    eventCount: summary.session.events.count,
                    primaryApplication: summary.session.primaryApplication,
                    narrative: summary.narrative,
                    outcomes: summary.outcomes,
                    confidence: configuration.includeConfidenceScores ? summary.confidence : nil,
                    keyEvents: configuration.includeEvidence ? summary.keyEvents.map { event in
                        EventData(
                            id: event.id,
                            timestamp: event.timestamp,
                            type: event.type.rawValue,
                            target: event.target,
                            valueBefore: event.valueBefore,
                            valueAfter: event.valueAfter,
                            confidence: configuration.includeConfidenceScores ? event.confidence : nil,
                            evidenceFrames: event.evidenceFrames
                        )
                    } : nil,
                    evidenceReference: configuration.includeEvidence ? evidenceReference : nil,
                    evidenceTrace: configuration.includeEvidence ? evidenceTrace : nil
                )
            }
        )
        
        let jsonData = try encoder.encode(reportData)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
    
    private func generateHTMLReport(
        _ report: ActivityReport,
        templateType: SummaryTemplateEngine.TemplateType,
        events: [ActivityEvent] = [],
        frameMetadata: [FrameMetadata] = []
    ) throws -> String {
        
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Activity Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
                .header { border-bottom: 2px solid #007AFF; padding-bottom: 20px; margin-bottom: 30px; }
                .summary { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
                .session { border-left: 4px solid #007AFF; padding-left: 20px; margin: 20px 0; }
                .evidence { background: #fff3cd; padding: 10px; border-radius: 4px; margin: 10px 0; }
                .stats-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                .stats-table th, .stats-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                .stats-table th { background-color: #f2f2f2; }
                .confidence { color: #28a745; font-weight: bold; }
            </style>
        </head>
        <body>
        """
        
        // Header
        html += "<div class=\"header\">"
        html += "<h1>Activity Report</h1>"
        html += generateReportMetadata(report).replacingOccurrences(of: "\n", with: "<br>")
        html += "</div>"
        
        // Executive summary
        if !report.summaries.isEmpty {
            html += "<div class=\"summary\">"
            html += "<h2>Executive Summary</h2>"
            html += "<p>" + generateExecutiveSummary(report).replacingOccurrences(of: "\n", with: "<br>") + "</p>"
            html += "</div>"
        }
        
        // Detailed summaries
        if !report.summaries.isEmpty {
            html += "<h2>Activity Details</h2>"
            
            for (index, summary) in report.summaries.enumerated() {
                html += "<div class=\"session\">"
                html += "<h3>Session \(index + 1): \(summary.session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)</h3>"
                
                let narrativeSummary = try templateEngine.generateSummary(
                    session: summary.session,
                    context: summary.context,
                    templateType: templateType
                )
                
                html += "<p>" + narrativeSummary.narrative.replacingOccurrences(of: "\n", with: "<br>") + "</p>"
                
                if configuration.includeEvidence && !summary.keyEvents.isEmpty {
                    html += try generateEvidenceSection(
                        for: summary,
                        events: events,
                        frameMetadata: frameMetadata,
                        format: .html
                    )
                }
                
                html += "</div>"
            }
        }
        
        // Statistics
        html += "<h2>Statistics</h2>"
        html += generateStatisticsHTMLTable(report)
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - Helper Methods
    
    private func generateReportMetadata(_ report: ActivityReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = configuration.dateFormat
        
        var metadata = ""
        metadata += "**Report Type:** \(report.reportType.rawValue.capitalized)\n"
        metadata += "**Time Range:** \(dateFormatter.string(from: report.timeRange.start)) - \(dateFormatter.string(from: report.timeRange.end))\n"
        metadata += "**Duration:** \(formatDuration(report.totalDuration))\n"
        metadata += "**Total Events:** \(report.totalEvents)\n"
        metadata += "**Sessions:** \(report.summaries.count)\n"
        metadata += "**Generated:** \(dateFormatter.string(from: report.generatedAt))\n"
        
        return metadata
    }
    
    private func generateExecutiveSummary(_ report: ActivityReport) -> String {
        let totalSessions = report.summaries.count
        let avgDuration = totalSessions > 0 ? report.totalDuration / Double(totalSessions) : 0
        let avgEvents = totalSessions > 0 ? Double(report.totalEvents) / Double(totalSessions) : 0
        
        var summary = ""
        summary += "This report covers \(totalSessions) activity session\(totalSessions == 1 ? "" : "s") "
        summary += "over \(formatDuration(report.totalDuration)) with \(report.totalEvents) total events. "
        summary += "Average session duration was \(formatDuration(avgDuration)) "
        summary += "with \(String(format: "%.1f", avgEvents)) events per session."
        
        // Add session type breakdown
        let sessionTypes = Dictionary(grouping: report.summaries) { $0.session.sessionType }
        if sessionTypes.count > 1 {
            summary += "\n\nSession breakdown: "
            let breakdown = sessionTypes.map { type, summaries in
                "\(summaries.count) \(type.rawValue.replacingOccurrences(of: "_", with: " "))"
            }.joined(separator: ", ")
            summary += breakdown + "."
        }
        
        return summary
    }
    
    private func generateStatisticsTable(_ report: ActivityReport) -> String {
        var table = "| Metric | Value |\n"
        table += "|--------|-------|\n"
        table += "| Total Sessions | \(report.summaries.count) |\n"
        table += "| Total Duration | \(formatDuration(report.totalDuration)) |\n"
        table += "| Total Events | \(report.totalEvents) |\n"
        
        if !report.summaries.isEmpty {
            let avgDuration = report.totalDuration / Double(report.summaries.count)
            let avgEvents = Double(report.totalEvents) / Double(report.summaries.count)
            let avgConfidence = report.summaries.map { $0.confidence }.reduce(0, +) / Float(report.summaries.count)
            
            table += "| Average Session Duration | \(formatDuration(avgDuration)) |\n"
            table += "| Average Events per Session | \(String(format: "%.1f", avgEvents)) |\n"
            
            if configuration.includeConfidenceScores {
                table += "| Average Confidence | \(String(format: "%.1f", avgConfidence * 100))% |\n"
            }
        }
        
        return table
    }
    
    private func generateStatisticsHTMLTable(_ report: ActivityReport) -> String {
        var table = "<table class=\"stats-table\">"
        table += "<tr><th>Metric</th><th>Value</th></tr>"
        table += "<tr><td>Total Sessions</td><td>\(report.summaries.count)</td></tr>"
        table += "<tr><td>Total Duration</td><td>\(formatDuration(report.totalDuration))</td></tr>"
        table += "<tr><td>Total Events</td><td>\(report.totalEvents)</td></tr>"
        
        if !report.summaries.isEmpty {
            let avgDuration = report.totalDuration / Double(report.summaries.count)
            let avgEvents = Double(report.totalEvents) / Double(report.summaries.count)
            let avgConfidence = report.summaries.map { $0.confidence }.reduce(0, +) / Float(report.summaries.count)
            
            table += "<tr><td>Average Session Duration</td><td>\(formatDuration(avgDuration))</td></tr>"
            table += "<tr><td>Average Events per Session</td><td>\(String(format: "%.1f", avgEvents))</td></tr>"
            
            if configuration.includeConfidenceScores {
                table += "<tr><td>Average Confidence</td><td>\(String(format: "%.1f", avgConfidence * 100))%</td></tr>"
            }
        }
        
        table += "</table>"
        return table
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Generate evidence section with traceability information
    /// - Parameters:
    ///   - summary: Activity summary to generate evidence for
    ///   - events: All events for evidence linking
    ///   - frameMetadata: Frame metadata for evidence linking
    ///   - format: Output format (markdown or html)
    /// - Returns: Formatted evidence section
    private func generateEvidenceSection(
        for summary: ActivitySummary,
        events: [ActivityEvent],
        frameMetadata: [FrameMetadata],
        format: ReportFormat
    ) throws -> String {
        
        var evidenceSection = ""
        
        if !events.isEmpty && !frameMetadata.isEmpty {
            // Generate comprehensive evidence with traceability
            let evidenceReference = evidenceLinker.createEvidenceReferences(
                for: summary,
                events: events,
                frameMetadata: frameMetadata
            )
            
            let evidenceTrace = evidenceLinker.traceEvidencePath(
                summaryId: summary.id,
                evidenceReference: evidenceReference
            )
            
            switch format {
            case .markdown:
                evidenceSection += "#### Evidence & Traceability\n\n"
                evidenceSection += "**Trace Confidence:** \(String(format: "%.1f", evidenceTrace.totalConfidence * 100))%\n\n"
                
                // Direct evidence frames
                evidenceSection += "**Direct Evidence Frames:**\n"
                for frameId in evidenceReference.directEvidenceFrames.prefix(5) {
                    evidenceSection += "- `\(frameId)`"
                    if let frameMetadata = frameMetadata.first(where: { $0.frameId == frameId }) {
                        evidenceSection += " (\(frameMetadata.applicationName))"
                        if configuration.includeConfidenceScores, let ocrConfidence = frameMetadata.ocrConfidence {
                            evidenceSection += " - OCR: \(String(format: "%.1f", ocrConfidence * 100))%"
                        }
                    }
                    evidenceSection += "\n"
                }
                evidenceSection += "\n"
                
                // Correlated frames
                if !evidenceReference.correlatedFrames.isEmpty {
                    evidenceSection += "**Temporally Correlated Frames:**\n"
                    for correlatedFrame in evidenceReference.correlatedFrames.prefix(3) {
                        evidenceSection += "- `\(correlatedFrame.frameId)` "
                        evidenceSection += "(Score: \(String(format: "%.2f", correlatedFrame.correlationScore)), "
                        evidenceSection += "Reasons: \(correlatedFrame.correlationReasons.joined(separator: ", ")))\n"
                    }
                    evidenceSection += "\n"
                }
                
                // Confidence breakdown
                if configuration.includeConfidenceScores {
                    let confidencePropagation = evidenceReference.confidencePropagation
                    evidenceSection += "**Confidence Analysis:**\n"
                    evidenceSection += "- Frame Confidence: \(String(format: "%.1f", confidencePropagation.summaryConfidence.frameConfidenceAverage * 100))%\n"
                    evidenceSection += "- Event Confidence: \(String(format: "%.1f", confidencePropagation.summaryConfidence.eventConfidenceAverage * 100))%\n"
                    evidenceSection += "- Temporal Consistency: \(String(format: "%.1f", confidencePropagation.summaryConfidence.temporalConsistency * 100))%\n"
                    evidenceSection += "- Evidence Completeness: \(String(format: "%.1f", confidencePropagation.summaryConfidence.evidenceCompleteness * 100))%\n\n"
                }
                
            case .html:
                evidenceSection += "<div class=\"evidence\">"
                evidenceSection += "<h4>Evidence & Traceability</h4>"
                evidenceSection += "<p><strong>Trace Confidence:</strong> <span class=\"confidence\">\(String(format: "%.1f", evidenceTrace.totalConfidence * 100))%</span></p>"
                
                // Direct evidence frames
                evidenceSection += "<h5>Direct Evidence Frames</h5>"
                evidenceSection += "<ul>"
                for frameId in evidenceReference.directEvidenceFrames.prefix(5) {
                    evidenceSection += "<li><code>\(frameId)</code>"
                    if let frameMetadata = frameMetadata.first(where: { $0.frameId == frameId }) {
                        evidenceSection += " (\(frameMetadata.applicationName))"
                        if configuration.includeConfidenceScores, let ocrConfidence = frameMetadata.ocrConfidence {
                            evidenceSection += " - OCR: <span class=\"confidence\">\(String(format: "%.1f", ocrConfidence * 100))%</span>"
                        }
                    }
                    evidenceSection += "</li>"
                }
                evidenceSection += "</ul>"
                
                // Correlated frames
                if !evidenceReference.correlatedFrames.isEmpty {
                    evidenceSection += "<h5>Temporally Correlated Frames</h5>"
                    evidenceSection += "<ul>"
                    for correlatedFrame in evidenceReference.correlatedFrames.prefix(3) {
                        evidenceSection += "<li><code>\(correlatedFrame.frameId)</code> "
                        evidenceSection += "(Score: \(String(format: "%.2f", correlatedFrame.correlationScore)), "
                        evidenceSection += "Reasons: \(correlatedFrame.correlationReasons.joined(separator: ", ")))</li>"
                    }
                    evidenceSection += "</ul>"
                }
                
                // Confidence breakdown
                if configuration.includeConfidenceScores {
                    let confidencePropagation = evidenceReference.confidencePropagation
                    evidenceSection += "<h5>Confidence Analysis</h5>"
                    evidenceSection += "<ul>"
                    evidenceSection += "<li>Frame Confidence: <span class=\"confidence\">\(String(format: "%.1f", confidencePropagation.summaryConfidence.frameConfidenceAverage * 100))%</span></li>"
                    evidenceSection += "<li>Event Confidence: <span class=\"confidence\">\(String(format: "%.1f", confidencePropagation.summaryConfidence.eventConfidenceAverage * 100))%</span></li>"
                    evidenceSection += "<li>Temporal Consistency: <span class=\"confidence\">\(String(format: "%.1f", confidencePropagation.summaryConfidence.temporalConsistency * 100))%</span></li>"
                    evidenceSection += "<li>Evidence Completeness: <span class=\"confidence\">\(String(format: "%.1f", confidencePropagation.summaryConfidence.evidenceCompleteness * 100))%</span></li>"
                    evidenceSection += "</ul>"
                }
                
                evidenceSection += "</div>"
                
            default:
                // Fallback to simple evidence listing
                evidenceSection += "Evidence: "
                evidenceSection += summary.keyEvents.flatMap { $0.evidenceFrames }.joined(separator: ", ")
            }
        } else {
            // Fallback to basic evidence listing when full data is not available
            switch format {
            case .markdown:
                evidenceSection += "#### Evidence\n\n"
                for event in summary.keyEvents.prefix(5) {
                    if !event.evidenceFrames.isEmpty {
                        evidenceSection += "- **\(event.type.rawValue)**: Frames \(event.evidenceFrames.joined(separator: ", "))"
                        if configuration.includeConfidenceScores {
                            evidenceSection += " (Confidence: \(String(format: "%.1f", event.confidence * 100))%)"
                        }
                        evidenceSection += "\n"
                    }
                }
                evidenceSection += "\n"
                
            case .html:
                evidenceSection += "<div class=\"evidence\">"
                evidenceSection += "<h4>Evidence</h4>"
                evidenceSection += "<ul>"
                for event in summary.keyEvents.prefix(5) {
                    if !event.evidenceFrames.isEmpty {
                        evidenceSection += "<li><strong>\(event.type.rawValue):</strong> Frames \(event.evidenceFrames.joined(separator: ", "))"
                        if configuration.includeConfidenceScores {
                            evidenceSection += " <span class=\"confidence\">(Confidence: \(String(format: "%.1f", event.confidence * 100))%)</span>"
                        }
                        evidenceSection += "</li>"
                    }
                }
                evidenceSection += "</ul>"
                evidenceSection += "</div>"
                
            default:
                break
            }
        }
        
        return evidenceSection
    }
}

// MARK: - Data Transfer Objects for JSON Export

private struct ReportData: Codable {
    let metadata: ReportMetadata
    let summaries: [SummaryData]
}

private struct ReportMetadata: Codable {
    let timeRange: DateInterval
    let reportType: String
    let totalEvents: Int
    let totalDuration: TimeInterval
    let generatedAt: Date
    let summaryCount: Int
}

private struct SummaryData: Codable {
    let id: String
    let sessionId: String
    let sessionType: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let eventCount: Int
    let primaryApplication: String?
    let narrative: String
    let outcomes: [String]
    let confidence: Float?
    let keyEvents: [EventData]?
    let evidenceReference: EvidenceReference?
    let evidenceTrace: EvidenceTrace?
}

private struct EventData: Codable {
    let id: String
    let timestamp: Date
    let type: String
    let target: String
    let valueBefore: String?
    let valueAfter: String?
    let confidence: Float?
    let evidenceFrames: [String]
}

/// Errors that can occur during report generation
public enum ReportGenerationError: Error, LocalizedError {
    case invalidReportData(String)
    case formatNotSupported(String)
    case templateProcessingFailed(String)
    case exportFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidReportData(let message):
            return "Invalid report data: \(message)"
        case .formatNotSupported(let format):
            return "Format not supported: \(format)"
        case .templateProcessingFailed(let message):
            return "Template processing failed: \(message)"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }
}