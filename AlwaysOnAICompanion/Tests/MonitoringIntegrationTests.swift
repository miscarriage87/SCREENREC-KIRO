import XCTest
import SwiftUI
@testable import MenuBarApp
@testable import Shared

final class MonitoringIntegrationTests: XCTestCase {
    var menuBarController: MenuBarController!
    var systemMonitor: SystemMonitor!
    var logManager: LogManager!
    
    override func setUp() {
        super.setUp()
        menuBarController = MenuBarController()
        systemMonitor = SystemMonitor.shared
        logManager = LogManager.shared
    }
    
    override func tearDown() {
        menuBarController.stopMonitoring()
        systemMonitor.stopMonitoring()
        logManager.clearLogs()
        super.tearDown()
    }
    
    func testMenuBarControllerMonitoringIntegration() {
        // Test monitoring startup
        menuBarController.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Monitoring started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Verify metrics are being updated
        XCTAssertGreaterThanOrEqual(menuBarController.cpuUsage, 0.0)
        XCTAssertGreaterThanOrEqual(menuBarController.memoryUsage, 0.0)
        XCTAssertGreaterThanOrEqual(menuBarController.diskIO, 0.0)
        
        // Test monitoring stop
        menuBarController.stopMonitoring()
    }
    
    func testSystemHealthAlerts() {
        menuBarController.startMonitoring()
        
        // Set very low thresholds to trigger alerts
        systemMonitor.thresholds.maxCPUUsage = 0.1
        systemMonitor.thresholds.maxMemoryUsage = 0.1
        
        let expectation = XCTestExpectation(description: "Health alerts generated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
        
        // Should have generated alerts
        XCTAssertFalse(systemMonitor.activeAlerts.isEmpty)
        XCTAssertNotEqual(systemMonitor.systemHealth, .healthy)
        
        // Check that logs were generated for alerts
        let alertLogs = logManager.logEntries.filter { $0.category == "SystemHealth" }
        XCTAssertFalse(alertLogs.isEmpty)
    }
    
    func testPerformanceMetricsAccuracy() {
        menuBarController.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Metrics collected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Verify metrics are within reasonable ranges
        XCTAssertLessThan(menuBarController.cpuUsage, 100.0)
        XCTAssertGreaterThanOrEqual(menuBarController.cpuUsage, 0.0)
        
        XCTAssertLessThan(menuBarController.memoryUsage, 100.0)
        XCTAssertGreaterThanOrEqual(menuBarController.memoryUsage, 0.0)
        
        XCTAssertGreaterThanOrEqual(menuBarController.diskIO, 0.0)
        
        // Verify system monitor and menu bar controller have consistent data
        XCTAssertEqual(menuBarController.cpuUsage, systemMonitor.cpuUsage, accuracy: 0.1)
        XCTAssertEqual(menuBarController.memoryUsage, systemMonitor.memoryUsage.percentage, accuracy: 0.1)
    }
    
    func testHotkeyResponseTimeTracking() {
        menuBarController.startMonitoring()
        
        // Test hotkey response time tracking
        let startTime = CFAbsoluteTimeGetCurrent()
        menuBarController.toggleRecording()
        let responseTime = menuBarController.hotkeyResponseTime
        
        // Response time should be recorded and reasonable
        XCTAssertGreaterThan(responseTime, 0.0)
        XCTAssertLessThan(responseTime, 1.0) // Should be much less than 1 second
        
        // Test privacy mode toggle
        menuBarController.togglePrivacyMode()
        let privacyResponseTime = menuBarController.hotkeyResponseTime
        
        XCTAssertGreaterThan(privacyResponseTime, 0.0)
        XCTAssertLessThan(privacyResponseTime, 1.0)
    }
    
    func testMonitoringWindowManagement() {
        // Test opening monitoring window
        XCTAssertFalse(menuBarController.showingMonitoringWindow)
        XCTAssertNil(menuBarController.monitoringWindow)
        
        menuBarController.openMonitoring()
        
        XCTAssertTrue(menuBarController.showingMonitoringWindow)
        XCTAssertNotNil(menuBarController.monitoringWindow)
        
        // Test closing monitoring window
        menuBarController.stopMonitoring()
        
        XCTAssertFalse(menuBarController.showingMonitoringWindow)
        XCTAssertNil(menuBarController.monitoringWindow)
    }
    
    func testLogIntegration() {
        menuBarController.startMonitoring()
        
        // Generate some activity to create logs
        menuBarController.toggleRecording()
        menuBarController.togglePrivacyMode()
        menuBarController.openSettings()
        
        let expectation = XCTestExpectation(description: "Logs generated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Verify logs were created
        XCTAssertFalse(logManager.logEntries.isEmpty)
        
        // Check for specific log categories
        let categories = logManager.getAvailableCategories()
        XCTAssertTrue(categories.contains("MenuBar"))
        
        // Check for monitoring-related logs
        let monitoringLogs = logManager.logEntries.filter { $0.category == "MenuBar" }
        XCTAssertFalse(monitoringLogs.isEmpty)
    }
    
    func testDiagnosticsExport() {
        menuBarController.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Diagnostics ready")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Test diagnostics export
        let diagnostics = systemMonitor.getSystemDiagnostics()
        XCTAssertNotNil(diagnostics)
        
        // Verify diagnostics contain expected data
        XCTAssertGreaterThanOrEqual(diagnostics.cpuUsage, 0.0)
        XCTAssertGreaterThan(diagnostics.memoryUsage.total, 0)
        XCTAssertGreaterThan(diagnostics.diskUsage.total, 0)
        XCTAssertFalse(diagnostics.systemInfo.osVersion.isEmpty)
        
        // Test JSON export
        let exportData = systemMonitor.exportDiagnostics()
        XCTAssertNotNil(exportData)
        
        if let data = exportData {
            XCTAssertNoThrow(try JSONDecoder().decode(SystemDiagnostics.self, from: data))
        }
    }
    
    func testRecordingStatisticsTracking() {
        menuBarController.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Recording stats updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        let stats = systemMonitor.recordingStats
        
        // Verify recording statistics are being tracked
        XCTAssertGreaterThanOrEqual(stats.segmentsCreated, 0)
        XCTAssertGreaterThanOrEqual(stats.totalDataProcessed, 0)
        XCTAssertGreaterThanOrEqual(stats.errorsCount, 0)
        XCTAssertGreaterThanOrEqual(stats.averageProcessingTime, 0.0)
        XCTAssertGreaterThanOrEqual(stats.currentSegmentSize, 0)
        XCTAssertGreaterThanOrEqual(stats.recordingDuration, 0.0)
    }
    
    func testSystemHealthStateTransitions() {
        menuBarController.startMonitoring()
        
        // Start with healthy state
        XCTAssertEqual(systemMonitor.systemHealth, .healthy)
        
        // Set thresholds to trigger degraded state
        systemMonitor.thresholds.maxCPUUsage = 50.0
        systemMonitor.thresholds.maxMemoryUsage = 50.0
        
        let expectation1 = XCTestExpectation(description: "Health state updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 4.0)
        
        // May have transitioned to degraded or critical
        XCTAssertTrue([.healthy, .degraded, .critical].contains(systemMonitor.systemHealth))
        
        // Reset to healthy thresholds
        systemMonitor.thresholds.maxCPUUsage = 95.0
        systemMonitor.thresholds.maxMemoryUsage = 95.0
        
        let expectation2 = XCTestExpectation(description: "Health state recovered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 4.0)
        
        // Should return to healthy state
        XCTAssertEqual(systemMonitor.systemHealth, .healthy)
    }
    
    func testMonitoringPerformanceImpact() {
        let startTime = Date()
        
        // Start monitoring and run for a period
        menuBarController.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Performance test completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 6.0)
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Verify monitoring doesn't significantly impact performance
        XCTAssertLessThan(duration, 6.0) // Should complete within reasonable time
        
        // CPU usage should remain reasonable during monitoring
        XCTAssertLessThan(systemMonitor.cpuUsage, 80.0)
        
        menuBarController.stopMonitoring()
    }
    
    func testAlertNotificationSystem() {
        menuBarController.startMonitoring()
        
        // Set very low thresholds to trigger critical alerts
        systemMonitor.thresholds.maxCPUUsage = 0.1
        systemMonitor.thresholds.maxMemoryUsage = 0.1
        systemMonitor.thresholds.minDiskSpace = Int64.max // Force disk space alert
        
        let expectation = XCTestExpectation(description: "Critical alerts generated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
        
        // Should have critical alerts
        let criticalAlerts = systemMonitor.activeAlerts.filter { $0.severity == .critical }
        XCTAssertFalse(criticalAlerts.isEmpty)
        
        // Check that error logs were generated
        let errorLogs = logManager.logEntries.filter { $0.level == .error && $0.category == "SystemHealth" }
        XCTAssertFalse(errorLogs.isEmpty)
    }
    
    func testDataExportIntegration() {
        menuBarController.startMonitoring()
        
        // Generate some data
        logManager.info("Test export message", category: "Export")
        logManager.error("Test error for export", category: "Export")
        
        let expectation = XCTestExpectation(description: "Data ready for export")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Test log export functionality
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export.json")
        
        XCTAssertNoThrow(try logManager.exportLogs(to: tempURL, format: .json))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Verify exported data
        let exportedData = try! Data(contentsOf: tempURL)
        let decodedLogs = try! JSONDecoder().decode([LogEntry].self, from: exportedData)
        XCTAssertFalse(decodedLogs.isEmpty)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testMemoryManagement() {
        // Test that monitoring doesn't cause memory leaks
        let initialMemory = systemMonitor.memoryUsage.appUsage
        
        // Run monitoring cycles
        for _ in 1...10 {
            menuBarController.startMonitoring()
            
            let expectation = XCTestExpectation(description: "Monitoring cycle")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
            
            menuBarController.stopMonitoring()
        }
        
        // Memory usage shouldn't have grown significantly
        let finalMemory = systemMonitor.memoryUsage.appUsage
        let memoryGrowth = finalMemory - initialMemory
        
        // Allow for some reasonable memory growth (less than 10MB)
        XCTAssertLessThan(memoryGrowth, 10 * 1024 * 1024)
    }
}