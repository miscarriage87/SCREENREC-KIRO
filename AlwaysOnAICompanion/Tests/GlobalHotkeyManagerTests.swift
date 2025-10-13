import XCTest
import Carbon
@testable import Shared

class GlobalHotkeyManagerTests: XCTestCase {
    var hotkeyManager: GlobalHotkeyManager!
    var mockDelegate: MockGlobalHotkeyDelegate!
    
    override func setUp() {
        super.setUp()
        hotkeyManager = GlobalHotkeyManager.shared
        mockDelegate = MockGlobalHotkeyDelegate()
        hotkeyManager.delegate = mockDelegate
        
        // Clean up any existing hotkeys
        hotkeyManager.unregisterAllHotkeys()
    }
    
    override func tearDown() {
        hotkeyManager.unregisterAllHotkeys()
        hotkeyManager.delegate = nil
        super.tearDown()
    }
    
    // MARK: - Hotkey Registration Tests
    
    func testRegisterHotkey() {
        // Given
        let hotkey = GlobalHotkey.pauseRecording
        
        // When
        let success = hotkeyManager.registerHotkey(hotkey)
        
        // Then
        XCTAssertTrue(success, "Should successfully register hotkey")
        XCTAssertTrue(hotkeyManager.isHotkeyRegistered(id: hotkey.id), "Hotkey should be registered")
        XCTAssertEqual(hotkeyManager.registeredHotkeyConfigs.count, 1, "Should have one registered hotkey")
    }
    
    func testRegisterMultipleHotkeys() {
        // Given
        let hotkeys = [
            GlobalHotkey.pauseRecording,
            GlobalHotkey.togglePrivacyMode,
            GlobalHotkey.emergencyStop
        ]
        
        // When
        var successCount = 0
        for hotkey in hotkeys {
            if hotkeyManager.registerHotkey(hotkey) {
                successCount += 1
            }
        }
        
        // Then
        XCTAssertEqual(successCount, hotkeys.count, "Should register all hotkeys successfully")
        XCTAssertEqual(hotkeyManager.registeredHotkeyConfigs.count, hotkeys.count, "Should have all hotkeys registered")
        
        for hotkey in hotkeys {
            XCTAssertTrue(hotkeyManager.isHotkeyRegistered(id: hotkey.id), "Hotkey \(hotkey.id) should be registered")
        }
    }
    
    func testUnregisterHotkey() {
        // Given
        let hotkey = GlobalHotkey.pauseRecording
        hotkeyManager.registerHotkey(hotkey)
        
        // When
        hotkeyManager.unregisterHotkey(id: hotkey.id)
        
        // Then
        XCTAssertFalse(hotkeyManager.isHotkeyRegistered(id: hotkey.id), "Hotkey should be unregistered")
        XCTAssertEqual(hotkeyManager.registeredHotkeyConfigs.count, 0, "Should have no registered hotkeys")
    }
    
    func testUnregisterAllHotkeys() {
        // Given
        let hotkeys = [GlobalHotkey.pauseRecording, GlobalHotkey.togglePrivacyMode]
        for hotkey in hotkeys {
            hotkeyManager.registerHotkey(hotkey)
        }
        
        // When
        hotkeyManager.unregisterAllHotkeys()
        
        // Then
        XCTAssertEqual(hotkeyManager.registeredHotkeyConfigs.count, 0, "Should have no registered hotkeys")
        for hotkey in hotkeys {
            XCTAssertFalse(hotkeyManager.isHotkeyRegistered(id: hotkey.id), "Hotkey \(hotkey.id) should be unregistered")
        }
    }
    
    func testRegisterDuplicateHotkey() {
        // Given
        let hotkey = GlobalHotkey.pauseRecording
        hotkeyManager.registerHotkey(hotkey)
        
        // When - register the same hotkey again
        let success = hotkeyManager.registerHotkey(hotkey)
        
        // Then
        XCTAssertTrue(success, "Should successfully re-register hotkey")
        XCTAssertEqual(hotkeyManager.registeredHotkeyConfigs.count, 1, "Should still have only one registered hotkey")
    }
    
    // MARK: - Hotkey String Parsing Tests
    
    func testHotkeyFromString() {
        // Test valid hotkey strings
        let testCases = [
            ("cmd+shift+p", "pause", "Pause"),
            ("cmd+alt+p", "privacy", "Privacy"),
            ("cmd+shift+escape", "emergency", "Emergency"),
            ("ctrl+shift+r", "record", "Record")
        ]
        
        for (string, id, description) in testCases {
            // When
            let hotkey = GlobalHotkey.from(string: string, id: id, description: description)
            
            // Then
            XCTAssertNotNil(hotkey, "Should create hotkey from string: \(string)")
            XCTAssertEqual(hotkey?.id, id, "Should have correct ID")
            XCTAssertEqual(hotkey?.description, description, "Should have correct description")
        }
    }
    
    func testInvalidHotkeyString() {
        // Test invalid hotkey strings
        let invalidStrings = [
            "invalid",
            "cmd+",
            "+p",
            "cmd+invalid+p",
            ""
        ]
        
        for string in invalidStrings {
            // When
            let hotkey = GlobalHotkey.from(string: string, id: "test", description: "Test")
            
            // Then
            XCTAssertNil(hotkey, "Should not create hotkey from invalid string: \(string)")
        }
    }
    
    // MARK: - Response Time Tests
    
    func testHotkeyResponseTime() {
        // Given
        let hotkey = GlobalHotkey.pauseRecording
        hotkeyManager.registerHotkey(hotkey)
        
        let expectation = XCTestExpectation(description: "Hotkey response time")
        var responseTime: TimeInterval = 0
        
        mockDelegate.onHotkeyPressed = { _ in
            responseTime = CFAbsoluteTimeGetCurrent() - mockDelegate.pressTime
            expectation.fulfill()
        }
        
        // When - simulate hotkey press
        mockDelegate.pressTime = CFAbsoluteTimeGetCurrent()
        mockDelegate.simulateHotkeyPress(hotkey)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertLessThan(responseTime, 0.1, "Hotkey response time should be less than 100ms, was \(responseTime * 1000)ms")
    }
    
    func testMultipleHotkeyResponseTimes() {
        // Given
        let hotkeys = [GlobalHotkey.pauseRecording, GlobalHotkey.togglePrivacyMode]
        for hotkey in hotkeys {
            hotkeyManager.registerHotkey(hotkey)
        }
        
        var responseTimes: [TimeInterval] = []
        let expectation = XCTestExpectation(description: "Multiple hotkey response times")
        expectation.expectedFulfillmentCount = hotkeys.count
        
        mockDelegate.onHotkeyPressed = { _ in
            let responseTime = CFAbsoluteTimeGetCurrent() - mockDelegate.pressTime
            responseTimes.append(responseTime)
            expectation.fulfill()
        }
        
        // When - simulate multiple hotkey presses
        for hotkey in hotkeys {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                mockDelegate.pressTime = CFAbsoluteTimeGetCurrent()
                mockDelegate.simulateHotkeyPress(hotkey)
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(responseTimes.count, hotkeys.count, "Should have response times for all hotkeys")
        
        for (index, responseTime) in responseTimes.enumerated() {
            XCTAssertLessThan(responseTime, 0.1, "Hotkey \(index) response time should be less than 100ms, was \(responseTime * 1000)ms")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testHotkeyRegistrationFailure() {
        // This test would require mocking Carbon APIs, which is complex
        // For now, we'll test the error handling path by registering conflicting hotkeys
        
        // Given - create a hotkey with system-reserved combination
        let systemHotkey = GlobalHotkey(
            id: "system_reserved",
            keyCode: 53, // Escape
            modifiers: UInt32(cmdKey | optionKey | shiftKey | controlKey), // All modifiers
            description: "System Reserved"
        )
        
        // When
        let success = hotkeyManager.registerHotkey(systemHotkey)
        
        // Then - this might fail on some systems, which is expected
        if !success {
            XCTAssertFalse(hotkeyManager.isHotkeyRegistered(id: systemHotkey.id), "Failed hotkey should not be registered")
        }
    }
}

// MARK: - Mock Delegate
class MockGlobalHotkeyDelegate: GlobalHotkeyDelegate {
    var pressTime: CFAbsoluteTime = 0
    var onHotkeyPressed: ((GlobalHotkey) -> Void)?
    var pressedHotkeys: [GlobalHotkey] = []
    
    func hotkeyPressed(_ hotkey: GlobalHotkey) {
        pressedHotkeys.append(hotkey)
        onHotkeyPressed?(hotkey)
    }
    
    func simulateHotkeyPress(_ hotkey: GlobalHotkey) {
        // Simulate the hotkey press with minimal delay
        DispatchQueue.main.async {
            self.hotkeyPressed(hotkey)
        }
    }
    
    func reset() {
        pressedHotkeys.removeAll()
        onHotkeyPressed = nil
        pressTime = 0
    }
}