#!/usr/bin/env swift

import Foundation
import SwiftUI

// MARK: - Validation Script for System Monitoring and Status Display

print("🔍 Always-On AI Companion - System Monitoring Validation")
print("=" * 60)

// MARK: - Test Configuration
struct ValidationConfig {
    static let testDuration: TimeInterval = 10.0
    static let metricsUpdateInterval: TimeInterval = 2.0
    static let performanceThreshold = (cpu: 50.0, memory: 80.0, disk: 90.0)
    static let responseTimeThreshold: TimeInterval = 0.1 // 100ms
}

// MARK: - Validation Tests

func validateSystemMonitorInitialization() -> Bool {
    print("\n📊 Testing System Monitor Initialization...")
    
    // Test that SystemMonitor can be initialized
    guard let _ = try? SystemMonitor.shared else {
        print("❌ Failed to initialize SystemMonitor")
        return false
    }
    
    print("✅ SystemMonitor initialized successfully")
    return true
}

func validatePerformanceMetricsCollection() -> Bool {
    print("\n📈 Testing Performance Metrics Collection...")
    
    let systemMonitor = SystemMonitor.shared
    systemMonitor.startMonitoring()
    
    // Wait for initial metrics collection
    Thread.sleep(forTimeInterval: 3.0)
    
    // Validate CPU metrics
    let cpuUsage = systemMonitor.cpuUsage
    guard cpuUsage >= 0.0 && cpuUsage <= 100.0 else {
        print("❌ Invalid CPU usage: \(cpuUsage)%")
        return false
    }
    print("✅ CPU Usage: \(String(format: "%.1f", cpuUsage))%")
    
    // Validate memory metrics
    let memoryUsage = systemMonitor.memoryUsage
    guard memoryUsage.total > 0 && memoryUsage.percentage >= 0.0 && memoryUsage.percentage <= 100.0 else {
        print("❌ Invalid memory usage: \(memoryUsage.percentage)%")
        return false
    }
    print("✅ Memory Usage: \(String(format: "%.1f", memoryUsage.percentage))% (\(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage.used), countStyle: .memory)))")
    
    // Validate disk metrics
    let diskUsage = systemMonitor.diskUsage
    guard diskUsage.total > 0 && diskUsage.percentage >= 0.0 && diskUsage.percentage <= 100.0 else {
        print("❌ Invalid disk usage: \(diskUsage.percentage)%")
        return false
    }
    print("✅ Disk Usage: \(String(format: "%.1f", diskUsage.percentage))% (\(ByteCountFormatter.string(fromByteCount: diskUsage.used, countStyle: .file)))")
    
    // Validate network metrics
    let networkUsage = systemMonitor.networkUsage
    guard networkUsage.bytesInPerSecond >= 0 && networkUsage.bytesOutPerSecond >= 0 else {
        print("❌ Invalid network usage")
        return false
    }
    print("✅ Network I/O: ↓\(ByteCountFormatter.string(fromByteCount: networkUsage.bytesInPerSecond, countStyle: .file))/s ↑\(ByteCountFormatter.string(fromByteCount: networkUsage.bytesOutPerSecond, countStyle: .file))/s")
    
    systemMonitor.stopMonitoring()
    return true
}

func validateRecordingStatistics() -> Bool {
    print("\n📹 Testing Recording Statistics...")
    
    let systemMonitor = SystemMonitor.shared
    systemMonitor.startMonitoring()
    
    Thread.sleep(forTimeInterval: 2.0)
    
    let stats = systemMonitor.recordingStats
    
    // Validate recording statistics structure
    guard stats.segmentsCreated >= 0 else {
        print("❌ Invalid segments created: \(stats.segmentsCreated)")
        return false
    }
    
    guard stats.totalDataProcessed >= 0 else {
        print("❌ Invalid total data processed: \(stats.totalDataProcessed)")
        return false
    }
    
    guard stats.errorsCount >= 0 else {
        print("❌ Invalid error count: \(stats.errorsCount)")
        return false
    }
    
    guard stats.averageProcessingTime >= 0.0 else {
        print("❌ Invalid average processing time: \(stats.averageProcessingTime)")
        return false
    }
    
    print("✅ Segments Created: \(stats.segmentsCreated)")
    print("✅ Total Data Processed: \(ByteCountFormatter.string(fromByteCount: stats.totalDataProcessed, countStyle: .file))")
    print("✅ Error Count: \(stats.errorsCount)")
    print("✅ Average Processing Time: \(String(format: "%.2f", stats.averageProcessingTime))s")
    print("✅ Recording Duration: \(formatDuration(stats.recordingDuration))")
    
    systemMonitor.stopMonitoring()
    return true
}

func validateSystemHealthMonitoring() -> Bool {
    print("\n🏥 Testing System Health Monitoring...")
    
    let systemMonitor = SystemMonitor.shared
    systemMonitor.startMonitoring()
    
    // Test initial health state
    let initialHealth = systemMonitor.systemHealth
    print("✅ Initial Health State: \(initialHealth.rawValue)")
    
    // Test threshold configuration
    let originalThresholds = systemMonitor.thresholds
    
    // Set very low thresholds to trigger alerts
    systemMonitor.thresholds.maxCPUUsage = 1.0
    systemMonitor.thresholds.maxMemoryUsage = 1.0
    systemMonitor.thresholds.maxDiskUsage = 1.0
    
    // Wait for health check
    Thread.sleep(forTimeInterval: 4.0)
    
    // Should have alerts now
    let alerts = systemMonitor.activeAlerts
    guard !alerts.isEmpty else {
        print("❌ No alerts generated with low thresholds")
        systemMonitor.thresholds = originalThresholds
        systemMonitor.stopMonitoring()
        return false
    }
    
    print("✅ Generated \(alerts.count) alerts:")
    for alert in alerts {
        print("  - \(alert.severity.rawValue.uppercased()): \(alert.title) - \(alert.message)")
    }
    
    // Health should be degraded or critical
    let currentHealth = systemMonitor.systemHealth
    guard currentHealth != .healthy else {
        print("❌ Health state should not be healthy with active alerts")
        systemMonitor.thresholds = originalThresholds
        systemMonitor.stopMonitoring()
        return false
    }
    
    print("✅ Health State Changed: \(initialHealth.rawValue) → \(currentHealth.rawValue)")
    
    // Restore thresholds
    systemMonitor.thresholds = originalThresholds
    systemMonitor.stopMonitoring()
    return true
}

func validateLogManagement() -> Bool {
    print("\n📝 Testing Log Management...")
    
    let logManager = LogManager.shared
    logManager.clearLogs()
    
    // Test different log levels
    logManager.debug("Debug message for validation", category: "Validation")
    logManager.info("Info message for validation", category: "Validation")
    logManager.warning("Warning message for validation", category: "Validation")
    logManager.error("Error message for validation", category: "Validation")
    logManager.critical("Critical message for validation", category: "Validation")
    
    // Verify logs were added
    guard logManager.logEntries.count == 5 else {
        print("❌ Expected 5 log entries, got \(logManager.logEntries.count)")
        return false
    }
    
    print("✅ Created 5 log entries with different levels")
    
    // Test log filtering
    var filter = LogFilter()
    filter.levels = [.error, .fault]
    logManager.applyFilter(filter)
    
    guard logManager.filteredEntries.count == 2 else {
        print("❌ Expected 2 filtered entries, got \(logManager.filteredEntries.count)")
        return false
    }
    
    print("✅ Log filtering works correctly")
    
    // Test log statistics
    let stats = logManager.getLogStatistics()
    guard stats.totalEntries == 5 else {
        print("❌ Expected 5 total entries in stats, got \(stats.totalEntries)")
        return false
    }
    
    guard stats.errorCount == 2 else { // error + critical
        print("❌ Expected 2 error entries in stats, got \(stats.errorCount)")
        return false
    }
    
    print("✅ Log statistics calculated correctly")
    
    // Test log export
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("validation_logs.json")
    
    do {
        try logManager.exportLogs(to: tempURL, format: .json)
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            print("❌ Log export file not created")
            return false
        }
        
        let exportedData = try Data(contentsOf: tempURL)
        let decodedLogs = try JSONDecoder().decode([LogEntry].self, from: exportedData)
        
        guard decodedLogs.count == 5 else {
            print("❌ Expected 5 exported logs, got \(decodedLogs.count)")
            return false
        }
        
        print("✅ Log export works correctly")
        
        // Clean up
        try FileManager.default.removeItem(at: tempURL)
        
    } catch {
        print("❌ Log export failed: \(error)")
        return false
    }
    
    return true
}

func validateDiagnosticsExport() -> Bool {
    print("\n🔧 Testing Diagnostics Export...")
    
    let systemMonitor = SystemMonitor.shared
    systemMonitor.startMonitoring()
    
    Thread.sleep(forTimeInterval: 2.0)
    
    // Test diagnostics generation
    let diagnostics = systemMonitor.getSystemDiagnostics()
    
    // Validate diagnostics structure
    guard !diagnostics.systemInfo.osVersion.isEmpty else {
        print("❌ Missing OS version in diagnostics")
        return false
    }
    
    guard !diagnostics.systemInfo.hostName.isEmpty else {
        print("❌ Missing host name in diagnostics")
        return false
    }
    
    guard diagnostics.systemInfo.processorCount > 0 else {
        print("❌ Invalid processor count: \(diagnostics.systemInfo.processorCount)")
        return false
    }
    
    guard diagnostics.systemInfo.physicalMemory > 0 else {
        print("❌ Invalid physical memory: \(diagnostics.systemInfo.physicalMemory)")
        return false
    }
    
    print("✅ System Info:")
    print("  - OS: \(diagnostics.systemInfo.osVersion)")
    print("  - Host: \(diagnostics.systemInfo.hostName)")
    print("  - CPUs: \(diagnostics.systemInfo.processorCount)")
    print("  - Memory: \(ByteCountFormatter.string(fromByteCount: Int64(diagnostics.systemInfo.physicalMemory), countStyle: .memory))")
    print("  - Uptime: \(formatDuration(diagnostics.systemInfo.uptime))")
    
    // Test JSON export
    guard let exportData = systemMonitor.exportDiagnostics() else {
        print("❌ Failed to export diagnostics data")
        return false
    }
    
    // Verify JSON can be decoded
    do {
        let decodedDiagnostics = try JSONDecoder().decode(SystemDiagnostics.self, from: exportData)
        guard decodedDiagnostics.systemInfo.osVersion == diagnostics.systemInfo.osVersion else {
            print("❌ Exported diagnostics don't match original")
            return false
        }
        print("✅ Diagnostics export and decode successful")
    } catch {
        print("❌ Failed to decode exported diagnostics: \(error)")
        return false
    }
    
    systemMonitor.stopMonitoring()
    return true
}

func validatePerformanceImpact() -> Bool {
    print("\n⚡ Testing Performance Impact...")
    
    let systemMonitor = SystemMonitor.shared
    
    // Measure baseline CPU usage
    systemMonitor.startMonitoring()
    Thread.sleep(forTimeInterval: 2.0)
    let baselineCPU = systemMonitor.cpuUsage
    
    // Run monitoring for extended period
    let startTime = Date()
    Thread.sleep(forTimeInterval: ValidationConfig.testDuration)
    let endTime = Date()
    
    let finalCPU = systemMonitor.cpuUsage
    let duration = endTime.timeIntervalSince(startTime)
    
    // Verify timing accuracy
    guard abs(duration - ValidationConfig.testDuration) < 1.0 else {
        print("❌ Timing inaccuracy: expected \(ValidationConfig.testDuration)s, got \(duration)s")
        return false
    }
    
    // Verify CPU usage remains reasonable
    guard finalCPU < ValidationConfig.performanceThreshold.cpu else {
        print("❌ High CPU usage during monitoring: \(finalCPU)%")
        return false
    }
    
    // Verify memory usage is reasonable
    let memoryUsage = systemMonitor.memoryUsage.percentage
    guard memoryUsage < ValidationConfig.performanceThreshold.memory else {
        print("❌ High memory usage during monitoring: \(memoryUsage)%")
        return false
    }
    
    print("✅ Performance Impact Test:")
    print("  - Duration: \(String(format: "%.1f", duration))s")
    print("  - CPU Usage: \(String(format: "%.1f", finalCPU))% (threshold: \(ValidationConfig.performanceThreshold.cpu)%)")
    print("  - Memory Usage: \(String(format: "%.1f", memoryUsage))% (threshold: \(ValidationConfig.performanceThreshold.memory)%)")
    
    systemMonitor.stopMonitoring()
    return true
}

func validateAlertSystem() -> Bool {
    print("\n🚨 Testing Alert System...")
    
    let systemMonitor = SystemMonitor.shared
    systemMonitor.startMonitoring()
    
    // Test alert generation with different severities
    let originalThresholds = systemMonitor.thresholds
    
    // Set thresholds to trigger different alert types
    systemMonitor.thresholds.maxCPUUsage = 0.1 // Very low to trigger alert
    systemMonitor.thresholds.maxMemoryUsage = 0.1
    systemMonitor.thresholds.maxDiskUsage = 0.1
    systemMonitor.thresholds.minDiskSpace = Int64.max // Force disk space alert
    
    Thread.sleep(forTimeInterval: 4.0)
    
    let alerts = systemMonitor.activeAlerts
    
    // Should have multiple alerts
    guard alerts.count >= 2 else {
        print("❌ Expected multiple alerts, got \(alerts.count)")
        systemMonitor.thresholds = originalThresholds
        systemMonitor.stopMonitoring()
        return false
    }
    
    // Check alert types
    let alertTypes = Set(alerts.map { $0.type })
    let expectedTypes: Set<SystemAlert.AlertType> = [.performance, .storage]
    
    guard !alertTypes.intersection(expectedTypes).isEmpty else {
        print("❌ Expected performance or storage alerts, got: \(alertTypes)")
        systemMonitor.thresholds = originalThresholds
        systemMonitor.stopMonitoring()
        return false
    }
    
    // Check alert severities
    let severities = Set(alerts.map { $0.severity })
    guard severities.contains(.critical) || severities.contains(.warning) else {
        print("❌ Expected critical or warning alerts, got: \(severities)")
        systemMonitor.thresholds = originalThresholds
        systemMonitor.stopMonitoring()
        return false
    }
    
    print("✅ Alert System Test:")
    print("  - Generated \(alerts.count) alerts")
    print("  - Alert Types: \(alertTypes.map { $0.rawValue }.joined(separator: ", "))")
    print("  - Severities: \(severities.map { $0.rawValue }.joined(separator: ", "))")
    
    // Verify alert properties
    for alert in alerts {
        guard !alert.title.isEmpty && !alert.message.isEmpty else {
            print("❌ Alert missing title or message")
            systemMonitor.thresholds = originalThresholds
            systemMonitor.stopMonitoring()
            return false
        }
        
        guard alert.timestamp.timeIntervalSinceNow > -60 else {
            print("❌ Alert timestamp too old")
            systemMonitor.thresholds = originalThresholds
            systemMonitor.stopMonitoring()
            return false
        }
    }
    
    print("✅ All alerts have valid properties")
    
    systemMonitor.thresholds = originalThresholds
    systemMonitor.stopMonitoring()
    return true
}

// MARK: - Helper Functions

func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    let seconds = Int(duration) % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Main Validation

func runValidation() -> Bool {
    var allTestsPassed = true
    
    let tests: [(String, () -> Bool)] = [
        ("System Monitor Initialization", validateSystemMonitorInitialization),
        ("Performance Metrics Collection", validatePerformanceMetricsCollection),
        ("Recording Statistics", validateRecordingStatistics),
        ("System Health Monitoring", validateSystemHealthMonitoring),
        ("Log Management", validateLogManagement),
        ("Diagnostics Export", validateDiagnosticsExport),
        ("Performance Impact", validatePerformanceImpact),
        ("Alert System", validateAlertSystem)
    ]
    
    for (testName, testFunction) in tests {
        print("\n" + "─" * 60)
        print("Running: \(testName)")
        print("─" * 60)
        
        let testPassed = testFunction()
        allTestsPassed = allTestsPassed && testPassed
        
        if testPassed {
            print("✅ \(testName): PASSED")
        } else {
            print("❌ \(testName): FAILED")
        }
    }
    
    return allTestsPassed
}

// MARK: - Execution

let validationPassed = runValidation()

print("\n" + "=" * 60)
if validationPassed {
    print("🎉 ALL VALIDATION TESTS PASSED!")
    print("✅ System monitoring and status display is working correctly")
    print("✅ Performance metrics collection is accurate")
    print("✅ System health monitoring is functional")
    print("✅ Log management system is operational")
    print("✅ Diagnostics export is working")
    print("✅ Alert system is responsive")
    print("✅ Performance impact is within acceptable limits")
} else {
    print("❌ SOME VALIDATION TESTS FAILED!")
    print("Please check the output above for specific failures")
    exit(1)
}

print("=" * 60)
print("📊 System Monitoring Validation Complete")

exit(0)