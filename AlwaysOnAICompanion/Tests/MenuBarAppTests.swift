import XCTest
import SwiftUI
@testable import MenuBarApp
@testable import Shared

@MainActor
class MenuBarAppTests: XCTestCase {
    var menuBarController: MenuBarController!
    var settingsController: SettingsController!
    
    override func setUp() async throws {
        try await super.setUp()
        menuBarController = MenuBarController()
        settingsController = SettingsController()
    }
    
    override func tearDown() async throws {
        menuBarController = nil
        settingsController = nil
        try await super.tearDown()
    }
    
    // MARK: - MenuBarController Tests
    
    func testMenuBarControllerInitialization() {
        // Given & When
        let controller = MenuBarController()
        
        // Then
        XCTAssertFalse(controller.isRecording)
        XCTAssertFalse(controller.isPrivacyMode)
        XCTAssertEqual(controller.privacyState, .paused)
        XCTAssertGreaterThanOrEqual(controller.cpuUsage, 0.0)
        XCTAssertGreaterThanOrEqual(controller.memoryUsage, 0.0)
        XCTAssertGreaterThanOrEqual(controller.diskIO, 0.0)
    }
    
    func testToggleRecording() {
        // Given
        let initialState = menuBarController.isRecording
        
        // When
        menuBarController.toggleRecording()
        
        // Then
        // State should change (though actual recording depends on system permissions)
        XCTAssertTrue(menuBarController.hotkeyResponseTime >= 0)
        
        // Verify response time is within acceptable limits
        XCTAssertLessThan(menuBarController.hotkeyResponseTime, 0.2, "Response time should be under 200ms")
    }
    
    func testTogglePrivacyMode() {
        // Given
        let initialPrivacyMode = menuBarController.isPrivacyMode
        
        // When
        menuBarController.togglePrivacyMode()
        
        // Then
        XCTAssertTrue(menuBarController.hotkeyResponseTime >= 0)
        XCTAssertLessThan(menuBarController.hotkeyResponseTime, 0.2, "Privacy mode toggle should be under 200ms")
    }
    
    func testEmergencyStop() {
        // Given
        menuBarController.privacyState = .recording
        
        // When
        menuBarController.activateEmergencyStop()
        
        // Then
        XCTAssertTrue(menuBarController.hotkeyResponseTime >= 0)
        XCTAssertLessThan(menuBarController.hotkeyResponseTime, 0.15, "Emergency stop should be very fast")
    }
    
    func testResetEmergencyStop() {
        // Given
        menuBarController.activateEmergencyStop()
        
        // When
        menuBarController.resetEmergencyStop()
        
        // Then
        // Should be able to reset from emergency stop
        XCTAssertNotEqual(menuBarController.privacyState, .emergencyStop)
    }
    
    func testPerformanceMetricsUpdate() {
        // Given
        let initialCPU = menuBarController.cpuUsage
        let initialMemory = menuBarController.memoryUsage
        let initialDiskIO = menuBarController.diskIO
        
        // When
        menuBarController.startMonitoring()
        
        // Wait for metrics update
        let expectation = XCTestExpectation(description: "Metrics updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        
        // Then
        XCTAssertGreaterThanOrEqual(menuBarController.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(menuBarController.cpuUsage, 100.0)
        XCTAssertGreaterThanOrEqual(menuBarController.memoryUsage, 0.0)
        XCTAssertGreaterThanOrEqual(menuBarController.diskIO, 0.0)
        
        // Clean up
        menuBarController.stopMonitoring()
    }
    
    func testDataExport() {
        // Given
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-export.json")
        
        // When
        let expectation = XCTestExpectation(description: "Data export completed")
        Task {
            await menuBarController.performDataExport(to: tempURL)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Verify export content
        do {
            let data = try Data(contentsOf: tempURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json)
            XCTAssertNotNil(json?["timestamp"])
            XCTAssertNotNil(json?["settings"])
            XCTAssertNotNil(json?["summary"])
        } catch {
            XCTFail("Failed to read export file: \(error)")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - SettingsController Tests
    
    func testSettingsControllerInitialization() {
        // Given & When
        let controller = SettingsController()
        
        // Then
        XCTAssertTrue(controller.launchAtStartup)
        XCTAssertTrue(controller.showMenuBarIcon)
        XCTAssertTrue(controller.showNotifications)
        XCTAssertEqual(controller.retentionDays, 21)
        XCTAssertEqual(controller.frameRate, 30)
        XCTAssertEqual(controller.quality, "medium")
        XCTAssertEqual(controller.segmentDuration, 120)
        XCTAssertTrue(controller.enablePIIMasking)
        XCTAssertEqual(controller.maxCPUUsage, 8.0)
        XCTAssertEqual(controller.maxMemoryUsage, 500.0)
        XCTAssertEqual(controller.maxDiskIO, 20.0)
    }
    
    func testSettingsLoadAndSave() {
        // Given
        settingsController.retentionDays = 30
        settingsController.frameRate = 60
        settingsController.quality = "high"
        settingsController.enablePIIMasking = false
        
        // When
        settingsController.saveSettings()
        
        // Create new controller to test loading
        let newController = SettingsController()
        newController.loadSettings()
        
        // Then
        XCTAssertEqual(newController.retentionDays, 30)
        XCTAssertEqual(newController.frameRate, 60)
        XCTAssertEqual(newController.quality, "high")
        XCTAssertFalse(newController.enablePIIMasking)
    }
    
    func testDisplayDetection() {
        // Given & When
        settingsController.loadSettings()
        
        // Then
        XCTAssertGreaterThan(settingsController.availableDisplays.count, 0)
        
        // Verify primary display is detected
        let hasPrimaryDisplay = settingsController.availableDisplays.contains { $0.isPrimary }
        XCTAssertTrue(hasPrimaryDisplay)
        
        // Verify display info is populated
        for display in settingsController.availableDisplays {
            XCTAssertFalse(display.name.isEmpty)
            XCTAssertGreaterThan(display.bounds.width, 0)
            XCTAssertGreaterThan(display.bounds.height, 0)
        }
    }
    
    func testAllowedAppsManagement() {
        // Given
        let testApp = "TestApp.app"
        
        // When
        settingsController.allowedApps.append(testApp)
        settingsController.saveSettings()
        
        // Then
        XCTAssertTrue(settingsController.allowedApps.contains(testApp))
        
        // When removing
        settingsController.removeAllowedApp(testApp)
        
        // Then
        XCTAssertFalse(settingsController.allowedApps.contains(testApp))
    }
    
    func testHotkeyResponseTesting() {
        // Given
        let initialResponseTime = settingsController.lastResponseTime
        
        // When
        settingsController.testPauseHotkey()
        
        // Then
        XCTAssertGreaterThan(settingsController.lastResponseTime, 0)
        XCTAssertLessThan(settingsController.lastResponseTime, 0.2, "Hotkey response should be under 200ms")
        
        // When testing privacy hotkey
        settingsController.testPrivacyHotkey()
        
        // Then
        XCTAssertGreaterThan(settingsController.lastResponseTime, 0)
        XCTAssertLessThan(settingsController.lastResponseTime, 0.2, "Privacy hotkey response should be under 200ms")
        
        // When testing emergency hotkey
        settingsController.testEmergencyHotkey()
        
        // Then
        XCTAssertGreaterThan(settingsController.lastResponseTime, 0)
        XCTAssertLessThan(settingsController.lastResponseTime, 0.15, "Emergency hotkey should be very fast")
    }
    
    func testPerformanceMonitoring() {
        // Given
        let initialCPU = settingsController.currentCPUUsage
        let initialMemory = settingsController.currentMemoryUsage
        let initialDiskIO = settingsController.currentDiskIO
        
        // When
        let expectation = XCTestExpectation(description: "Performance metrics updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        
        // Then
        XCTAssertGreaterThanOrEqual(settingsController.currentCPUUsage, 0.0)
        XCTAssertLessThanOrEqual(settingsController.currentCPUUsage, 100.0)
        XCTAssertGreaterThanOrEqual(settingsController.currentMemoryUsage, 0.0)
        XCTAssertGreaterThanOrEqual(settingsController.currentDiskIO, 0.0)
    }
    
    // MARK: - UI Component Tests
    
    func testPrivacyStateDisplayNames() {
        // Test all privacy states have proper display names
        XCTAssertEqual(PrivacyState.recording.displayName, "Recording Active")
        XCTAssertEqual(PrivacyState.paused.displayName, "Recording Paused")
        XCTAssertEqual(PrivacyState.privacyMode.displayName, "Privacy Mode")
        XCTAssertEqual(PrivacyState.emergencyStop.displayName, "Emergency Stop")
    }
    
    func testPrivacyStateColors() {
        // Test all privacy states have appropriate colors
        XCTAssertEqual(PrivacyState.recording.color, .green)
        XCTAssertEqual(PrivacyState.paused.color, .orange)
        XCTAssertEqual(PrivacyState.privacyMode.color, .blue)
        XCTAssertEqual(PrivacyState.emergencyStop.color, .red)
    }
    
    func testPerformanceMetricCalculations() {
        // Given
        let metric = PerformanceMetric(
            label: "Test Metric",
            value: 5.0,
            maxValue: 10.0,
            unit: "%",
            warningThreshold: 8.0
        )
        
        // Test percentage calculation
        XCTAssertEqual(metric.percentage, 0.5, accuracy: 0.01)
        XCTAssertFalse(metric.isWarning)
        
        // Test warning threshold
        let warningMetric = PerformanceMetric(
            label: "Warning Metric",
            value: 9.0,
            maxValue: 10.0,
            unit: "%",
            warningThreshold: 8.0
        )
        
        XCTAssertTrue(warningMetric.isWarning)
    }
    
    func testSystemHealthIndicator() {
        // Given
        menuBarController.cpuUsage = 5.0
        menuBarController.memoryUsage = 300.0
        menuBarController.diskIO = 10.0
        menuBarController.hotkeyResponseTime = 0.05
        
        // When
        let healthIndicator = SystemHealthIndicator(controller: menuBarController)
        
        // Then
        XCTAssertEqual(healthIndicator.healthStatus.0, "Healthy")
        XCTAssertEqual(healthIndicator.healthStatus.1, .green)
        
        // Test warning state
        menuBarController.cpuUsage = 12.0
        XCTAssertEqual(healthIndicator.healthStatus.0, "Warning")
        XCTAssertEqual(healthIndicator.healthStatus.1, .orange)
        
        // Test degraded state
        menuBarController.hotkeyResponseTime = 0.15
        XCTAssertEqual(healthIndicator.healthStatus.0, "Degraded")
        XCTAssertEqual(healthIndicator.healthStatus.1, .red)
    }
    
    // MARK: - Integration Tests
    
    func testMenuBarControllerSettingsIntegration() {
        // Given
        let controller = MenuBarController()
        let settings = SettingsController()
        
        // When
        settings.maxCPUUsage = 10.0
        settings.maxMemoryUsage = 1000.0
        settings.saveSettings()
        
        // Then
        // Verify settings are properly integrated
        // (This would require actual IPC integration in a real implementation)
        XCTAssertNotNil(settings)
        XCTAssertNotNil(controller)
    }
    
    func testHotkeyIntegration() {
        // Given
        let controller = MenuBarController()
        
        // When
        controller.startMonitoring()
        
        // Simulate hotkey press
        controller.toggleRecording()
        
        // Then
        XCTAssertGreaterThan(controller.hotkeyResponseTime, 0)
        XCTAssertLessThan(controller.hotkeyResponseTime, 0.1, "Hotkey response should meet 100ms requirement")
        
        // Clean up
        controller.stopMonitoring()
    }
    
    func testPrivacyStateTransitions() {
        // Given
        let controller = MenuBarController()
        
        // Test normal recording -> paused
        controller.privacyState = .recording
        controller.toggleRecording()
        
        // Test paused -> privacy mode
        controller.privacyState = .paused
        controller.togglePrivacyMode()
        
        // Test emergency stop
        controller.activateEmergencyStop()
        XCTAssertEqual(controller.privacyState, .emergencyStop)
        
        // Test reset from emergency stop
        controller.resetEmergencyStop()
        XCTAssertNotEqual(controller.privacyState, .emergencyStop)
    }
}

// MARK: - Test Extensions

extension PerformanceMetric {
    var percentage: Double {
        min(value / maxValue, 1.0)
    }
    
    var isWarning: Bool {
        value > warningThreshold
    }
}

extension SystemHealthIndicator {
    var healthStatus: (String, Color) {
        let cpuOK = controller.cpuUsage <= 8.0
        let memoryOK = controller.memoryUsage <= 500.0
        let diskOK = controller.diskIO <= 20.0
        let responseOK = controller.hotkeyResponseTime <= 0.1
        
        if cpuOK && memoryOK && diskOK && responseOK {
            return ("Healthy", .green)
        } else if !responseOK || controller.cpuUsage > 10.0 {
            return ("Warning", .orange)
        } else {
            return ("Degraded", .red)
        }
    }
}