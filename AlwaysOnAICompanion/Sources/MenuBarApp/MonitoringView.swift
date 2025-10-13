import SwiftUI
import Shared

struct MonitoringView: View {
    @StateObject private var systemMonitor = SystemMonitor.shared
    @StateObject private var logManager = LogManager.shared
    @State private var selectedTab = 0
    @State private var showingExportSheet = false
    @State private var showingLogExportSheet = false
    @State private var logFilter = LogFilter()
    @State private var refreshTimer: Timer?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SystemMetricsView()
                .environmentObject(systemMonitor)
                .tabItem {
                    Label("Metrics", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
            
            RecordingStatsView()
                .environmentObject(systemMonitor)
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }
                .tag(1)
            
            SystemHealthView()
                .environmentObject(systemMonitor)
                .tabItem {
                    Label("Health", systemImage: "heart.text.square")
                }
                .tag(2)
            
            LogViewerView()
                .environmentObject(logManager)
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
                .tag(3)
            
            DiagnosticsView()
                .environmentObject(systemMonitor)
                .environmentObject(logManager)
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
                .tag(4)
        }
        .frame(width: 800, height: 600)
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Trigger UI updates
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct SystemMetricsView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                
                // CPU Usage Card
                MetricCard(
                    title: "CPU Usage",
                    value: "\(systemMonitor.cpuUsage, specifier: "%.1f")%",
                    icon: "cpu",
                    color: cpuColor,
                    trend: .stable
                ) {
                    CPUUsageChart(usage: systemMonitor.cpuUsage)
                }
                
                // Memory Usage Card
                MetricCard(
                    title: "Memory Usage",
                    value: "\(systemMonitor.memoryUsage.percentage, specifier: "%.1f")%",
                    icon: "memorychip",
                    color: memoryColor,
                    trend: .stable
                ) {
                    MemoryUsageChart(memoryUsage: systemMonitor.memoryUsage)
                }
                
                // Disk Usage Card
                MetricCard(
                    title: "Disk Usage",
                    value: "\(systemMonitor.diskUsage.percentage, specifier: "%.1f")%",
                    icon: "internaldrive",
                    color: diskColor,
                    trend: .stable
                ) {
                    DiskUsageChart(diskUsage: systemMonitor.diskUsage)
                }
                
                // Network Usage Card
                MetricCard(
                    title: "Network I/O",
                    value: formatBytes(systemMonitor.networkUsage.bytesInPerSecond + systemMonitor.networkUsage.bytesOutPerSecond) + "/s",
                    icon: "network",
                    color: .blue,
                    trend: .stable
                ) {
                    NetworkUsageChart(networkUsage: systemMonitor.networkUsage)
                }
            }
            .padding()
        }
    }
    
    private var cpuColor: Color {
        switch systemMonitor.cpuUsage {
        case 0..<50: return .green
        case 50..<80: return .yellow
        default: return .red
        }
    }
    
    private var memoryColor: Color {
        switch systemMonitor.memoryUsage.percentage {
        case 0..<70: return .green
        case 70..<90: return .yellow
        default: return .red
        }
    }
    
    private var diskColor: Color {
        switch systemMonitor.diskUsage.percentage {
        case 0..<80: return .green
        case 80..<95: return .yellow
        default: return .red
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct RecordingStatsView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recording Overview
                GroupBox("Recording Overview") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(label: "Segments Created", value: "\(systemMonitor.recordingStats.segmentsCreated)")
                        StatRow(label: "Total Data Processed", value: formatBytes(systemMonitor.recordingStats.totalDataProcessed))
                        StatRow(label: "Recording Duration", value: formatDuration(systemMonitor.recordingStats.recordingDuration))
                        StatRow(label: "Current Segment Size", value: formatBytes(systemMonitor.recordingStats.currentSegmentSize))
                    }
                }
                
                // Performance Metrics
                GroupBox("Performance Metrics") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(label: "Average Processing Time", value: "\(systemMonitor.recordingStats.averageProcessingTime, specifier: "%.2f")s")
                        StatRow(label: "Error Count", value: "\(systemMonitor.recordingStats.errorsCount)")
                        
                        if systemMonitor.recordingStats.errorsCount > 0 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Recent errors detected - check logs for details")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Processing Pipeline Status
                GroupBox("Processing Pipeline") {
                    VStack(spacing: 12) {
                        PipelineStageView(name: "Screen Capture", status: .active, throughput: "30 FPS")
                        PipelineStageView(name: "Video Encoding", status: .active, throughput: "2.5 MB/s")
                        PipelineStageView(name: "Keyframe Extraction", status: .active, throughput: "1.2 FPS")
                        PipelineStageView(name: "OCR Processing", status: .active, throughput: "0.8 FPS")
                        PipelineStageView(name: "Event Detection", status: .active, throughput: "15 events/min")
                    }
                }
            }
            .padding()
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct SystemHealthView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Health Status
                GroupBox("System Health") {
                    HStack {
                        Image(systemName: healthIcon)
                            .font(.title)
                            .foregroundColor(healthColor)
                        
                        VStack(alignment: .leading) {
                            Text("Status: \(systemMonitor.systemHealth.rawValue.capitalized)")
                                .font(.headline)
                            Text("Last updated: \(Date(), formatter: timeFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Refresh") {
                            // Trigger manual refresh
                        }
                    }
                }
                
                // Active Alerts
                if !systemMonitor.activeAlerts.isEmpty {
                    GroupBox("Active Alerts") {
                        VStack(spacing: 8) {
                            ForEach(systemMonitor.activeAlerts) { alert in
                                AlertRow(alert: alert)
                            }
                        }
                    }
                } else {
                    GroupBox("Active Alerts") {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No active alerts")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Health Thresholds
                GroupBox("Health Thresholds") {
                    VStack(alignment: .leading, spacing: 8) {
                        ThresholdRow(label: "CPU Usage", current: systemMonitor.cpuUsage, threshold: systemMonitor.thresholds.maxCPUUsage, unit: "%")
                        ThresholdRow(label: "Memory Usage", current: systemMonitor.memoryUsage.percentage, threshold: systemMonitor.thresholds.maxMemoryUsage, unit: "%")
                        ThresholdRow(label: "Disk Usage", current: systemMonitor.diskUsage.percentage, threshold: systemMonitor.thresholds.maxDiskUsage, unit: "%")
                    }
                }
            }
            .padding()
        }
    }
    
    private var healthIcon: String {
        switch systemMonitor.systemHealth {
        case .healthy: return "heart.fill"
        case .degraded: return "heart"
        case .critical: return "heart.slash"
        }
    }
    
    private var healthColor: Color {
        switch systemMonitor.systemHealth {
        case .healthy: return .green
        case .degraded: return .yellow
        case .critical: return .red
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct LogViewerView: View {
    @EnvironmentObject var logManager: LogManager
    @State private var logFilter = LogFilter()
    @State private var showingExportSheet = false
    @State private var selectedExportFormat: LogExportFormat = .json
    
    var body: some View {
        VStack {
            // Filter Controls
            LogFilterView(filter: $logFilter) {
                logManager.applyFilter(logFilter)
            }
            
            Divider()
            
            // Log Entries
            List {
                ForEach(logManager.filteredEntries.isEmpty ? logManager.logEntries : logManager.filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                }
            }
            .listStyle(PlainListStyle())
            
            // Bottom Toolbar
            HStack {
                Text("\(logManager.filteredEntries.isEmpty ? logManager.logEntries.count : logManager.filteredEntries.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Clear") {
                    logManager.clearLogs()
                }
                
                Button("Export...") {
                    showingExportSheet = true
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingExportSheet) {
            LogExportSheet(
                format: $selectedExportFormat,
                onExport: { url, format in
                    do {
                        try logManager.exportLogs(to: url, format: format)
                    } catch {
                        print("Export failed: \(error)")
                    }
                }
            )
        }
    }
}

struct DiagnosticsView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var logManager: LogManager
    @State private var showingExportSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Information
                GroupBox("System Information") {
                    let diagnostics = systemMonitor.getSystemDiagnostics()
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "OS Version", value: diagnostics.systemInfo.osVersion)
                        InfoRow(label: "Host Name", value: diagnostics.systemInfo.hostName)
                        InfoRow(label: "Processor Count", value: "\(diagnostics.systemInfo.processorCount)")
                        InfoRow(label: "Physical Memory", value: formatBytes(Int64(diagnostics.systemInfo.physicalMemory)))
                        InfoRow(label: "System Uptime", value: formatDuration(diagnostics.systemInfo.uptime))
                    }
                }
                
                // Log Statistics
                GroupBox("Log Statistics") {
                    let stats = logManager.getLogStatistics()
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Total Log Entries", value: "\(stats.totalEntries)")
                        InfoRow(label: "Error Count", value: "\(stats.errorCount)")
                        InfoRow(label: "Recent Errors", value: "\(stats.recentErrorCount)")
                        
                        if let oldest = stats.oldestEntry {
                            InfoRow(label: "Oldest Entry", value: formatDate(oldest))
                        }
                        
                        if let newest = stats.newestEntry {
                            InfoRow(label: "Newest Entry", value: formatDate(newest))
                        }
                    }
                }
                
                // Performance Summary
                GroupBox("Performance Summary") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Average CPU Usage", value: "\(systemMonitor.cpuUsage, specifier: "%.1f")%")
                        InfoRow(label: "Memory Usage", value: "\(systemMonitor.memoryUsage.percentage, specifier: "%.1f")%")
                        InfoRow(label: "Disk I/O", value: "\(formatBytes(systemMonitor.diskUsage.readBytesPerSecond + systemMonitor.diskUsage.writeBytesPerSecond))/s")
                        InfoRow(label: "Recording Segments", value: "\(systemMonitor.recordingStats.segmentsCreated)")
                        InfoRow(label: "Processing Errors", value: "\(systemMonitor.recordingStats.errorsCount)")
                    }
                }
                
                // Export Actions
                GroupBox("Export & Diagnostics") {
                    VStack(spacing: 12) {
                        Button("Export Full Diagnostics Report") {
                            exportDiagnosticsReport()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        HStack {
                            Button("Export System Metrics") {
                                exportSystemMetrics()
                            }
                            
                            Button("Export Logs") {
                                exportLogs()
                            }
                            
                            Button("Generate Support Bundle") {
                                generateSupportBundle()
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func exportDiagnosticsReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "diagnostics-report-\(Date().timeIntervalSince1970).json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = systemMonitor.exportDiagnostics() {
                    do {
                        try data.write(to: url)
                    } catch {
                        print("Failed to export diagnostics: \(error)")
                    }
                }
            }
        }
    }
    
    private func exportSystemMetrics() {
        // Implementation for exporting system metrics
        print("Exporting system metrics...")
    }
    
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "logs-export-\(Date().timeIntervalSince1970).json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try logManager.exportLogs(to: url, format: .json)
                } catch {
                    print("Failed to export logs: \(error)")
                }
            }
        }
    }
    
    private func generateSupportBundle() {
        // Implementation for generating comprehensive support bundle
        print("Generating support bundle...")
    }
}

// MARK: - Supporting Views

struct MetricCard<Content: View>: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: MetricTrend
    let content: Content
    
    init(title: String, value: String, icon: String, color: Color, trend: MetricTrend, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.trend = trend
        self.content = content()
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                
                content
                    .frame(height: 60)
            }
        }
    }
}

enum MetricTrend {
    case up, down, stable
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PipelineStageView: View {
    let name: String
    let status: PipelineStatus
    let throughput: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(name)
            
            Spacer()
            
            Text(throughput)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

enum PipelineStatus {
    case active, idle, error
    
    var color: Color {
        switch self {
        case .active: return .green
        case .idle: return .yellow
        case .error: return .red
        }
    }
}

struct AlertRow: View {
    let alert: SystemAlert
    
    var body: some View {
        HStack {
            Image(systemName: alert.severity.icon)
                .foregroundColor(alert.severity.color)
            
            VStack(alignment: .leading) {
                Text(alert.title)
                    .fontWeight(.medium)
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(alert.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ThresholdRow: View {
    let label: String
    let current: Double
    let threshold: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
            
            Spacer()
            
            Text("\(current, specifier: "%.1f")\(unit) / \(threshold, specifier: "%.0f")\(unit)")
                .foregroundColor(current > threshold ? .red : .green)
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top) {
            Circle()
                .fill(entry.level.color)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(entry.level.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(entry.level.color.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(entry.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                
                if !entry.file.isEmpty {
                    Text("\(entry.file):\(entry.line)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct LogFilterView: View {
    @Binding var filter: LogFilter
    let onApply: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Search logs...", text: $filter.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Apply") {
                    onApply()
                }
                
                Button("Clear") {
                    filter = LogFilter()
                    onApply()
                }
            }
            
            // Additional filter controls could go here
        }
        .padding()
    }
}

struct LogExportSheet: View {
    @Binding var format: LogExportFormat
    let onExport: (URL, LogExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Logs")
                .font(.headline)
            
            Picker("Format", selection: $format) {
                Text("JSON").tag(LogExportFormat.json)
                Text("CSV").tag(LogExportFormat.csv)
                Text("Text").tag(LogExportFormat.text)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Export") {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [format.contentType]
                    panel.nameFieldStringValue = "logs-export.\(format.fileExtension)"
                    
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            onExport(url, format)
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}

// MARK: - Chart Views (Simplified)

struct CPUUsageChart: View {
    let usage: Double
    
    var body: some View {
        // Simplified chart - in a real implementation, use Charts framework
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: geometry.size.width * (usage / 100), height: geometry.size.height)
        }
    }
}

struct MemoryUsageChart: View {
    let memoryUsage: MemoryUsage
    
    var body: some View {
        // Simplified chart
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.green.opacity(0.3))
                .frame(width: geometry.size.width * (memoryUsage.percentage / 100), height: geometry.size.height)
        }
    }
}

struct DiskUsageChart: View {
    let diskUsage: DiskUsage
    
    var body: some View {
        // Simplified chart
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.orange.opacity(0.3))
                .frame(width: geometry.size.width * (diskUsage.percentage / 100), height: geometry.size.height)
        }
    }
}

struct NetworkUsageChart: View {
    let networkUsage: NetworkUsage
    
    var body: some View {
        // Simplified chart
        GeometryReader { geometry in
            HStack(spacing: 2) {
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.6)
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.8)
            }
        }
    }
}

// MARK: - Extensions

extension SystemAlert.AlertSeverity {
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

extension OSLogType {
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .default: return .primary
        case .error: return .orange
        case .fault: return .red
        default: return .primary
        }
    }
}

extension LogExportFormat {
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .text: return "txt"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .text: return .plainText
        }
    }
}

#Preview {
    MonitoringView()
}