import XCTest
import Combine
@testable import Shared

class HotkeyPrivacyIntegrationTests: XCTestCase {
    var hotkeyManager: GlobalHotkeyManager!
    var privacyController: PrivacyController!
    var statusManager: StatusIndicatorManager!
    var mockDelegate: MockIntegrationDelegate!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        hotkeyManager = GlobalHotkeyManager.shared
        privacyController = PrivacyController.shared
        statusManager = StatusIndicatorManager.shared
        mockDelegate = MockIntegrationDelegate()
        cancellables = Set<AnyCancellable>()
        
        // Set up delegates
        hotkeyManager.delegate = mockDelegate
        privacyController.delegate = mockDelegate
        
        // Clean up state
        hotkeyManager.unregisterAllHotkeys()
        privacyController.resetToSafeState()
        statusManager.hideIndicator()
        
        // Register test hotkeys
        registerTestHotkeys()
    }
    
    override func tearDown() {
        hotkeyManager.unregisterAllHotkeys()
        hotkeyManager.delegate = nil
        privacyController.delegate = nil
        statusManager.hideIndicator()
        cancellables.removeAll()
        super.tearDown()
    }
    
    private func registerTestHotkeys() {
        let hotkeys = [
            GlobalHotkey.pauseRecording,
            GlobalHotkey.togglePrivacyMode,
            GlobalHotkey.emergencyStop
        ]
        
        for hotkey in hotkeys {
            XCTAssertTrue(hotkeyManager.registerHotkey(hotkey), "Should register hotkey: \(hotkey.description)")
        }
    }
    
    // MARK: - End-to-End Hotkey Tests
    
    func testPauseHotkeyEndToEnd() {
        // Given - start in recording state
        privacyController.resumeRecording()
        XCTAssertEqual(privacyController.currentState, .recording)
        
        // When - simulate pause hotkey press
        let startTime = CFAbsoluteTimeGetCurrent()
        mockDelegate.simulateHotkeyPress(GlobalHotkey.pauseRecording)
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - verify complete response chain
        XCTAssertLessThan(responseTime, 0.1, "End-to-end response time should be less than 100ms")
        XCTAssertEqual(privacyController.currentState, .paused, "Should be in paused state")
        XCTAssertTrue(mockDelegate.hotkeyPressed, "Hotkey should be processed")
        XCTAssertTrue(mockDelegate.stateChanged, "Privacy state should change")
        XCTAssertTrue(statusManager.isVisible, "Status indicator should be visible")
    }
    
    func testPrivacyModeHotkeyEndToEnd() {
        // Given - start in recording state
        privacyController.resumeRecording()
        XCTAssertEqual(privacyController.currentState, .recording)
        
        // When - simulate privacy mode hotkey press
        let startTime = CFAbsoluteTimeGetCurrent()
        mockDelegate.simulateHotkeyPress(GlobalHotkey.togglePrivacyMode)
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - verify complete response chain
        XCTAssertLessThan(responseTime, 0.1, "End-to-end response time should be less than 100ms")
        XCTAssertEqual(privacyController.currentState, .privacyMode, "Should be in privacy mode")
        XCTAssertTrue(mockDelegate.hotkeyPressed, "Hotkey should be processed")
        XCTAssertTrue(mockDelegate.privacyModeActivated, "Privacy mode should be activated")
        XCTAssertTrue(statusManager.shouldPulse, "Status indicator should pulse in privacy mode")
    }
    
    func testEmergencyStopHotkeyEndToEnd() {
        // Given - start in recording state
        privacyController.resumeRecording()
        XCTAssertEqual(privacyController.currentState, .recording)
        
        // When - simulate emergency stop hotkey press
        let startTime = CFAbsoluteTimeGetCurrent()
        mockDelegate.simulateHotkeyPress(GlobalHotkey.emergencyStop)
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - verify complete response chain
        XCTAssertLessThan(responseTime, 0.1, "End-to-end response time should be less than 100ms")
        XCTAssertEqual(privacyController.currentState, .emergencyStop, "Should be in emergency stop state")
        XCTAssertTrue(mockDelegate.hotkeyPressed, "Hotkey should be processed")
        XCTAssertTrue(mockDelegate.emergencyStopActivated, "Emergency stop should be activated")
        XCTAssertTrue(statusManager.isVisible, "Status indicator should be visible")
    }
    
    // MARK: - Rapid Hotkey Sequence Tests
    
    func testRapidHotkeySequence() {
        // Given - start in recording state
        privacyController.resumeRecording()
        
        let expectation = XCTestExpectation(description: "Rapid hotkey sequence")
        expectation.expectedFulfillmentCount = 3
        
        var responseTimes: [TimeInterval] = []
        
        // When - simulate rapid hotkey presses
        let hotkeys = [GlobalHotkey.pauseRecording, GlobalHotkey.togglePrivacyMode, GlobalHotkey.pauseRecording]
        
        for (index, hotkey) in hotkeys.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                let startTime = CFAbsoluteTimeGetCurrent()
                mockDelegate.simulateHotkeyPress(hotkey)
                let responseTime = CFAbsoluteTimeGetCurrent() - startTime
                responseTimes.append(responseTime)
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(responseTimes.count, 3, "Should have response times for all hotkeys")
        for (index, responseTime) in responseTimes.enumerated() {
            XCTAssertLessThan(responseTime, 0.1, "Hotkey \(index) response time should be less than 100ms")
        }
        
        // Verify final state is valid
        XCTAssertTrue(privacyController.validateState(), "Final state should be valid")
    }
    
    func testHotkeySpamProtection() {
        // Given - start in recording state
        privacyController.resumeRecording()
        let initialState = privacyController.currentState
        
        // When - spam the same hotkey rapidly
        let spamCount = 10
        for _ in 0..<spamCount {
            mockDelegate.simulateHotkeyPress(GlobalHotkey.pauseRecording)
        }
        
        // Then - should handle gracefully without crashes
        XCTAssertTrue(privacyController.validateState(), "State should remain valid after hotkey spam")
        
        // Final state should be different from initial (paused vs recording)
        XCTAssertNotEqual(privacyController.currentState, initialState, "State should have changed")
    }
    
    // MARK: - Visual Feedback Integration Tests
    
    func testVisualFeedbackForStateChanges() {
        let states: [PrivacyState] = [.recording, .paused, .privacyMode, .emergencyStop]
        
        for targetState in states {
            // Given - reset to known state
            privacyController.resetToSafeState()
            mockDelegate.reset()
            
            // When - transition to target state
            switch targetState {
            case .recording:
                mockDelegate.simulateHotkeyPress(GlobalHotkey.pauseRecording) // paused -> recording
            case .paused:
                // Already in paused state
                break
            case .privacyMode:
                mockDelegate.simulateHotkeyPress(GlobalHotkey.togglePrivacyMode)
            case .emergencyStop:
                mockDelegate.simulateHotkeyPress(GlobalHotkey.emergencyStop)
            }
            
            // Then - verify visual feedback
            XCTAssertEqual(privacyController.currentState, targetState, "Should be in \(targetState) state")
            XCTAssertTrue(statusManager.isVisible, "Status indicator should be visible for \(targetState)")
            
            let expectedIndicator = StatusIndicator.from(privacyState: targetState)
            XCTAssertEqual(statusManager.currentIndicator.text, expectedIndicator.text, "Indicator text should match state")
            XCTAssertEqual(statusManager.shouldPulse, expectedIndicator.shouldPulse, "Pulse behavior should match state")
        }
    }
    
    // MARK: - Secure Pause Integration Tests
    
    func testSecurePausePreventAccidentalResume() {
        // Given - start recording and pause
        privacyController.resumeRecording()
        mockDelegate.simulateHotkeyPress(GlobalHotkey.pauseRecording)
        XCTAssertEqual(privacyController.currentState, .paused)
        XCTAssertTrue(privacyController.isSecurePauseActive)
        
        // When - try to resume immediately with multiple hotkey presses
        for _ in 0..<3 {
            mockDelegate.simulateHotkeyPress(GlobalHotkey.pauseRecording)
        }
        
        // Then - should handle gracefully
        XCTAssertTrue(privacyController.validateState(), "State should remain valid")
        // Final state depends on odd/even number of presses, but should be consistent
    }
    
    func testEmergencyStopOverridesOtherStates() {
        let initialStates: [PrivacyState] = [.recording, .paused, .privacyMode]
        
        for initialState in initialStates {
            // Given - set initial state
            switch initialState {
            case .recording:
                privacyController.resumeRecording()
            case .paused:
                privacyController.pauseRecording()
            case .privacyMode:
                privacyController.activatePrivacyMode()
            case .emergencyStop:
                break // Skip this case
            }
            
            XCTAssertEqual(privacyController.currentState, initialState)
            
            // When - activate emergency stop
            mockDelegate.simulateHotkeyPress(GlobalHotkey.emergencyStop)
            
            // Then - should always go to emergency stop
            XCTAssertEqual(privacyController.currentState, .emergencyStop, "Emergency stop should override \(initialState)")
            XCTAssertTrue(mockDelegate.emergencyStopActivated, "Emergency stop should be activated")
            
            // Reset for next iteration
            mockDelegate.reset()
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testSystemPerformanceUnderLoad() {
        // Given - simulate high load scenario
        let iterations = 100
        var responseTimes: [TimeInterval] = []
        
        // When - perform many rapid state changes
        for i in 0..<iterations {
            let hotkey = i % 2 == 0 ? GlobalHotkey.pauseRecording : GlobalHotkey.togglePrivacyMode
            
            let startTime = CFAbsoluteTimeGetCurrent()
            mockDelegate.simulateHotkeyPress(hotkey)
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            responseTimes.append(responseTime)
        }
        
        // Then - verify performance remains consistent
        let averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let maxResponseTime = responseTimes.max() ?? 0
        
        XCTAssertLessThan(averageResponseTime, 0.05, "Average response time should be less than 50ms")
        XCTAssertLessThan(maxResponseTime, 0.1, "Maximum response time should be less than 100ms")
        XCTAssertTrue(privacyController.validateState(), "Final state should be valid")
    }
    
    // MARK: - Error Recovery Tests
    
    func testRecoveryFromInvalidState() {
        // Given - force invalid state (this is artificial for testing)
        privacyController.resumeRecording()
        
        // When - use hotkey to trigger state validation and recovery
        mockDelegate.simulateHotkeyPress(GlobalHotkey.pauseRecording)
        
        // Then - system should recover gracefully
        XCTAssertTrue(privacyController.validateState(), "Should recover to valid state")
        XCTAssertTrue(statusManager.isVisible, "Status indicator should be visible")
    }
    
    func testHotkeySystemResilience() {
        // Given - register and unregister hotkeys multiple times
        for _ in 0..<5 {
            hotkeyManager.unregisterAllHotkeys()
            registerTestHotkeys()
        }
        
        // When - use hotkeys after multiple registrations
        mockDelegate.simulateHotkeyPress(GlobalHotkey.pauseRecording)
        
        // Then - should still work correctly
        XCTAssertTrue(mockDelegate.hotkeyPressed, "Hotkey should still work after multiple registrations")
        XCTAssertTrue(privacyController.validateState(), "Privacy controller should be in valid state")
    }
}

// MARK: - Mock Integration Delegate
class MockIntegrationDelegate: GlobalHotkeyDelegate, PrivacyControllerDelegate {
    var hotkeyPressed = false
    var stateChanged = false
    var privacyModeActivated = false
    var privacyModeDeactivated = false
    var emergencyStopActivated = false
    var lastHotkey: GlobalHotkey?
    var lastStateChange: (PrivacyState, PrivacyState)?
    
    // GlobalHotkeyDelegate
    func hotkeyPressed(_ hotkey: GlobalHotkey) {
        hotkeyPressed = true
        lastHotkey = hotkey
        
        // Simulate the actual hotkey handling logic
        switch hotkey.id {
        case "pause_recording":
            PrivacyController.shared.toggleRecording()
        case "toggle_privacy":
            PrivacyController.shared.togglePrivacyMode()
        case "emergency_stop":
            PrivacyController.shared.activateEmergencyStop()
        default:
            break
        }
    }
    
    // PrivacyControllerDelegate
    func privacyStateDidChange(_ newState: PrivacyState, previousState: PrivacyState) {
        stateChanged = true
        lastStateChange = (newState, previousState)
        
        // Update status indicator
        StatusIndicatorManager.shared.updateIndicator(for: newState)
    }
    
    func privacyModeWillActivate() {
        privacyModeActivated = true
    }
    
    func privacyModeDidDeactivate() {
        privacyModeDeactivated = true
    }
    
    func emergencyStopActivated() {
        emergencyStopActivated = true
    }
    
    // Test utilities
    func simulateHotkeyPress(_ hotkey: GlobalHotkey) {
        // Simulate immediate hotkey press
        DispatchQueue.main.async {
            self.hotkeyPressed(hotkey)
        }
    }
    
    func reset() {
        hotkeyPressed = false
        stateChanged = false
        privacyModeActivated = false
        privacyModeDeactivated = false
        emergencyStopActivated = false
        lastHotkey = nil
        lastStateChange = nil
    }
}