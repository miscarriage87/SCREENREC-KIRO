import XCTest
@testable import Shared

final class SystemMonitorTests: XCTestCase {
    var systemMonitor: SystemMonitor!
    
    override func setUp() {
        super.setUp()
        systemMonitor = SystemMonitor.shared
    }
    
    override func tearDown() {
        systemMonitor.stopMonitoring()
        super.tearDown()
    }
    
    func testSystemMonitorInitialization() {
        XCTAssertNotNil(systemMonitor)
        XCTAssertEqual(systemMonitor.systemHealth, .healthy)
        XCTAssertTrue(systemMonitor.activeAlerts.isEmpty)
    }
    
    func testMonitoringStartStop() {
        // Test starting monitoring
        systemMonitor.startMonitoring()
        
        // Wait a moment for initial metrics
        let expectation = XCTestExpectation(description: "Initial metrics collected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Verify metrics are being collected
        XCTAssertGreaterThanOrEqual(systemMonitor.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(systemMonitor.cpuUsage, 100.0)
        
        // Test stopping monitoring
        systemMonitor.stopMonitoring()
    }
    
    func testCPUUsageMetrics() {
        systemMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "CPU metrics updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // CPU usage should be within valid range
        XCTAssertGreaterThanOrEqual(systemMonitor.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(systemMonitor.cpuUsage, 100.0)
    }
    
    func testMemoryUsageMetrics() {
        systemMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Memory metrics updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let memoryUsage = systemMonitor.memoryUsage
        
        // Memory usage should be within valid range
        XCTAssertGreaterThan(memoryUsage.total, 0)
        XCTAssertGreaterThanOrEqual(memoryUsage.percentage, 0.0)
        XCTAssertLessThanOrEqual(memoryUsage.percentage, 100.0)
        XCTAssertLessThanOrEqual(memoryUsage.used, memoryUsage.total)
        XCTAssertEqual(memoryUsage.used + memoryUsage.free, memoryUsage.total)
    }
    
    func testDiskUsageMetrics() {
        systemMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Disk metrics updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let diskUsage = systemMonitor.diskUsage
        
        // Disk usage should be within valid range
        XCTAssertGreaterThan(diskUsage.total, 0)
        XCTAssertGreaterThanOrEqual(diskUsage.percentage, 0.0)
        XCTAssertLessThanOrEqual(diskUsage.percentage, 100.0)
        XCTAssertLessThanOrEqual(diskUsage.used, diskUsage.total)
    }
    
    func testRecordingStatistics() {
        systemMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Recording stats updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let stats = systemMonitor.recordingStats
        
        // Recording stats should be valid
        XCTAssertGreaterThanOrEqual(stats.segmentsCreated, 0)
        XCTAssertGreaterThanOrEqual(stats.totalDataProcessed, 0)
        XCTAssertGreaterThanOrEqual(stats.errorsCount, 0)
        XCTAssertGreaterThanOrEqual(stats.averageProcessingTime, 0.0)
        XCTAssertGreaterThanOrEqual(stats.currentSegmentSize, 0)
        XCTAssertGreaterThanOrEqual(stats.recordingDuration, 0.0)
    }
    
    func testSystemHealthMonitoring() {
        systemMonitor.startMonitoring()
        
        // Test healthy state
        XCTAssertEqual(systemMonitor.systemHealth, .healthy)
        XCTAssertTrue(systemMonitor.activeAlerts.isEmpty)
        
        // Test threshold configuration
        let originalThresholds = systemMonitor.thresholds
        
        // Set very low thresholds to trigger alerts
        systemMonitor.thresholds.maxCPUUsage = 1.0
        systemMonitor.thresholds.maxMemoryUsage = 1.0
        systemMonitor.thresholds.maxDiskUsage = 1.0
        
        let expectation = XCTestExpectation(description: "Health check triggered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
        
        // Should have alerts now
        XCTAssertFalse(systemMonitor.activeAlerts.isEmpty)
        XCTAssertNotEqual(systemMonitor.systemHealth, .healthy)
        
        // Restore original thresholds
        systemMonitor.thresholds = originalThresholds
    }
    
    func testAlertGeneration() {
        systemMonitor.startMonitoring()
        
        // Set very low thresholds to trigger alerts
        systemMonitor.thresholds.maxCPUUsage = 0.1
        systemMonitor.thresholds.maxMemoryUsage = 0.1
        
        let expectation = XCTestExpectation(description: "Alerts generated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
        
        // Should have performance alerts
        let performanceAlerts = systemMonitor.activeAlerts.filter { $0.type == .performance }
        XCTAssertFalse(performanceAlerts.isEmpty)
        
        // Check alert properties
        for alert in performanceAlerts {
            XCTAssertFalse(alert.title.isEmpty)
            XCTAssertFalse(alert.message.isEmpty)
            XCTAssertNotNil(alert.timestamp)
            XCTAssertTrue([.warning, .critical].contains(alert.severity))
        }
    }
    
    func testSystemDiagnosticsExport() {
        systemMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Diagnostics collected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let diagnostics = systemMonitor.getSystemDiagnostics()
        
        // Verify diagnostics structure
        XCTAssertNotNil(diagnostics.timestamp)
        XCTAssertGreaterThanOrEqual(diagnostics.cpuUsage, 0.0)
        XCTAssertGreaterThan(diagnostics.memoryUsage.total, 0)
        XCTAssertGreaterThan(diagnostics.diskUsage.total, 0)
        XCTAssertFalse(diagnostics.systemInfo.osVersion.isEmpty)
        XCTAssertFalse(diagnostics.systemInfo.hostName.isEmpty)
        XCTAssertGreaterThan(diagnostics.systemInfo.processorCount, 0)
        XCTAssertGreaterThan(diagnostics.systemInfo.physicalMemory, 0)
        
        // Test JSON export
        let exportData = systemMonitor.exportDiagnostics()
        XCTAssertNotNil(exportData)
        
        // Verify JSON can be decoded
        if let data = exportData {
            XCTAssertNoThrow(try JSONDecoder().decode(SystemDiagnostics.self, from: data))
        }
    }
    
    func testPerformanceUnderLoad() {
        systemMonitor.startMonitoring()
        
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Performance test completed")
        
        // Run for 10 seconds to test performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Verify monitoring didn't significantly impact performance
        XCTAssertLessThan(duration, 11.0) // Should complete within reasonable time
        
        // CPU usage should remain reasonable
        XCTAssertLessThan(systemMonitor.cpuUsage, 50.0) // Shouldn't use excessive CPU
    }
    
    func testThresholdConfiguration() {
        let originalThresholds = systemMonitor.thresholds
        
        // Test threshold modification
        systemMonitor.thresholds.maxCPUUsage = 75.0
        systemMonitor.thresholds.maxMemoryUsage = 80.0
        systemMonitor.thresholds.maxDiskUsage = 85.0
        
        XCTAssertEqual(systemMonitor.thresholds.maxCPUUsage, 75.0)
        XCTAssertEqual(systemMonitor.thresholds.maxMemoryUsage, 80.0)
        XCTAssertEqual(systemMonitor.thresholds.maxDiskUsage, 85.0)
        
        // Restore original thresholds
        systemMonitor.thresholds = originalThresholds
    }
    
    func testNetworkUsageTracking() {
        systemMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Network metrics updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
        
        let networkUsage = systemMonitor.networkUsage
        
        // Network usage should be valid
        XCTAssertGreaterThanOrEqual(networkUsage.bytesInPerSecond, 0)
        XCTAssertGreaterThanOrEqual(networkUsage.bytesOutPerSecond, 0)
        XCTAssertGreaterThanOrEqual(networkUsage.totalBytesIn, 0)
        XCTAssertGreaterThanOrEqual(networkUsage.totalBytesOut, 0)
    }
    
    func testMemoryLeakPrevention() {
        weak var weakMonitor: SystemMonitor?
        
        autoreleasepool {
            let monitor = SystemMonitor.shared
            weakMonitor = monitor
            monitor.startMonitoring()
            
            // Run monitoring for a short time
            let expectation = XCTestExpectation(description: "Monitoring cycle completed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 3.0)
            
            monitor.stopMonitoring()
        }
        
        // SystemMonitor is a singleton, so it should still exist
        XCTAssertNotNil(weakMonitor)
    }
}