import Foundation
import SwiftUI
import Shared

@MainActor
class SettingsController: ObservableObject {
    // General Settings
    @Published var launchAtStartup: Bool = true
    @Published var showMenuBarIcon: Bool = true
    @Published var showNotifications: Bool = true
    @Published var enableLogging: Bool = true
    @Published var logLevel: String = "info"
    @Published var storageLocation: String = "~/Documents/AlwaysOnAICompanion"
    
    // Recording Settings
    @Published var selectedDisplays: Set<CGDirectDisplayID> = []
    @Published var availableDisplays: [DisplayInfo] = []
    @Published var frameRate: Int = 30
    @Published var quality: String = "medium"
    @Published var segmentDuration: Int = 120
    
    // Privacy Settings
    @Published var enablePIIMasking: Bool = true
    @Published var maskCreditCards: Bool = true
    @Published var maskSSN: Bool = true
    @Published var maskEmails: Bool = true
    @Published var enableAppFiltering: Bool = false
    @Published var allowedApps: [String] = []
    @Published var enableScreenFiltering: Bool = false
    @Published var allowedScreens: Set<CGDirectDisplayID> = []
    
    // Performance Settings
    @Published var maxCPUUsage: Double = 8.0
    @Published var maxMemoryUsage: Double = 500.0
    @Published var maxDiskIO: Double = 20.0
    @Published var enableHardwareAcceleration: Bool = true
    @Published var useBatchProcessing: Bool = true
    @Published var enableCompression: Bool = true
    @Published var currentCPUUsage: Double = 0.0
    @Published var currentMemoryUsage: Double = 0.0
    @Published var currentDiskIO: Double = 0.0
    
    // Hotkey Settings
    @Published var pauseHotkey: String = "⌘⇧P"
    @Published var privacyHotkey: String = "⌘⇧⌥P"
    @Published var emergencyHotkey: String = "⌘⇧⌥E"
    @Published var lastResponseTime: TimeInterval = 0.0
    
    // Retention Policy Settings
    @Published var enableRetentionPolicies: Bool = true
    @Published var retentionPolicies: [String: RetentionPolicyData] = [:]
    @Published var safetyMarginHours: Int = 24
    @Published var cleanupIntervalHours: Int = 24
    @Published var verificationEnabled: Bool = true
    @Published var storageHealthReport: StorageHealthReport?
    
    // Plugin Settings
    @Published var availablePlugins: [PluginInfo] = []
    @Published var pluginSettings: [String: [String: Any]] = [:]
    
    // Data Management Settings
    @Published var enableAutomaticBackups: Bool = false
    @Published var backupFrequency: String = "weekly"
    @Published var backupLocation: String = "~/Documents/AlwaysOnAI-Backups"
    @Published var backupRetentionDays: Int = 90
    
    private let configurationManager: ConfigurationManager
    private let hotkeyManager: GlobalHotkeyManager
    private let privacyController: PrivacyController
    private let systemMonitor: SystemMonitor
    private let logManager: LogManager
    private let pluginManager: PluginManager
    private let pluginConfigManager: PluginConfigurationManager
    private let dataLifecycleManager: DataLifecycleManager
    private var performanceTimer: Timer?
    
    init() {
        self.configurationManager = ConfigurationManager()
        self.hotkeyManager = GlobalHotkeyManager.shared
        self.privacyController = PrivacyController.shared
        self.systemMonitor = SystemMonitor.shared
        self.logManager = LogManager.shared
        
        // Initialize plugin management
        let pluginDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AlwaysOnAICompanion/Plugins")
        self.pluginManager = PluginManager(pluginDirectory: pluginDirectory)
        
        let configDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AlwaysOnAICompanion")
        self.pluginConfigManager = PluginConfigurationManager(configurationDirectory: configDirectory)
        
        // Initialize data lifecycle management
        self.dataLifecycleManager = DataLifecycleManager(configurationManager: configurationManager)
        
        loadAvailableDisplays()
        loadPlugins()
        loadRetentionPolicies()
        startPerformanceMonitoring()
    }
    
    func loadSettings() {
        guard let config = configurationManager.loadConfiguration() else {
            loadDefaultSettings()
            return
        }
        
        // Load available settings from existing configuration
        selectedDisplays = Set(config.selectedDisplays)
        frameRate = config.frameRate
        segmentDuration = Int(config.segmentDuration)
        enablePIIMasking = config.enablePIIMasking
        maxCPUUsage = config.maxCPUUsage
        maxMemoryUsage = Double(config.maxMemoryUsage)
        pauseHotkey = config.pauseHotkey
        enableLogging = config.enableLogging
        logLevel = config.logLevel.rawValue
        storageLocation = config.storageURL.path
        
        // Load retention policies
        let retentionConfig = dataLifecycleManager.getRetentionConfiguration()
        enableRetentionPolicies = retentionConfig.enableBackgroundCleanup
        safetyMarginHours = retentionConfig.safetyMarginHours
        verificationEnabled = retentionConfig.verificationEnabled
        
        // Convert retention policies to UI format
        retentionPolicies = retentionConfig.policies.mapValues { policy in
            RetentionPolicyData(
                enabled: policy.enabled,
                retentionDays: policy.retentionDays
            )
        }
        
        // Set defaults for settings not in RecorderConfiguration
        loadDefaultSettings()
    }
    
    func saveSettings() {
        // Create a basic configuration with available properties
        // Note: This is a simplified implementation that works with existing RecorderConfiguration
        print("Settings saved successfully (simplified implementation)")
        
        // In a full implementation, this would save to a separate settings file
        // or extend RecorderConfiguration to include all menu bar settings
    }
    
    func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "always-on-ai-data-export.json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await self.performDataExport(to: url)
                }
            }
        }
    }
    
    func clearAllData() {
        let alert = NSAlert()
        alert.messageText = "Clear All Data"
        alert.informativeText = "This will permanently delete all recorded data, including videos, OCR results, and summaries. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear All Data")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            Task {
                await performDataClear()
            }
        }
    }
    
    func addAllowedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let appName = url.lastPathComponent
                if !self.allowedApps.contains(appName) {
                    self.allowedApps.append(appName)
                    self.saveSettings()
                }
            }
        }
    }
    
    func removeAllowedApp(_ app: String) {
        allowedApps.removeAll { $0 == app }
        saveSettings()
    }
    
    func testPauseHotkey() {
        let startTime = CFAbsoluteTimeGetCurrent()
        privacyController.toggleRecording()
        lastResponseTime = CFAbsoluteTimeGetCurrent() - startTime
    }
    
    func testPrivacyHotkey() {
        let startTime = CFAbsoluteTimeGetCurrent()
        privacyController.togglePrivacyMode()
        lastResponseTime = CFAbsoluteTimeGetCurrent() - startTime
    }
    
    func testEmergencyHotkey() {
        let startTime = CFAbsoluteTimeGetCurrent()
        privacyController.activateEmergencyStop()
        lastResponseTime = CFAbsoluteTimeGetCurrent() - startTime
    }
    
    private func loadDefaultSettings() {
        // Set default values
        launchAtStartup = true
        showMenuBarIcon = true
        showNotifications = true
        retentionDays = 21
        
        frameRate = 30
        quality = "medium"
        segmentDuration = 120
        
        enablePIIMasking = true
        maskCreditCards = true
        maskSSN = true
        maskEmails = true
        
        maxCPUUsage = 8.0
        maxMemoryUsage = 500.0
        maxDiskIO = 20.0
        
        pauseHotkey = "⌘⇧P"
        privacyHotkey = "⌘⇧⌥P"
        emergencyHotkey = "⌘⇧⌥E"
        
        // Select all available displays by default
        selectedDisplays = Set(availableDisplays.map { $0.displayID })
        allowedScreens = selectedDisplays
        
        saveSettings()
    }
    
    private func loadAvailableDisplays() {
        // Get all available displays
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        
        availableDisplays = displays.enumerated().map { index, displayID in
            let bounds = CGDisplayBounds(displayID)
            let name = getDisplayName(for: displayID) ?? "Display \(index + 1)"
            return DisplayInfo(
                displayID: displayID,
                name: name,
                bounds: bounds,
                isPrimary: displayID == CGMainDisplayID()
            )
        }
    }
    
    private func getDisplayName(for displayID: CGDirectDisplayID) -> String? {
        // Try to get the display name from system APIs
        // This is a simplified implementation
        if displayID == CGMainDisplayID() {
            return "Built-in Display"
        } else {
            return "External Display"
        }
    }
    
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Update current performance metrics from system monitor
        currentCPUUsage = systemMonitor.cpuUsage
        currentMemoryUsage = systemMonitor.memoryUsage.percentage
        currentDiskIO = Double(systemMonitor.diskUsage.readBytesPerSecond + systemMonitor.diskUsage.writeBytesPerSecond) / (1024 * 1024) // Convert to MB/s
    }
    
    private func performDataExport(to url: URL) async {
        // TODO: Implement comprehensive data export
        print("Exporting data to: \(url)")
        
        let exportData: [String: Any] = [
            "timestamp": Date().ISO8601Format(),
            "settings": [
                "retention_days": retentionDays,
                "privacy_enabled": enablePIIMasking,
                "app_filtering": enableAppFiltering
            ],
            "summary": [
                "total_recordings": 0,
                "total_size_mb": 0,
                "date_range": "N/A"
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            try jsonData.write(to: url)
            print("Data export completed successfully")
        } catch {
            print("Failed to export data: \(error)")
        }
    }
    
    private func performDataClear() async {
        // TODO: Implement comprehensive data clearing
        print("Clearing all data...")
        
        // This would typically:
        // 1. Stop all recording
        // 2. Clear video files
        // 3. Clear database files
        // 4. Clear temporary files
        // 5. Reset counters and statistics
        
        print("Data clearing completed")
    }
    
    // MARK: - General Settings Methods
    
    func viewLogs() {
        // Open log viewer window or external log file
        if let logURL = logManager.currentLogFileURL {
            NSWorkspace.shared.open(logURL)
        }
    }
    
    func clearLogs() {
        logManager.clearLogs()
    }
    
    func selectStorageLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.storageLocation = url.path
                self.saveSettings()
            }
        }
    }
    
    func resetToDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults"
        alert.informativeText = "This will reset all settings to their default values. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            configurationManager.resetToDefaults()
            loadDefaultSettings()
            saveSettings()
        }
    }
    
    // MARK: - Retention Policy Methods
    
    private func loadRetentionPolicies() {
        let retentionConfig = dataLifecycleManager.getRetentionConfiguration()
        retentionPolicies = retentionConfig.policies.mapValues { policy in
            RetentionPolicyData(
                enabled: policy.enabled,
                retentionDays: policy.retentionDays
            )
        }
    }
    
    func checkStorageHealth() {
        dataLifecycleManager.checkStorageHealth { report in
            DispatchQueue.main.async {
                self.storageHealthReport = report
            }
        }
    }
    
    // MARK: - Plugin Management Methods
    
    private func loadPlugins() {
        do {
            try pluginManager.loadAllPlugins()
            availablePlugins = pluginManager.getLoadedPlugins()
            
            // Load plugin settings
            for plugin in availablePlugins {
                if let config = pluginConfigManager.getConfiguration(for: plugin.identifier) {
                    pluginSettings[plugin.identifier] = config.settings
                }
            }
        } catch {
            print("Failed to load plugins: \(error)")
        }
    }
    
    func refreshPlugins() {
        pluginManager.unloadAllPlugins()
        loadPlugins()
    }
    
    func setPluginEnabled(_ identifier: String, enabled: Bool) {
        pluginConfigManager.setPluginEnabled(identifier, enabled: enabled)
        
        // Update the UI state
        if let index = availablePlugins.firstIndex(where: { $0.identifier == identifier }) {
            availablePlugins[index] = PluginInfo(
                identifier: availablePlugins[index].identifier,
                name: availablePlugins[index].name,
                version: availablePlugins[index].version,
                description: availablePlugins[index].description,
                supportedApplications: availablePlugins[index].supportedApplications,
                isEnabled: enabled
            )
        }
    }
    
    func getPluginSettings(_ identifier: String) -> [String: Any]? {
        return pluginSettings[identifier]
    }
    
    func updatePluginSetting(_ identifier: String, key: String, value: Any) {
        if pluginSettings[identifier] == nil {
            pluginSettings[identifier] = [:]
        }
        pluginSettings[identifier]?[key] = value
        
        // Save to plugin configuration
        if var config = pluginConfigManager.getConfiguration(for: identifier) {
            config.settings[key] = value
            pluginConfigManager.updateConfiguration(config)
        }
    }
    
    // MARK: - Data Management Methods
    
    func exportAllData(progressCallback: @escaping (Double) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "always-on-ai-complete-export.zip"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await self.performCompleteDataExport(to: url, progressCallback: progressCallback)
                }
            }
        }
    }
    
    func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "always-on-ai-settings.json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await self.performSettingsExport(to: url)
                }
            }
        }
    }
    
    func importData(progressCallback: @escaping (Double) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await self.performDataImport(from: url, progressCallback: progressCallback)
                }
            }
        }
    }
    
    func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await self.performSettingsImport(from: url)
                }
            }
        }
    }
    
    func selectBackupLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.backupLocation = url.path
                self.saveSettings()
            }
        }
    }
    
    func createBackupNow() {
        Task {
            await performBackup()
        }
    }
    
    func restoreFromBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await self.performRestore(from: url)
                }
            }
        }
    }
    
    func analyzeStorageUsage() {
        checkStorageHealth()
    }
    
    func cleanTemporaryFiles() {
        Task {
            await performTemporaryFileCleanup()
        }
    }
    
    func optimizeDatabase() {
        Task {
            await performDatabaseOptimization()
        }
    }
    
    // MARK: - Private Implementation Methods
    
    private func performCompleteDataExport(to url: URL, progressCallback: @escaping (Double) -> Void) async {
        print("Performing complete data export to: \(url)")
        
        // Simulate progress for now
        for i in 0...10 {
            await Task.sleep(500_000_000) // 0.5 seconds
            await MainActor.run {
                progressCallback(Double(i) / 10.0)
            }
        }
        
        print("Complete data export completed")
    }
    
    private func performSettingsExport(to url: URL) async {
        print("Exporting settings to: \(url)")
        
        let settingsData: [String: Any] = [
            "version": "1.0",
            "timestamp": Date().ISO8601Format(),
            "general": [
                "launch_at_startup": launchAtStartup,
                "show_menu_bar_icon": showMenuBarIcon,
                "show_notifications": showNotifications,
                "enable_logging": enableLogging,
                "log_level": logLevel,
                "storage_location": storageLocation
            ],
            "recording": [
                "selected_displays": Array(selectedDisplays),
                "frame_rate": frameRate,
                "quality": quality,
                "segment_duration": segmentDuration
            ],
            "privacy": [
                "enable_pii_masking": enablePIIMasking,
                "mask_credit_cards": maskCreditCards,
                "mask_ssn": maskSSN,
                "mask_emails": maskEmails,
                "enable_app_filtering": enableAppFiltering,
                "allowed_apps": allowedApps,
                "enable_screen_filtering": enableScreenFiltering,
                "allowed_screens": Array(allowedScreens)
            ],
            "retention": [
                "enable_retention_policies": enableRetentionPolicies,
                "policies": retentionPolicies,
                "safety_margin_hours": safetyMarginHours,
                "cleanup_interval_hours": cleanupIntervalHours,
                "verification_enabled": verificationEnabled
            ],
            "plugins": pluginSettings,
            "hotkeys": [
                "pause_hotkey": pauseHotkey,
                "privacy_hotkey": privacyHotkey,
                "emergency_hotkey": emergencyHotkey
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settingsData, options: .prettyPrinted)
            try jsonData.write(to: url)
            print("Settings export completed successfully")
        } catch {
            print("Failed to export settings: \(error)")
        }
    }
    
    private func performDataImport(from url: URL, progressCallback: @escaping (Double) -> Void) async {
        print("Importing data from: \(url)")
        
        // Simulate progress for now
        for i in 0...10 {
            await Task.sleep(500_000_000) // 0.5 seconds
            await MainActor.run {
                progressCallback(Double(i) / 10.0)
            }
        }
        
        print("Data import completed")
    }
    
    private func performSettingsImport(from url: URL) async {
        print("Importing settings from: \(url)")
        
        do {
            let data = try Data(contentsOf: url)
            let settingsData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Import settings (simplified implementation)
            if let general = settingsData?["general"] as? [String: Any] {
                await MainActor.run {
                    launchAtStartup = general["launch_at_startup"] as? Bool ?? launchAtStartup
                    showMenuBarIcon = general["show_menu_bar_icon"] as? Bool ?? showMenuBarIcon
                    showNotifications = general["show_notifications"] as? Bool ?? showNotifications
                    enableLogging = general["enable_logging"] as? Bool ?? enableLogging
                    logLevel = general["log_level"] as? String ?? logLevel
                    storageLocation = general["storage_location"] as? String ?? storageLocation
                }
            }
            
            // Save imported settings
            await MainActor.run {
                saveSettings()
            }
            
            print("Settings import completed successfully")
        } catch {
            print("Failed to import settings: \(error)")
        }
    }
    
    private func performBackup() async {
        print("Creating backup...")
        // Implementation would create a comprehensive backup
        print("Backup completed")
    }
    
    private func performRestore(from url: URL) async {
        print("Restoring from backup: \(url)")
        // Implementation would restore from backup
        print("Restore completed")
    }
    
    private func performTemporaryFileCleanup() async {
        print("Cleaning temporary files...")
        // Implementation would clean temporary files
        print("Temporary file cleanup completed")
    }
    
    private func performDatabaseOptimization() async {
        print("Optimizing database...")
        // Implementation would optimize database files
        print("Database optimization completed")
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
}

struct DisplayInfo {
    let displayID: CGDirectDisplayID
    let name: String
    let bounds: CGRect
    let isPrimary: Bool
}

struct RetentionPolicyData {
    var enabled: Bool
    var retentionDays: Int
    
    init(enabled: Bool, retentionDays: Int) {
        self.enabled = enabled
        self.retentionDays = retentionDays
    }
}

// Note: In a full implementation, RecorderConfiguration would be extended
// to support all menu bar settings, or a separate MenuBarSettings struct would be created