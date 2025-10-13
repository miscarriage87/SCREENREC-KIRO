import Foundation
import Shared

/// Demo application showcasing the global hotkey and privacy control system
public class HotkeyPrivacyDemo {
    private let hotkeyManager: GlobalHotkeyManager
    private let privacyController: PrivacyController
    private let statusManager: StatusIndicatorManager
    private let menuBarItem: MenuBarStatusItem
    private let logger = Logger.shared
    
    private var isRunning = false
    private var demoTimer: Timer?
    
    public init() {
        self.hotkeyManager = GlobalHotkeyManager.shared
        self.privacyController = PrivacyController.shared
        self.statusManager = StatusIndicatorManager.shared
        self.menuBarItem = MenuBarStatusItem.shared
        
        setupDelegates()
    }
    
    deinit {
        stopDemo()
    }
    
    // MARK: - Public Interface
    
    /// Starts the hotkey and privacy demo
    public func startDemo() {
        guard !isRunning else {
            logger.warning("Demo is already running")
            return
        }
        
        logger.info("Starting Hotkey and Privacy Control Demo")
        logger.info("===========================================")
        
        isRunning = true
        
        // Register hotkeys
        registerDemoHotkeys()
        
        // Set up privacy controller
        setupPrivacyController()
        
        // Start status indicators
        startStatusIndicators()
        
        // Start demo monitoring
        startDemoMonitoring()
        
        // Print instructions
        printInstructions()
        
        logger.info("Demo started successfully!")
    }
    
    /// Stops the demo and cleans up resources
    public func stopDemo() {
        guard isRunning else { return }
        
        logger.info("Stopping Hotkey and Privacy Control Demo")
        
        isRunning = false
        
        // Stop monitoring
        demoTimer?.invalidate()
        demoTimer = nil
        
        // Clean up hotkeys
        hotkeyManager.unregisterAllHotkeys()
        
        // Hide status indicators
        statusManager.hideIndicator()
        menuBarItem.removeStatusItem()
        
        // Reset privacy controller
        privacyController.resetToSafeState()
        
        logger.info("Demo stopped")
    }
    
    /// Runs the demo for a specified duration
    public func runDemo(duration: TimeInterval) {
        startDemo()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.stopDemo()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupDelegates() {
        hotkeyManager.delegate = self
        privacyController.delegate = self
    }
    
    private func registerDemoHotkeys() {
        logger.info("Registering demo hotkeys...")
        
        let hotkeys = [
            GlobalHotkey.pauseRecording,
            GlobalHotkey.togglePrivacyMode,
            GlobalHotkey.emergencyStop
        ]
        
        for hotkey in hotkeys {
            let success = hotkeyManager.registerHotkey(hotkey)
            if success {
                logger.info("✅ Registered: \(hotkey.description)")
            } else {
                logger.error("❌ Failed to register: \(hotkey.description)")
            }
        }
    }
    
    private func setupPrivacyController() {
        logger.info("Setting up privacy controller...")
        
        // Start in paused state for safety
        privacyController.resetToSafeState()
        
        logger.info("Privacy controller initialized in \(privacyController.currentState.description) state")
    }
    
    private func startStatusIndicators() {
        logger.info("Starting status indicators...")
        
        // Update status indicators for current state
        statusManager.updateIndicator(for: privacyController.currentState)
        menuBarItem.updateStatusItem(for: privacyController.currentState)
        
        logger.info("Status indicators started")
    }
    
    private func startDemoMonitoring() {
        demoTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.logCurrentStatus()
        }
    }
    
    private func printInstructions() {
        logger.info("")
        logger.info("📋 DEMO INSTRUCTIONS")
        logger.info("===================")
        logger.info("Use the following hotkeys to control the system:")
        logger.info("")
        logger.info("⌘⇧P - Pause/Resume Recording")
        logger.info("⌘⌥P - Toggle Privacy Mode")
        logger.info("⌘⇧⎋ - Emergency Stop")
        logger.info("")
        logger.info("Watch for:")
        logger.info("• Visual status indicators in top-right corner")
        logger.info("• Menu bar status item changes")
        logger.info("• Console log messages")
        logger.info("• Response time measurements")
        logger.info("")
        logger.info("Current state: \(privacyController.currentState.description)")
        logger.info("")
    }
    
    private func logCurrentStatus() {
        let state = privacyController.currentState
        let shouldRecord = privacyController.shouldRecord
        let shouldProcess = privacyController.shouldProcessData
        
        logger.info("📊 Status: \(state.description) | Recording: \(shouldRecord) | Processing: \(shouldProcess)")
        
        if let pauseDuration = privacyController.pauseDuration {
            logger.info("⏸ Paused for: \(String(format: "%.1f", pauseDuration))s")
        }
        
        if let privacyDuration = privacyController.privacyModeDuration {
            logger.info("👁 Privacy mode active for: \(String(format: "%.1f", privacyDuration))s")
        }
    }
    
    // MARK: - Demo Scenarios
    
    /// Demonstrates automatic state transitions
    public func demonstrateStateTransitions() {
        logger.info("🎬 Demonstrating automatic state transitions...")
        
        let scenarios = [
            ("Starting recording", { self.privacyController.resumeRecording() }),
            ("Pausing recording", { self.privacyController.pauseRecording() }),
            ("Activating privacy mode", { self.privacyController.activatePrivacyMode() }),
            ("Deactivating privacy mode", { self.privacyController.deactivatePrivacyMode() }),
            ("Emergency stop", { self.privacyController.activateEmergencyStop() }),
            ("Resuming from emergency stop", { self.privacyController.resumeFromEmergencyStop() })
        ]
        
        for (index, (description, action)) in scenarios.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.0) {
                self.logger.info("🎯 \(description)...")
                let startTime = CFAbsoluteTimeGetCurrent()
                action()
                let responseTime = CFAbsoluteTimeGetCurrent() - startTime
                self.logger.info("⚡ Response time: \(String(format: "%.1f", responseTime * 1000))ms")
            }
        }
    }
    
    /// Demonstrates response time measurements
    public func demonstrateResponseTimes() {
        logger.info("⏱ Demonstrating response time measurements...")
        
        let testCount = 10
        var responseTimes: [TimeInterval] = []
        
        for i in 0..<testCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                let startTime = CFAbsoluteTimeGetCurrent()
                self.privacyController.toggleRecording()
                let responseTime = CFAbsoluteTimeGetCurrent() - startTime
                responseTimes.append(responseTime)
                
                self.logger.info("Test \(i + 1): \(String(format: "%.1f", responseTime * 1000))ms")
                
                if i == testCount - 1 {
                    let averageTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
                    let maxTime = responseTimes.max() ?? 0
                    let minTime = responseTimes.min() ?? 0
                    
                    self.logger.info("📈 Response Time Summary:")
                    self.logger.info("   Average: \(String(format: "%.1f", averageTime * 1000))ms")
                    self.logger.info("   Min: \(String(format: "%.1f", minTime * 1000))ms")
                    self.logger.info("   Max: \(String(format: "%.1f", maxTime * 1000))ms")
                    self.logger.info("   Target: <100ms ✅")
                }
            }
        }
    }
    
    /// Demonstrates visual feedback system
    public func demonstrateVisualFeedback() {
        logger.info("🎨 Demonstrating visual feedback system...")
        
        let states: [PrivacyState] = [.recording, .paused, .privacyMode, .emergencyStop]
        
        for (index, state) in states.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 3.0) {
                self.logger.info("🎯 Switching to \(state.description) state...")
                
                switch state {
                case .recording:
                    self.privacyController.resumeRecording()
                case .paused:
                    self.privacyController.pauseRecording()
                case .privacyMode:
                    self.privacyController.activatePrivacyMode()
                case .emergencyStop:
                    self.privacyController.activateEmergencyStop()
                }
                
                // Show temporary notification
                let message = "Switched to \(state.description)"
                let notificationType: StatusIndicator.NotificationType = {
                    switch state {
                    case .recording: return .success
                    case .paused: return .warning
                    case .privacyMode: return .info
                    case .emergencyStop: return .error
                    }
                }()
                
                self.statusManager.showTemporaryNotification(message, type: notificationType, duration: 2.0)
            }
        }
    }
}

// MARK: - GlobalHotkeyDelegate
extension HotkeyPrivacyDemo: GlobalHotkeyDelegate {
    public func hotkeyPressed(_ hotkey: GlobalHotkey) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.info("🔥 Hotkey pressed: \(hotkey.description)")
        
        switch hotkey.id {
        case "pause_recording":
            privacyController.toggleRecording()
        case "toggle_privacy":
            privacyController.togglePrivacyMode()
        case "emergency_stop":
            privacyController.activateEmergencyStop()
        default:
            logger.warning("Unknown hotkey ID: \(hotkey.id)")
            return
        }
        
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        let responseTimeMs = responseTime * 1000
        
        let status = responseTimeMs < 100 ? "✅" : "⚠️"
        logger.info("⚡ Hotkey response time: \(String(format: "%.1f", responseTimeMs))ms \(status)")
        
        if responseTimeMs >= 100 {
            logger.warning("Response time exceeded 100ms target!")
        }
    }
}

// MARK: - PrivacyControllerDelegate
extension HotkeyPrivacyDemo: PrivacyControllerDelegate {
    public func privacyStateDidChange(_ newState: PrivacyState, previousState: PrivacyState) {
        logger.info("🔄 State changed: \(previousState.description) → \(newState.description)")
        
        // Update visual indicators
        statusManager.updateIndicator(for: newState)
        menuBarItem.updateStatusItem(for: newState)
        
        // Log state properties
        logger.info("   Should record: \(privacyController.shouldRecord)")
        logger.info("   Should process data: \(privacyController.shouldProcessData)")
        logger.info("   Secure pause active: \(privacyController.isSecurePauseActive)")
    }
    
    public func privacyModeWillActivate() {
        logger.info("🛡 Privacy mode will activate - limiting data processing")
        statusManager.showTemporaryNotification("Privacy Mode Activating", type: .info, duration: 2.0)
    }
    
    public func privacyModeDidDeactivate() {
        logger.info("🔓 Privacy mode deactivated - resuming normal processing")
        statusManager.showTemporaryNotification("Privacy Mode Deactivated", type: .success, duration: 2.0)
    }
    
    public func emergencyStopActivated() {
        logger.warning("🚨 EMERGENCY STOP ACTIVATED - All recording and processing stopped!")
        statusManager.showTemporaryNotification("EMERGENCY STOP", type: .error, duration: 5.0)
    }
}

// MARK: - Command Line Interface
public class HotkeyPrivacyDemoCLI {
    public static func main() {
        let demo = HotkeyPrivacyDemo()
        
        print("Always-On AI Companion - Hotkey & Privacy Demo")
        print("==============================================")
        print("")
        print("Commands:")
        print("  start    - Start the demo")
        print("  stop     - Stop the demo")
        print("  test     - Run automated tests")
        print("  visual   - Demonstrate visual feedback")
        print("  timing   - Test response times")
        print("  quit     - Exit the demo")
        print("")
        
        var shouldContinue = true
        
        while shouldContinue {
            print("Enter command: ", terminator: "")
            
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                continue
            }
            
            switch input {
            case "start":
                demo.startDemo()
            case "stop":
                demo.stopDemo()
            case "test":
                demo.demonstrateStateTransitions()
            case "visual":
                demo.demonstrateVisualFeedback()
            case "timing":
                demo.demonstrateResponseTimes()
            case "quit", "exit", "q":
                demo.stopDemo()
                shouldContinue = false
            case "help", "h":
                print("Available commands: start, stop, test, visual, timing, quit")
            default:
                print("Unknown command: \(input). Type 'help' for available commands.")
            }
        }
        
        print("Demo terminated.")
    }
}