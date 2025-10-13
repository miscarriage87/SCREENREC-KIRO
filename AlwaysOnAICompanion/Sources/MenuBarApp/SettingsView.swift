import SwiftUI
import Shared

struct SettingsView: View {
    @StateObject private var settingsController = SettingsController()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            RecordingSettingsView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }
            
            PrivacySettingsView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
            
            RetentionSettingsView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("Retention", systemImage: "clock.arrow.circlepath")
                }
            
            PluginSettingsView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("Plugins", systemImage: "puzzlepiece.extension")
                }
            
            DataManagementView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
            
            PerformanceSettingsView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }
            
            HotkeysSettingsView()
                .environmentObject(settingsController)
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
        }
        .frame(width: 650, height: 500)
        .onAppear {
            settingsController.loadSettings()
        }
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsController: SettingsController
    
    var body: some View {
        Form {
            Section("Application") {
                Toggle("Launch at startup", isOn: $settingsController.launchAtStartup)
                Toggle("Show menu bar icon", isOn: $settingsController.showMenuBarIcon)
                Toggle("Show notifications", isOn: $settingsController.showNotifications)
                Toggle("Enable logging", isOn: $settingsController.enableLogging)
            }
            
            Section("Logging") {
                HStack {
                    Text("Log level:")
                    Spacer()
                    Picker("", selection: $settingsController.logLevel) {
                        Text("Debug").tag("debug")
                        Text("Info").tag("info")
                        Text("Warning").tag("warning")
                        Text("Error").tag("error")
                    }
                    .pickerStyle(.menu)
                }
                
                Button("View Logs...") {
                    settingsController.viewLogs()
                }
                
                Button("Clear Logs") {
                    settingsController.clearLogs()
                }
            }
            
            Section("System") {
                HStack {
                    Text("Storage location:")
                    Spacer()
                    Button(settingsController.storageLocation) {
                        settingsController.selectStorageLocation()
                    }
                    .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Configuration:")
                    Spacer()
                    Button("Reset to Defaults") {
                        settingsController.resetToDefaults()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding()
    }
}

struct RecordingSettingsView: View {
    @EnvironmentObject var settingsController: SettingsController
    
    var body: some View {
        Form {
            Section("Display Selection") {
                ForEach(settingsController.availableDisplays, id: \.displayID) { display in
                    Toggle(display.name, isOn: Binding(
                        get: { settingsController.selectedDisplays.contains(display.displayID) },
                        set: { isSelected in
                            if isSelected {
                                settingsController.selectedDisplays.insert(display.displayID)
                            } else {
                                settingsController.selectedDisplays.remove(display.displayID)
                            }
                        }
                    ))
                }
            }
            
            Section("Quality Settings") {
                HStack {
                    Text("Frame rate:")
                    Spacer()
                    Picker("", selection: $settingsController.frameRate) {
                        Text("15 FPS").tag(15)
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack {
                    Text("Quality:")
                    Spacer()
                    Picker("", selection: $settingsController.quality) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack {
                    Text("Segment duration:")
                    Spacer()
                    Picker("", selection: $settingsController.segmentDuration) {
                        Text("1 min").tag(60)
                        Text("2 min").tag(120)
                        Text("5 min").tag(300)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject var settingsController: SettingsController
    
    var body: some View {
        Form {
            Section("PII Protection") {
                Toggle("Enable PII masking", isOn: $settingsController.enablePIIMasking)
                Toggle("Mask credit card numbers", isOn: $settingsController.maskCreditCards)
                Toggle("Mask social security numbers", isOn: $settingsController.maskSSN)
                Toggle("Mask email addresses", isOn: $settingsController.maskEmails)
            }
            
            Section("Application Allowlist") {
                Toggle("Enable application filtering", isOn: $settingsController.enableAppFiltering)
                
                if settingsController.enableAppFiltering {
                    List {
                        ForEach(settingsController.allowedApps, id: \.self) { app in
                            HStack {
                                Text(app)
                                Spacer()
                                Button("Remove") {
                                    settingsController.removeAllowedApp(app)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(height: 100)
                    
                    Button("Add Application...") {
                        settingsController.addAllowedApp()
                    }
                }
            }
            
            Section("Screen Filtering") {
                Toggle("Enable screen filtering", isOn: $settingsController.enableScreenFiltering)
                
                if settingsController.enableScreenFiltering {
                    ForEach(settingsController.availableDisplays, id: \.displayID) { display in
                        Toggle("Allow \(display.name)", isOn: Binding(
                            get: { settingsController.allowedScreens.contains(display.displayID) },
                            set: { isAllowed in
                                if isAllowed {
                                    settingsController.allowedScreens.insert(display.displayID)
                                } else {
                                    settingsController.allowedScreens.remove(display.displayID)
                                }
                            }
                        ))
                    }
                }
            }
        }
        .padding()
    }
}

struct PerformanceSettingsView: View {
    @EnvironmentObject var settingsController: SettingsController
    
    var body: some View {
        Form {
            Section("Performance Limits") {
                HStack {
                    Text("Max CPU usage:")
                    Spacer()
                    Slider(value: $settingsController.maxCPUUsage, in: 5...20, step: 1)
                    Text("\(Int(settingsController.maxCPUUsage))%")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Max memory usage:")
                    Spacer()
                    Slider(value: $settingsController.maxMemoryUsage, in: 100...1000, step: 50)
                    Text("\(Int(settingsController.maxMemoryUsage)) MB")
                        .frame(width: 80)
                }
                
                HStack {
                    Text("Max disk I/O:")
                    Spacer()
                    Slider(value: $settingsController.maxDiskIO, in: 10...50, step: 5)
                    Text("\(Int(settingsController.maxDiskIO)) MB/s")
                        .frame(width: 80)
                }
            }
            
            Section("Processing Options") {
                Toggle("Enable hardware acceleration", isOn: $settingsController.enableHardwareAcceleration)
                Toggle("Use batch processing", isOn: $settingsController.useBatchProcessing)
                Toggle("Enable compression", isOn: $settingsController.enableCompression)
            }
            
            Section("Current Performance") {
                HStack {
                    Text("CPU Usage:")
                    Spacer()
                    Text("\(settingsController.currentCPUUsage, specifier: "%.1f")%")
                }
                
                HStack {
                    Text("Memory Usage:")
                    Spacer()
                    Text("\(settingsController.currentMemoryUsage, specifier: "%.1f") MB")
                }
                
                HStack {
                    Text("Disk I/O:")
                    Spacer()
                    Text("\(settingsController.currentDiskIO, specifier: "%.1f") MB/s")
                }
            }
        }
        .padding()
    }
}

struct HotkeysSettingsView: View {
    @EnvironmentObject var settingsController: SettingsController
    
    var body: some View {
        Form {
            Section("Hotkey Configuration") {
                HStack {
                    Text("Pause/Resume Recording:")
                    Spacer()
                    HotkeyField(hotkey: $settingsController.pauseHotkey)
                }
                
                HStack {
                    Text("Toggle Privacy Mode:")
                    Spacer()
                    HotkeyField(hotkey: $settingsController.privacyHotkey)
                }
                
                HStack {
                    Text("Emergency Stop:")
                    Spacer()
                    HotkeyField(hotkey: $settingsController.emergencyHotkey)
                }
            }
            
            Section("Response Time") {
                HStack {
                    Text("Target response time:")
                    Spacer()
                    Text("< 100ms")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Last response time:")
                    Spacer()
                    Text("\(settingsController.lastResponseTime * 1000, specifier: "%.1f")ms")
                        .foregroundColor(settingsController.lastResponseTime > 0.1 ? .red : .green)
                }
            }
            
            Section("Test Hotkeys") {
                Button("Test Pause/Resume") {
                    settingsController.testPauseHotkey()
                }
                
                Button("Test Privacy Mode") {
                    settingsController.testPrivacyHotkey()
                }
                
                Button("Test Emergency Stop") {
                    settingsController.testEmergencyHotkey()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct RetentionSettingsView: View {
    @EnvironmentObject var settingsController: SettingsController
    
    var body: some View {
        Form {
            Section("Retention Policies") {
                Toggle("Enable automatic cleanup", isOn: $settingsController.enableRetentionPolicies)
                
                if settingsController.enableRetentionPolicies {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(settingsController.retentionPolicies.keys.sorted(), id: \.self) { dataType in
                            if let policy = settingsController.retentionPolicies[dataType] {
                                RetentionPolicyRow(
                                    dataType: dataType,
                                    policy: Binding(
                                        get: { policy },
                                        set: { settingsController.retentionPolicies[dataType] = $0 }
                                    )
                                )
                            }
                        }
                    }
                }
            }
            
            Section("Cleanup Settings") {
                HStack {
                    Text("Safety margin:")
                    Spacer()
                    Picker("", selection: $settingsController.safetyMarginHours) {
                        Text("6 hours").tag(6)
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                        Text("48 hours").tag(48)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("Cleanup interval:")
                    Spacer()
                    Picker("", selection: $settingsController.cleanupIntervalHours) {
                        Text("6 hours").tag(6)
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                    }
                    .pickerStyle(.menu)
                }
                
                Toggle("Verification before deletion", isOn: $settingsController.verificationEnabled)
            }
            
            Section("Storage Status") {
                if let healthReport = settingsController.storageHealthReport {
                    StorageHealthView(report: healthReport)
                } else {
                    Button("Check Storage Health") {
                        settingsController.checkStorageHealth()
                    }
                }
            }
        }
        .padding()
    }
}

struct RetentionPolicyRow: View {
    let dataType: String
    @Binding var policy: RetentionPolicyData
    
    var body: some View {
        HStack {
            Toggle(dataType.capitalized, isOn: $policy.enabled)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            if policy.enabled {
                Picker("", selection: $policy.retentionDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                    Text("Permanent").tag(-1)
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
    }
}

struct StorageHealthView: View {
    let report: StorageHealthReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Status:")
                Spacer()
                Text(statusText)
                    .foregroundColor(statusColor)
            }
            
            HStack {
                Text("Total size:")
                Spacer()
                Text(formatBytes(report.totalSize))
            }
            
            HStack {
                Text("Available space:")
                Spacer()
                Text(formatBytes(report.availableSpace))
            }
            
            if !report.recommendations.isEmpty {
                Divider()
                Text("Recommendations:")
                    .font(.headline)
                ForEach(report.recommendations, id: \.self) { recommendation in
                    Text("• \(recommendation)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var statusText: String {
        switch report.healthStatus {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .error: return "Error"
        }
    }
    
    private var statusColor: Color {
        switch report.healthStatus {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        case .error: return .red
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct PluginSettingsView: View {
    @EnvironmentObject var settingsController: SettingsController
    @State private var selectedPlugin: PluginInfo?
    
    var body: some View {
        HSplitView {
            // Plugin list
            VStack(alignment: .leading) {
                Text("Available Plugins")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                List(settingsController.availablePlugins, id: \.identifier, selection: $selectedPlugin) { plugin in
                    PluginListRow(plugin: plugin, settingsController: settingsController)
                }
                .frame(minWidth: 200)
                
                Button("Refresh Plugins") {
                    settingsController.refreshPlugins()
                }
                .padding(.top, 8)
            }
            .frame(minWidth: 250)
            
            // Plugin details
            VStack(alignment: .leading) {
                if let plugin = selectedPlugin {
                    PluginDetailView(plugin: plugin, settingsController: settingsController)
                } else {
                    Text("Select a plugin to view details")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
        }
        .padding()
    }
}

struct PluginListRow: View {
    let plugin: PluginInfo
    let settingsController: SettingsController
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                    .font(.headline)
                Text("v\(plugin.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { plugin.isEnabled },
                set: { settingsController.setPluginEnabled(plugin.identifier, enabled: $0) }
            ))
            .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }
}

struct PluginDetailView: View {
    let plugin: PluginInfo
    let settingsController: SettingsController
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(plugin.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Version \(plugin.version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("Enabled", isOn: Binding(
                        get: { plugin.isEnabled },
                        set: { settingsController.setPluginEnabled(plugin.identifier, enabled: $0) }
                    ))
                    .toggleStyle(.switch)
                }
                
                Divider()
                
                // Description
                Text("Description")
                    .font(.headline)
                Text(plugin.description)
                    .foregroundColor(.secondary)
                
                // Supported Applications
                Text("Supported Applications")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plugin.supportedApplications, id: \.self) { app in
                        Text("• \(app)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Plugin Settings
                if let settings = settingsController.getPluginSettings(plugin.identifier) {
                    Text("Settings")
                        .font(.headline)
                    PluginSettingsEditor(
                        pluginId: plugin.identifier,
                        settings: settings,
                        settingsController: settingsController
                    )
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct PluginSettingsEditor: View {
    let pluginId: String
    let settings: [String: Any]
    let settingsController: SettingsController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(settings.keys.sorted()), id: \.self) { key in
                PluginSettingRow(
                    key: key,
                    value: settings[key] ?? "",
                    onValueChanged: { newValue in
                        settingsController.updatePluginSetting(pluginId, key: key, value: newValue)
                    }
                )
            }
        }
    }
}

struct PluginSettingRow: View {
    let key: String
    let value: Any
    let onValueChanged: (Any) -> Void
    
    var body: some View {
        HStack {
            Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            if let boolValue = value as? Bool {
                Toggle("", isOn: Binding(
                    get: { boolValue },
                    set: { onValueChanged($0) }
                ))
                .toggleStyle(.switch)
            } else if let intValue = value as? Int {
                TextField("", value: Binding(
                    get: { intValue },
                    set: { onValueChanged($0) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            } else if let doubleValue = value as? Double {
                TextField("", value: Binding(
                    get: { doubleValue },
                    set: { onValueChanged($0) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            } else {
                TextField("", text: Binding(
                    get: { String(describing: value) },
                    set: { onValueChanged($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
            }
        }
    }
}

struct DataManagementView: View {
    @EnvironmentObject var settingsController: SettingsController
    @State private var showingExportProgress = false
    @State private var showingImportProgress = false
    @State private var exportProgress: Double = 0.0
    @State private var importProgress: Double = 0.0
    
    var body: some View {
        Form {
            Section("Data Export") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export your data for backup or migration purposes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Export All Data...") {
                            settingsController.exportAllData { progress in
                                exportProgress = progress
                            }
                        }
                        
                        Button("Export Settings Only...") {
                            settingsController.exportSettings()
                        }
                    }
                    
                    if showingExportProgress {
                        ProgressView("Exporting...", value: exportProgress, total: 1.0)
                    }
                }
            }
            
            Section("Data Import") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import data from a previous backup or another system.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Import Data...") {
                            settingsController.importData { progress in
                                importProgress = progress
                            }
                        }
                        
                        Button("Import Settings...") {
                            settingsController.importSettings()
                        }
                    }
                    
                    if showingImportProgress {
                        ProgressView("Importing...", value: importProgress, total: 1.0)
                    }
                }
            }
            
            Section("Backup & Restore") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create automatic backups of your configuration and data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Enable automatic backups", isOn: $settingsController.enableAutomaticBackups)
                    
                    if settingsController.enableAutomaticBackups {
                        HStack {
                            Text("Backup frequency:")
                            Spacer()
                            Picker("", selection: $settingsController.backupFrequency) {
                                Text("Daily").tag("daily")
                                Text("Weekly").tag("weekly")
                                Text("Monthly").tag("monthly")
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Text("Backup location:")
                            Spacer()
                            Button(settingsController.backupLocation) {
                                settingsController.selectBackupLocation()
                            }
                            .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("Keep backups for:")
                            Spacer()
                            Picker("", selection: $settingsController.backupRetentionDays) {
                                Text("30 days").tag(30)
                                Text("90 days").tag(90)
                                Text("1 year").tag(365)
                                Text("Forever").tag(-1)
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Button("Create Backup Now") {
                        settingsController.createBackupNow()
                    }
                    
                    Button("Restore from Backup...") {
                        settingsController.restoreFromBackup()
                    }
                }
            }
            
            Section("Data Cleanup") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Manage and clean up your stored data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Analyze Storage Usage") {
                        settingsController.analyzeStorageUsage()
                    }
                    
                    Button("Clean Temporary Files") {
                        settingsController.cleanTemporaryFiles()
                    }
                    
                    Button("Optimize Database") {
                        settingsController.optimizeDatabase()
                    }
                    
                    Divider()
                    
                    Button("Clear All Data...") {
                        settingsController.clearAllData()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
    }
}

struct HotkeyField: View {
    @Binding var hotkey: String
    @State private var isRecording = false
    
    var body: some View {
        Button(action: {
            isRecording.toggle()
        }) {
            Text(isRecording ? "Press keys..." : hotkey.isEmpty ? "Click to set" : hotkey)
                .frame(width: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}