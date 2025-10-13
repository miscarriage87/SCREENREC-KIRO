import Foundation
import SwiftUI
import Shared

@MainActor
class MenuBarController: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var isPrivacyMode: Bool = false
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var diskIO: Double = 0.0
    @Published var privacyState: PrivacyState = .paused
    @Published var hotkeyResponseTime: TimeInterval = 0.0
    @Published var showingMonitoringWindow: Bool = false
    
    private var configurationManager: ConfigurationManager
    private var monitoringTimer: Timer?
    private var hotkeyManager: GlobalHotkeyManager
    private var privacyController: PrivacyController
    private var statusIndicatorManager: StatusIndicatorManager
    private var menuBarStatusItem: MenuBarStatusItem
    private var systemMonitor: SystemMonitor
    private var logManager: LogManager
    private var monitoringWindow: NSWindow?
    private var helpWindow: NSWindow?
    
    init() {
        self.configurationManager = ConfigurationManager()
        self.hotkeyManager = GlobalHotkeyManager.shared
        self.privacyController = PrivacyController.shared
        self.statusIndicatorManager = StatusIndicatorManager.shared
        self.menuBarStatusItem = MenuBarStatusItem.shared
        self.systemMonitor = SystemMonitor.shared
        self.logManager = LogManager.shared
        
        setupHotkeys()
        setupPrivacyController()
        setupMonitoring()
        loadInitialState()
    }
    
    func startMonitoring() {
        // Start system monitoring
        systemMonitor.startMonitoring()
        
        // Start periodic monitoring of system metrics
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateMetrics()
                self.checkSystemHealth()
            }
        }
        
        // Initial metrics update
        updateMetrics()
        
        // Start status indicators
        statusIndicatorManager.updateIndicator(for: privacyState)
        menuBarStatusItem.updateStatusItem(for: privacyState)
        
        // Log monitoring start
        logManager.info("System monitoring started", category: "MenuBar")
    }
    
    func stopMonitoring() {
        // Stop system monitoring
        systemMonitor.stopMonitoring()
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Clean up status indicators
        statusIndicatorManager.hideIndicator()
        menuBarStatusItem.removeStatusItem()
        
        // Close monitoring window if open
        monitoringWindow?.close()
        monitoringWindow = nil
        
        // Close help window if open
        helpWindow?.close()
        helpWindow = nil
        
        // Log monitoring stop
        logManager.info("System monitoring stopped", category: "MenuBar")
    }
    
    func toggleRecording() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        privacyController.toggleRecording()
        
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        hotkeyResponseTime = responseTime
        
        // Verify we met the 100ms requirement
        if responseTime > 0.1 {
            print("Warning: Hotkey response time exceeded 100ms: \(responseTime * 1000)ms")
        }
    }
    
    func togglePrivacyMode() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        privacyController.togglePrivacyMode()
        
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        hotkeyResponseTime = responseTime
        
        // Verify we met the 100ms requirement
        if responseTime > 0.1 {
            print("Warning: Privacy mode toggle response time exceeded 100ms: \(responseTime * 1000)ms")
        }
    }
    
    func activateEmergencyStop() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        privacyController.activateEmergencyStop()
        
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        hotkeyResponseTime = responseTime
        
        // Show emergency notification
        statusIndicatorManager.showTemporaryNotification(
            "Emergency Stop Activated",
            type: .error,
            duration: 5.0
        )
    }
    
    func openSettings() {
        // Create and show settings window
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Always-On AI Companion Settings"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Keep a reference to prevent deallocation
        NSApp.activate(ignoringOtherApps: true)
        
        logManager.info("Settings window opened", category: "MenuBar")
    }
    
    func openMonitoring() {
        if let existingWindow = monitoringWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create and show monitoring window
        let monitoringView = MonitoringView()
        let hostingController = NSHostingController(rootView: monitoringView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "System Monitoring & Diagnostics"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Store reference
        monitoringWindow = window
        showingMonitoringWindow = true
        
        // Handle window closing
        window.delegate = self
        
        NSApp.activate(ignoringOtherApps: true)
        
        logManager.info("Monitoring window opened", category: "MenuBar")
    }
    
    func openHelp(context: HelpContext = .general) {
        if let existingWindow = helpWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            // Update help context if different
            HelpSystem.shared.showHelp(for: context)
            return
        }
        
        // Create and show help window
        let helpView = HelpView()
        let hostingController = NSHostingController(rootView: helpView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Always-On AI Companion - Help & Support"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Store reference
        helpWindow = window
        
        // Handle window closing
        window.delegate = self
        
        // Set initial help context
        HelpSystem.shared.showHelp(for: context)
        
        NSApp.activate(ignoringOtherApps: true)
        
        logManager.info("Help window opened with context: \(context.rawValue)", category: "MenuBar")
    }
    
    func showContextualHelp(for context: HelpContext) {
        openHelp(context: context)
    }
    
    func resetEmergencyStop() {
        privacyController.resetEmergencyStop()
        updateStateFromPrivacyController()
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
    
    func gracefulShutdown() {
        // Stop monitoring and clean up
        stopMonitoring()
        
        // Stop recording gracefully
        privacyController.pauseRecording()
        
        // Give time for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    var buildDate: Date? {
        // Get build date from bundle info
        guard let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let infoDict = NSDictionary(contentsOfFile: infoPath),
              let buildDateString = infoDict["CFBundleVersion"] as? String else {
            return nil
        }
        
        // This is a simplified implementation
        // In a real app, you'd embed the actual build date
        return Date()
    }
    
    private func setupHotkeys() {
        // Set up hotkey delegate
        hotkeyManager.delegate = self
        
        // Load hotkey configuration and register hotkeys
        if let config = configurationManager.loadConfiguration() {
            registerConfiguredHotkeys(config)
        } else {
            registerDefaultHotkeys()
        }
    }
    
    private func setupPrivacyController() {
        // Set up privacy controller delegate
        privacyController.delegate = self
        
        // Sync initial state
        updateStateFromPrivacyController()
    }
    
    private func registerConfiguredHotkeys(_ config: RecorderConfiguration) {
        // Register pause/resume hotkey from configuration
        if let pauseHotkey = GlobalHotkey.from(
            string: config.pauseHotkey,
            id: "pause_recording",
            description: "Pause/Resume Recording"
        ) {
            if !hotkeyManager.registerHotkey(pauseHotkey) {
                print("Failed to register pause hotkey: \(config.pauseHotkey)")
                registerDefaultHotkeys()
            }
        } else {
            print("Invalid pause hotkey configuration: \(config.pauseHotkey)")
            registerDefaultHotkeys()
        }
        
        // Register additional hotkeys
        registerAdditionalHotkeys()
    }
    
    private func registerDefaultHotkeys() {
        // Register default hotkeys if configuration fails
        let defaultHotkeys = [
            GlobalHotkey.pauseRecording,
            GlobalHotkey.togglePrivacyMode,
            GlobalHotkey.emergencyStop
        ]
        
        for hotkey in defaultHotkeys {
            if !hotkeyManager.registerHotkey(hotkey) {
                print("Failed to register default hotkey: \(hotkey.description)")
            }
        }
    }
    
    private func registerAdditionalHotkeys() {
        // Register privacy mode toggle hotkey
        if !hotkeyManager.registerHotkey(GlobalHotkey.togglePrivacyMode) {
            print("Failed to register privacy mode hotkey")
        }
        
        // Register emergency stop hotkey
        if !hotkeyManager.registerHotkey(GlobalHotkey.emergencyStop) {
            print("Failed to register emergency stop hotkey")
        }
    }
    
    private func loadInitialState() {
        // Load initial recording state from configuration
        if configurationManager.loadConfiguration() != nil {
            // Don't auto-start recording, start in paused state for safety
            privacyController.pauseRecording()
        }
        
        updateStateFromPrivacyController()
    }
    
    private func updateStateFromPrivacyController() {
        privacyState = privacyController.currentState
        isRecording = privacyController.shouldRecord
        isPrivacyMode = (privacyState == .privacyMode)
    }
    
    private func setupMonitoring() {
        // Configure system monitor thresholds
        systemMonitor.thresholds.maxCPUUsage = 80.0
        systemMonitor.thresholds.maxMemoryUsage = 85.0
        systemMonitor.thresholds.maxDiskUsage = 90.0
        
        // Start monitoring
        systemMonitor.startMonitoring()
        
        logManager.info("System monitoring configured", category: "MenuBar")
    }
    
    private func updateMetrics() {
        // Update CPU usage from system monitor
        cpuUsage = systemMonitor.cpuUsage
        
        // Update memory usage from system monitor
        memoryUsage = systemMonitor.memoryUsage.percentage
        
        // Update disk I/O from system monitor
        diskIO = Double(systemMonitor.diskUsage.readBytesPerSecond + systemMonitor.diskUsage.writeBytesPerSecond) / (1024 * 1024) // Convert to MB/s
    }
    
    private func checkSystemHealth() {
        // Check for critical alerts
        let criticalAlerts = systemMonitor.activeAlerts.filter { $0.severity == .critical }
        
        if !criticalAlerts.isEmpty {
            // Show critical alert notification
            for alert in criticalAlerts {
                statusIndicatorManager.showTemporaryNotification(
                    alert.title,
                    type: .error,
                    duration: 10.0
                )
                
                logManager.error("Critical system alert: \(alert.message)", category: "SystemHealth")
            }
        }
        
        // Check system health status
        switch systemMonitor.systemHealth {
        case .critical:
            logManager.error("System health is critical", category: "SystemHealth")
        case .degraded:
            logManager.warning("System health is degraded", category: "SystemHealth")
        case .healthy:
            // Only log occasionally to avoid spam
            if Int(Date().timeIntervalSince1970) % 300 == 0 { // Every 5 minutes
                logManager.debug("System health is good", category: "SystemHealth")
            }
        }
    }
    
    private func startRecording() {
        print("Starting recording from menu bar...")
        // TODO: Send IPC message to recorder daemon to start
    }
    
    private func pauseRecording() {
        print("Pausing recording from menu bar...")
        // TODO: Send IPC message to recorder daemon to pause
    }
    
    private func enablePrivacyMode() {
        print("Enabling privacy mode...")
        // TODO: Send IPC message to recorder daemon to enable privacy mode
    }
    
    private func disablePrivacyMode() {
        print("Disabling privacy mode...")
        // TODO: Send IPC message to recorder daemon to disable privacy mode
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        // In a real implementation, this would use system APIs
        return Double.random(in: 2.0...8.0)
    }
    
    private func getCurrentMemoryUsage() -> Double {
        // Simplified memory usage calculation
        // In a real implementation, this would use system APIs
        let processInfo = ProcessInfo.processInfo
        return Double(processInfo.physicalMemory) / (1024 * 1024 * 1024) * 0.1 // Rough estimate
    }
    
    private func getCurrentDiskIO() -> Double {
        // Simplified disk I/O calculation
        // In a real implementation, this would use system APIs
        return Double.random(in: 5.0...20.0)
    }
    
    private func performDataExport(to url: URL) async {
        // TODO: Implement comprehensive data export
        print("Exporting data to: \(url)")
        
        let exportData = [
            "timestamp": Date().ISO8601Format(),
            "settings": [
                "retention_days": 21,
                "privacy_enabled": true,
                "app_filtering": false
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
    
    deinit {
        stopMonitoring()
        
        // Clean up hotkeys and status indicators
        hotkeyManager.unregisterAllHotkeys()
        statusIndicatorManager.hideIndicator()
        menuBarStatusItem.removeStatusItem()
        
        logManager.info("MenuBarController deinitialized", category: "MenuBar")
    }
}

// MARK: - GlobalHotkeyDelegate
extension MenuBarController: GlobalHotkeyDelegate {
    func hotkeyPressed(_ hotkey: GlobalHotkey) {
        print("Hotkey pressed: \(hotkey.description)")
        
        switch hotkey.id {
        case "pause_recording":
            toggleRecording()
        case "toggle_privacy":
            togglePrivacyMode()
        case "emergency_stop":
            activateEmergencyStop()
        default:
            print("Unknown hotkey ID: \(hotkey.id)")
        }
    }
}

// MARK: - NSWindowDelegate
extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == monitoringWindow {
                monitoringWindow = nil
                showingMonitoringWindow = false
                logManager.info("Monitoring window closed", category: "MenuBar")
            } else if window == helpWindow {
                helpWindow = nil
                HelpSystem.shared.hideHelp()
                logManager.info("Help window closed", category: "MenuBar")
            }
        }
    }
}

// MARK: - PrivacyControllerDelegate
extension MenuBarController: PrivacyControllerDelegate {
    func privacyStateDidChange(_ newState: PrivacyState, previousState: PrivacyState) {
        updateStateFromPrivacyController()
        
        // Update visual indicators
        statusIndicatorManager.updateIndicator(for: newState)
        menuBarStatusItem.updateStatusItem(for: newState)
        
        // Show notification for state changes
        let message = "Recording \(newState.description)"
        let notificationType: StatusIndicator.NotificationType = {
            switch newState {
            case .recording: return .success
            case .paused: return .warning
            case .privacyMode: return .info
            case .emergencyStop: return .error
            }
        }()
        
        statusIndicatorManager.showTemporaryNotification(message, type: notificationType)
        
        print("Privacy state changed: \(previousState.description) → \(newState.description)")
    }
    
    func privacyModeWillActivate() {
        print("Privacy mode will activate - preparing to limit data processing")
        // TODO: Send signal to processing components to enter privacy mode
    }
    
    func privacyModeDidDeactivate() {
        print("Privacy mode deactivated - resuming normal data processing")
        // TODO: Send signal to processing components to resume normal operation
    }
    
    func emergencyStopActivated() {
        print("Emergency stop activated - stopping all recording and processing")
        // TODO: Send emergency stop signal to all recording and processing components
        
        // Force stop all recording immediately
        // TODO: Implement emergency stop for recording system
    }
}