import XCTest
import SwiftUI
@testable import Shared

class StatusIndicatorManagerTests: XCTestCase {
    var statusManager: StatusIndicatorManager!
    
    override func setUp() {
        super.setUp()
        statusManager = StatusIndicatorManager.shared
        statusManager.hideIndicator() // Start with clean state
    }
    
    override func tearDown() {
        statusManager.hideIndicator()
        super.tearDown()
    }
    
    // MARK: - Status Indicator Creation Tests
    
    func testStatusIndicatorFromPrivacyState() {
        // Test recording state
        let recordingIndicator = StatusIndicator.from(privacyState: .recording)
        XCTAssertEqual(recordingIndicator.type, .recording)
        XCTAssertEqual(recordingIndicator.color, .red)
        XCTAssertEqual(recordingIndicator.icon, "record.circle.fill")
        XCTAssertEqual(recordingIndicator.text, "Recording")
        XCTAssertTrue(recordingIndicator.shouldShow)
        XCTAssertTrue(recordingIndicator.shouldPulse)
        
        // Test paused state
        let pausedIndicator = StatusIndicator.from(privacyState: .paused)
        XCTAssertEqual(pausedIndicator.type, .paused)
        XCTAssertEqual(pausedIndicator.color, .orange)
        XCTAssertEqual(pausedIndicator.icon, "pause.circle.fill")
        XCTAssertEqual(pausedIndicator.text, "Paused")
        XCTAssertTrue(pausedIndicator.shouldShow)
        XCTAssertFalse(pausedIndicator.shouldPulse)
        
        // Test privacy mode
        let privacyIndicator = StatusIndicator.from(privacyState: .privacyMode)
        XCTAssertEqual(privacyIndicator.type, .privacyMode)
        XCTAssertEqual(privacyIndicator.color, .blue)
        XCTAssertEqual(privacyIndicator.icon, "eye.slash.circle.fill")
        XCTAssertEqual(privacyIndicator.text, "Privacy Mode")
        XCTAssertTrue(privacyIndicator.shouldShow)
        XCTAssertTrue(privacyIndicator.shouldPulse)
        
        // Test emergency stop
        let emergencyIndicator = StatusIndicator.from(privacyState: .emergencyStop)
        XCTAssertEqual(emergencyIndicator.type, .emergencyStop)
        XCTAssertEqual(emergencyIndicator.color, .red)
        XCTAssertEqual(emergencyIndicator.icon, "stop.circle.fill")
        XCTAssertEqual(emergencyIndicator.text, "Emergency Stop")
        XCTAssertTrue(emergencyIndicator.shouldShow)
        XCTAssertFalse(emergencyIndicator.shouldPulse)
    }
    
    func testNotificationIndicator() {
        let message = "Test notification"
        let notificationTypes: [StatusIndicator.NotificationType] = [.info, .warning, .error, .success]
        
        for type in notificationTypes {
            let indicator = StatusIndicator.notification(message: message, type: type)
            
            XCTAssertEqual(indicator.text, message)
            XCTAssertEqual(indicator.color, type.color)
            XCTAssertEqual(indicator.icon, type.icon)
            XCTAssertTrue(indicator.shouldShow)
            XCTAssertFalse(indicator.shouldPulse)
            
            if case .notification(let notificationType) = indicator.type {
                XCTAssertEqual(notificationType, type)
            } else {
                XCTFail("Indicator type should be notification")
            }
        }
    }
    
    // MARK: - Status Manager Tests
    
    func testUpdateIndicatorForPrivacyState() {
        // Given
        let privacyState = PrivacyState.recording
        
        // When
        statusManager.updateIndicator(for: privacyState)
        
        // Then
        XCTAssertEqual(statusManager.currentIndicator.type, .recording)
        XCTAssertTrue(statusManager.isVisible)
        XCTAssertTrue(statusManager.shouldPulse)
    }
    
    func testShowTemporaryNotification() {
        // Given
        let message = "Test notification"
        let type = StatusIndicator.NotificationType.info
        let duration: TimeInterval = 0.5
        
        // When
        statusManager.showTemporaryNotification(message, type: type, duration: duration)
        
        // Then
        XCTAssertEqual(statusManager.currentIndicator.text, message)
        XCTAssertTrue(statusManager.isVisible)
        
        // Wait for notification to disappear
        let expectation = XCTestExpectation(description: "Notification should disappear")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            XCTAssertFalse(self.statusManager.isVisible)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: duration + 1.0)
    }
    
    func testShowAndHideIndicator() {
        // Initially hidden
        XCTAssertFalse(statusManager.isVisible)
        
        // Show indicator
        statusManager.showIndicator()
        XCTAssertTrue(statusManager.isVisible)
        
        // Hide indicator
        statusManager.hideIndicator()
        XCTAssertFalse(statusManager.isVisible)
    }
    
    func testMultipleIndicatorUpdates() {
        let states: [PrivacyState] = [.recording, .paused, .privacyMode, .emergencyStop]
        
        for state in states {
            // When
            statusManager.updateIndicator(for: state)
            
            // Then
            let expectedIndicator = StatusIndicator.from(privacyState: state)
            XCTAssertEqual(statusManager.currentIndicator.text, expectedIndicator.text)
            XCTAssertEqual(statusManager.shouldPulse, expectedIndicator.shouldPulse)
            XCTAssertTrue(statusManager.isVisible)
        }
    }
    
    // MARK: - Visual Indicator Response Time Tests
    
    func testIndicatorUpdateResponseTime() {
        // Given
        let privacyState = PrivacyState.recording
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        statusManager.updateIndicator(for: privacyState)
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(responseTime, 0.1, "Indicator update response time should be less than 100ms, was \(responseTime * 1000)ms")
        XCTAssertTrue(statusManager.isVisible)
    }
    
    func testNotificationDisplayResponseTime() {
        // Given
        let message = "Emergency notification"
        let type = StatusIndicator.NotificationType.error
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        statusManager.showTemporaryNotification(message, type: type)
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(responseTime, 0.1, "Notification display response time should be less than 100ms, was \(responseTime * 1000)ms")
        XCTAssertTrue(statusManager.isVisible)
        XCTAssertEqual(statusManager.currentIndicator.text, message)
    }
    
    // MARK: - Menu Bar Status Item Tests
    
    func testMenuBarStatusItemCreation() {
        // Given
        let menuBarItem = MenuBarStatusItem.shared
        
        // When
        menuBarItem.updateStatusItem(for: .recording)
        
        // Then - verify no crashes occur (actual menu bar testing requires UI testing)
        // This is a basic smoke test
        XCTAssertTrue(true, "Menu bar status item should be created without crashing")
    }
    
    func testMenuBarStatusItemUpdates() {
        // Given
        let menuBarItem = MenuBarStatusItem.shared
        let states: [PrivacyState] = [.recording, .paused, .privacyMode, .emergencyStop]
        
        // When/Then - test that updates don't crash
        for state in states {
            menuBarItem.updateStatusItem(for: state)
        }
        
        XCTAssertTrue(true, "Menu bar status item updates should complete without crashing")
    }
    
    func testMenuBarStatusItemRemoval() {
        // Given
        let menuBarItem = MenuBarStatusItem.shared
        menuBarItem.updateStatusItem(for: .recording)
        
        // When
        menuBarItem.removeStatusItem()
        
        // Then - verify no crashes occur
        XCTAssertTrue(true, "Menu bar status item should be removed without crashing")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentIndicatorUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent indicator updates")
        expectation.expectedFulfillmentCount = 10
        
        let states: [PrivacyState] = [.recording, .paused, .privacyMode, .emergencyStop]
        
        // When - perform multiple concurrent updates
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInitiated).async {
                let state = states[i % states.count]
                self.statusManager.updateIndicator(for: state)
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        // Verify final state is consistent
        XCTAssertTrue(statusManager.isVisible, "Indicator should be visible after concurrent updates")
    }
    
    // MARK: - Performance Tests
    
    func testIndicatorUpdatePerformance() {
        let states: [PrivacyState] = [.recording, .paused, .privacyMode, .emergencyStop]
        
        measure {
            for _ in 0..<100 {
                for state in states {
                    statusManager.updateIndicator(for: state)
                }
            }
        }
    }
    
    func testNotificationPerformance() {
        let messages = ["Message 1", "Message 2", "Message 3", "Message 4"]
        let types: [StatusIndicator.NotificationType] = [.info, .warning, .error, .success]
        
        measure {
            for i in 0..<100 {
                let message = messages[i % messages.count]
                let type = types[i % types.count]
                statusManager.showTemporaryNotification(message, type: type, duration: 0.01)
            }
        }
    }
}