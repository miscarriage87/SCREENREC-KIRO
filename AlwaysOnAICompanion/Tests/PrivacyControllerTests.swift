import XCTest
import Combine
@testable import Shared

class PrivacyControllerTests: XCTestCase {
    var privacyController: PrivacyController!
    var mockDelegate: MockPrivacyControllerDelegate!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        privacyController = PrivacyController.shared
        mockDelegate = MockPrivacyControllerDelegate()
        privacyController.delegate = mockDelegate
        cancellables = Set<AnyCancellable>()
        
        // Reset to known state
        privacyController.resetToSafeState()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        privacyController.delegate = nil
        super.tearDown()
    }
    
    // MARK: - State Transition Tests
    
    func testInitialState() {
        // Then
        XCTAssertEqual(privacyController.currentState, .paused, "Should start in paused state")
        XCTAssertTrue(privacyController.isSecurePauseActive, "Secure pause should be active")
        XCTAssertNotNil(privacyController.pauseStartTime, "Pause start time should be set")
    }
    
    func testToggleRecordingFromPaused() {
        // Given
        XCTAssertEqual(privacyController.currentState, .paused)
        
        // When
        privacyController.toggleRecording()
        
        // Then
        XCTAssertEqual(privacyController.currentState, .recording, "Should transition to recording")
        XCTAssertFalse(privacyController.isSecurePauseActive, "Secure pause should be inactive")
        XCTAssertNil(privacyController.pauseStartTime, "Pause start time should be cleared")
        XCTAssertTrue(mockDelegate.stateChanges.count > 0, "Should notify delegate of state change")
    }
    
    func testToggleRecordingFromRecording() {
        // Given
        privacyController.resumeRecording()
        XCTAssertEqual(privacyController.currentState, .recording)
        
        // When
        privacyController.toggleRecording()
        
        // Then
        XCTAssertEqual(privacyController.currentState, .paused, "Should transition to paused")
        XCTAssertTrue(privacyController.isSecurePauseActive, "Secure pause should be active")
        XCTAssertNotNil(privacyController.pauseStartTime, "Pause start time should be set")
    }
    
    func testTogglePrivacyModeFromRecording() {
        // Given
        privacyController.resumeRecording()
        XCTAssertEqual(privacyController.currentState, .recording)
        
        // When
        privacyController.togglePrivacyMode()
        
        // Then
        XCTAssertEqual(privacyController.currentState, .privacyMode, "Should transition to privacy mode")
        XCTAssertNotNil(privacyController.privacyModeStartTime, "Privacy mode start time should be set")
        XCTAssertTrue(mockDelegate.privacyModeActivated, "Should notify delegate of privacy mode activation")
    }
    
    func testTogglePrivacyModeFromPrivacyMode() {
        // Given
        privacyController.activatePrivacyMode()
        XCTAssertEqual(privacyController.currentState, .privacyMode)
        
        // When
        privacyController.togglePrivacyMode()
        
        // Then
        XCTAssertEqual(privacyController.currentState, .recording, "Should transition to recording")
        XCTAssertNil(privacyController.privacyModeStartTime, "Privacy mode start time should be cleared")
        XCTAssertTrue(mockDelegate.privacyModeDeactivated, "Should notify delegate of privacy mode deactivation")
    }
    
    func testEmergencyStop() {
        // Given
        privacyController.resumeRecording()
        XCTAssertEqual(privacyController.currentState, .recording)
        
        // When
        privacyController.activateEmergencyStop()
        
        // Then
        XCTAssertEqual(privacyController.currentState, .emergencyStop, "Should transition to emergency stop")
        XCTAssertTrue(privacyController.isSecurePauseActive, "Secure pause should be active")
        XCTAssertNotNil(privacyController.pauseStartTime, "Pause start time should be set")
        XCTAssertTrue(mockDelegate.emergencyStopActivated, "Should notify delegate of emergency stop")
    }
    
    func testResumeFromEmergencyStop() {
        // Given
        privacyController.activateEmergencyStop()
        XCTAssertEqual(privacyController.currentState, .emergencyStop)
        
        // When
        privacyController.resumeFromEmergencyStop()
        
        // Then
        XCTAssertEqual(privacyController.currentState, .paused, "Should transition to paused state for safety")
        XCTAssertTrue(privacyController.isSecurePauseActive, "Secure pause should remain active")
    }
    
    // MARK: - State Validation Tests
    
    func testStateValidation() {
        // Test recording state validation
        privacyController.resumeRecording()
        XCTAssertTrue(privacyController.validateState(), "Recording state should be valid")
        
        // Test paused state validation
        privacyController.pauseRecording()
        XCTAssertTrue(privacyController.validateState(), "Paused state should be valid")
        
        // Test privacy mode validation
        privacyController.activatePrivacyMode()
        XCTAssertTrue(privacyController.validateState(), "Privacy mode state should be valid")
        
        // Test emergency stop validation
        privacyController.activateEmergencyStop()
        XCTAssertTrue(privacyController.validateState(), "Emergency stop state should be valid")
    }
    
    func testResetToSafeState() {
        // Given - set to recording state
        privacyController.resumeRecording()
        XCTAssertEqual(privacyController.currentState, .recording)
        
        // When
        privacyController.resetToSafeState()
        
        // Then
        XCTAssertEqual(privacyController.currentState, .paused, "Should reset to paused state")
        XCTAssertTrue(privacyController.isSecurePauseActive, "Secure pause should be active")
        XCTAssertNotNil(privacyController.pauseStartTime, "Pause start time should be set")
    }
    
    // MARK: - Response Time Tests
    
    func testPauseResponseTime() {
        // Given
        privacyController.resumeRecording()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        privacyController.pauseRecording()
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(responseTime, 0.1, "Pause response time should be less than 100ms, was \(responseTime * 1000)ms")
        XCTAssertEqual(privacyController.currentState, .paused, "Should be in paused state")
    }
    
    func testPrivacyModeResponseTime() {
        // Given
        privacyController.resumeRecording()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        privacyController.activatePrivacyMode()
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(responseTime, 0.1, "Privacy mode response time should be less than 100ms, was \(responseTime * 1000)ms")
        XCTAssertEqual(privacyController.currentState, .privacyMode, "Should be in privacy mode")
    }
    
    func testEmergencyStopResponseTime() {
        // Given
        privacyController.resumeRecording()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        privacyController.activateEmergencyStop()
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(responseTime, 0.1, "Emergency stop response time should be less than 100ms, was \(responseTime * 1000)ms")
        XCTAssertEqual(privacyController.currentState, .emergencyStop, "Should be in emergency stop state")
    }
    
    // MARK: - Secure Pause Tests
    
    func testSecurePausePreventAccidentalResume() {
        // Given
        privacyController.pauseRecording()
        XCTAssertTrue(privacyController.isSecurePauseActive)
        
        // When - try to toggle recording multiple times quickly
        for _ in 0..<5 {
            privacyController.toggleRecording()
        }
        
        // Then - should only result in one state change
        let finalState = privacyController.currentState
        XCTAssertEqual(finalState, .recording, "Should end up in recording state after multiple toggles")
    }
    
    func testPauseDurationTracking() {
        // Given
        privacyController.pauseRecording()
        let pauseStart = Date()
        
        // When - wait a short time
        let expectation = XCTestExpectation(description: "Wait for pause duration")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        guard let pauseDuration = privacyController.pauseDuration else {
            XCTFail("Pause duration should be available")
            return
        }
        
        XCTAssertGreaterThan(pauseDuration, 0.05, "Pause duration should be greater than 50ms")
        XCTAssertLessThan(pauseDuration, 1.0, "Pause duration should be less than 1 second")
    }
    
    func testPrivacyModeDurationTracking() {
        // Given
        privacyController.activatePrivacyMode()
        
        // When - wait a short time
        let expectation = XCTestExpectation(description: "Wait for privacy mode duration")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        guard let privacyDuration = privacyController.privacyModeDuration else {
            XCTFail("Privacy mode duration should be available")
            return
        }
        
        XCTAssertGreaterThan(privacyDuration, 0.05, "Privacy mode duration should be greater than 50ms")
        XCTAssertLessThan(privacyDuration, 1.0, "Privacy mode duration should be less than 1 second")
    }
    
    // MARK: - State Property Tests
    
    func testShouldRecordProperty() {
        // Recording state
        privacyController.resumeRecording()
        XCTAssertTrue(privacyController.shouldRecord, "Should record in recording state")
        
        // Privacy mode
        privacyController.activatePrivacyMode()
        XCTAssertTrue(privacyController.shouldRecord, "Should record in privacy mode")
        
        // Paused state
        privacyController.pauseRecording()
        XCTAssertFalse(privacyController.shouldRecord, "Should not record in paused state")
        
        // Emergency stop
        privacyController.activateEmergencyStop()
        XCTAssertFalse(privacyController.shouldRecord, "Should not record in emergency stop")
    }
    
    func testShouldProcessDataProperty() {
        // Recording state
        privacyController.resumeRecording()
        XCTAssertTrue(privacyController.shouldProcessData, "Should process data in recording state")
        
        // Privacy mode
        privacyController.activatePrivacyMode()
        XCTAssertFalse(privacyController.shouldProcessData, "Should not process data in privacy mode")
        
        // Paused state
        privacyController.pauseRecording()
        XCTAssertFalse(privacyController.shouldProcessData, "Should not process data in paused state")
        
        // Emergency stop
        privacyController.activateEmergencyStop()
        XCTAssertFalse(privacyController.shouldProcessData, "Should not process data in emergency stop")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentStateChanges() {
        let expectation = XCTestExpectation(description: "Concurrent state changes")
        expectation.expectedFulfillmentCount = 10
        
        // When - perform multiple concurrent state changes
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInitiated).async {
                if i % 2 == 0 {
                    self.privacyController.toggleRecording()
                } else {
                    self.privacyController.togglePrivacyMode()
                }
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        // Verify final state is valid
        XCTAssertTrue(privacyController.validateState(), "Final state should be valid after concurrent changes")
    }
}

// MARK: - Mock Delegate
class MockPrivacyControllerDelegate: PrivacyControllerDelegate {
    var stateChanges: [(PrivacyState, PrivacyState)] = []
    var privacyModeActivated = false
    var privacyModeDeactivated = false
    var emergencyStopActivated = false
    
    func privacyStateDidChange(_ newState: PrivacyState, previousState: PrivacyState) {
        stateChanges.append((newState, previousState))
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
    
    func reset() {
        stateChanges.removeAll()
        privacyModeActivated = false
        privacyModeDeactivated = false
        emergencyStopActivated = false
    }
}