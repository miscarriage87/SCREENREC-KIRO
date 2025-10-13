import Foundation
import os.log
import IOKit
import IOKit.ps

/// Comprehensive system monitoring for performance metrics and health alerts
public class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()
    
    // MARK: - Published Properties
    @Published public var cpuUsage: Double = 0.0
    @Published public var memoryUsage: MemoryUsage = MemoryUsage()
    @Published public var diskUsage: DiskUsage = DiskUsage()
    @Published public var networkUsage: NetworkUsage = NetworkUsage()
    @Published public var recordingStats: RecordingStatistics = RecordingStatistics()
    @Published public var systemHealth: SystemHealth = .healthy
    @Published public var activeAlerts: [SystemAlert] = []
    
    // MARK: - Configuration
    public struct Thresholds {
        var maxCPUUsage: Double = 80.0
        var maxMemoryUsage: Double = 85.0
        var maxDiskUsage: Double = 90.0
        var maxTemperature: Double = 85.0
        var minDiskSpace: Int64 = 1024 * 1024 * 1024 // 1GB
    }
    
    public var thresholds = Thresholds()
    
    // MARK: - Private Properties
    private var monitoringTimer: Timer?
    private let logger = os.Logger(subsystem: "com.alwaysonai.companion", category: "SystemMonitor")
    private let updateInterval: TimeInterval = 2.0
    private var previousCPUInfo: processor_info_array_t?
    private var previousNetworkStats: NetworkStats?
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    public func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        logger.info("Starting system monitoring")
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updateMetrics()
                self.checkSystemHealth()
            }
        }
        
        // Initial update
        Task { @MainActor in
            updateMetrics()
            checkSystemHealth()
        }
    }
    
    public func stopMonitoring() {
        logger.info("Stopping system monitoring")
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    public func getSystemDiagnostics() -> SystemDiagnostics {
        return SystemDiagnostics(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            networkUsage: networkUsage,
            recordingStats: recordingStats,
            systemHealth: systemHealth,
            activeAlerts: activeAlerts,
            systemInfo: getSystemInfo()
        )
    }
    
    public func exportDiagnostics() -> Data? {
        let diagnostics = getSystemDiagnostics()
        do {
            return try JSONEncoder().encode(diagnostics)
        } catch {
            logger.error("Failed to encode diagnostics: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func updateMetrics() {
        updateCPUUsage()
        updateMemoryUsage()
        updateDiskUsage()
        updateNetworkUsage()
        updateRecordingStats()
    }
    
    private func updateCPUUsage() {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
        
        guard result == KERN_SUCCESS else {
            logger.error("Failed to get CPU info: \(result)")
            return
        }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(Int(numCpuInfo) * MemoryLayout<integer_t>.size))
        }
        
        var totalUsage: Double = 0.0
        
        for i in 0..<Int(numCpus) {
            let cpuLoadInfo = cpuInfo.advanced(by: i * Int(CPU_STATE_MAX)).withMemoryRebound(to: integer_t.self, capacity: Int(CPU_STATE_MAX)) { $0 }
            
            let user = Double(cpuLoadInfo[Int(CPU_STATE_USER)])
            let system = Double(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            let nice = Double(cpuLoadInfo[Int(CPU_STATE_NICE)])
            let idle = Double(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            
            let total = user + system + nice + idle
            if total > 0 {
                totalUsage += ((user + system + nice) / total) * 100.0
            }
        }
        
        DispatchQueue.main.async {
            self.cpuUsage = totalUsage / Double(numCpus)
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            logger.error("Failed to get memory info: \(result)")
            return
        }
        
        // Get system memory info
        var vmStats = vm_statistics64()
        var vmStatsCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmStatsCount)
            }
        }
        
        guard vmResult == KERN_SUCCESS else {
            logger.error("Failed to get VM stats: \(vmResult)")
            return
        }
        
        let pageSize = vm_kernel_page_size
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let freeMemory = UInt64(vmStats.free_count) * UInt64(pageSize)
        let usedMemory = totalMemory - freeMemory
        
        DispatchQueue.main.async {
            self.memoryUsage = MemoryUsage(
                total: totalMemory,
                used: usedMemory,
                free: freeMemory,
                appUsage: UInt64(info.resident_size),
                percentage: Double(usedMemory) / Double(totalMemory) * 100.0
            )
        }
    }
    
    private func updateDiskUsage() {
        let fileManager = FileManager.default
        
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get documents directory")
            return
        }
        
        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey
            ])
            
            let totalCapacity = resourceValues.volumeTotalCapacity ?? 0
            let availableCapacity = resourceValues.volumeAvailableCapacity ?? 0
            let usedCapacity = totalCapacity - availableCapacity
            
            // Calculate I/O statistics (simplified)
            let ioStats = getDiskIOStats()
            
            DispatchQueue.main.async {
                self.diskUsage = DiskUsage(
                    total: Int64(totalCapacity),
                    used: Int64(usedCapacity),
                    free: Int64(availableCapacity),
                    percentage: Double(usedCapacity) / Double(totalCapacity) * 100.0,
                    readBytesPerSecond: ioStats.readBytes,
                    writeBytesPerSecond: ioStats.writeBytes
                )
            }
        } catch {
            logger.error("Failed to get disk usage: \(error.localizedDescription)")
        }
    }
    
    private func updateNetworkUsage() {
        let networkStats = getNetworkStats()
        
        if let previous = previousNetworkStats {
            let timeDelta = networkStats.timestamp.timeIntervalSince(previous.timestamp)
            let bytesInDelta = networkStats.bytesIn - previous.bytesIn
            let bytesOutDelta = networkStats.bytesOut - previous.bytesOut
            
            DispatchQueue.main.async {
                self.networkUsage = NetworkUsage(
                    bytesInPerSecond: Int64(Double(bytesInDelta) / timeDelta),
                    bytesOutPerSecond: Int64(Double(bytesOutDelta) / timeDelta),
                    totalBytesIn: networkStats.bytesIn,
                    totalBytesOut: networkStats.bytesOut
                )
            }
        }
        
        previousNetworkStats = networkStats
    }
    
    private func updateRecordingStats() {
        // This would typically query the recording system for current statistics
        // For now, we'll simulate some basic stats
        
        let stats = RecordingStatistics(
            segmentsCreated: getSegmentCount(),
            totalDataProcessed: getTotalDataProcessed(),
            errorsCount: getErrorCount(),
            averageProcessingTime: getAverageProcessingTime(),
            currentSegmentSize: getCurrentSegmentSize(),
            recordingDuration: getRecordingDuration()
        )
        
        DispatchQueue.main.async {
            self.recordingStats = stats
        }
    }
    
    @MainActor
    private func checkSystemHealth() {
        var newAlerts: [SystemAlert] = []
        var healthStatus: SystemHealth = .healthy
        
        // Check CPU usage
        if cpuUsage > thresholds.maxCPUUsage {
            newAlerts.append(SystemAlert(
                id: "high_cpu",
                type: .performance,
                severity: cpuUsage > 90 ? .critical : .warning,
                title: "High CPU Usage",
                message: "CPU usage is \(String(format: "%.1f", cpuUsage))%",
                timestamp: Date()
            ))
            healthStatus = .degraded
        }
        
        // Check memory usage
        if memoryUsage.percentage > thresholds.maxMemoryUsage {
            newAlerts.append(SystemAlert(
                id: "high_memory",
                type: .performance,
                severity: memoryUsage.percentage > 95 ? .critical : .warning,
                title: "High Memory Usage",
                message: "Memory usage is \(String(format: "%.1f", memoryUsage.percentage))%",
                timestamp: Date()
            ))
            healthStatus = .degraded
        }
        
        // Check disk usage
        if diskUsage.percentage > thresholds.maxDiskUsage {
            newAlerts.append(SystemAlert(
                id: "high_disk",
                type: .storage,
                severity: diskUsage.percentage > 95 ? .critical : .warning,
                title: "High Disk Usage",
                message: "Disk usage is \(String(format: "%.1f", diskUsage.percentage))%",
                timestamp: Date()
            ))
            healthStatus = .degraded
        }
        
        // Check available disk space
        if diskUsage.free < thresholds.minDiskSpace {
            newAlerts.append(SystemAlert(
                id: "low_disk_space",
                type: .storage,
                severity: .critical,
                title: "Low Disk Space",
                message: "Only \(ByteCountFormatter.string(fromByteCount: diskUsage.free, countStyle: .file)) remaining",
                timestamp: Date()
            ))
            healthStatus = .critical
        }
        
        // Check recording errors
        if recordingStats.errorsCount > 10 {
            newAlerts.append(SystemAlert(
                id: "recording_errors",
                type: .recording,
                severity: .warning,
                title: "Recording Errors",
                message: "\(recordingStats.errorsCount) errors detected",
                timestamp: Date()
            ))
            healthStatus = .degraded
        }
        
        // Update alerts (remove resolved ones, add new ones)
        activeAlerts = newAlerts
        systemHealth = healthStatus
        
        // Log health changes
        if systemHealth != .healthy {
            logger.warning("System health: \(self.systemHealth.rawValue), alerts: \(self.activeAlerts.count)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDiskIOStats() -> (readBytes: Int64, writeBytes: Int64) {
        // Simplified I/O stats - in a real implementation, this would use IOKit
        return (readBytes: Int64.random(in: 1024...10240), writeBytes: Int64.random(in: 2048...20480))
    }
    
    private func getNetworkStats() -> NetworkStats {
        // Simplified network stats - in a real implementation, this would use system APIs
        return NetworkStats(
            bytesIn: Int64.random(in: 1000...100000),
            bytesOut: Int64.random(in: 500...50000),
            timestamp: Date()
        )
    }
    
    private func getSystemInfo() -> SystemDiagnosticInfo {
        let processInfo = ProcessInfo.processInfo
        return SystemDiagnosticInfo(
            osVersion: processInfo.operatingSystemVersionString,
            hostName: processInfo.hostName,
            processorCount: processInfo.processorCount,
            physicalMemory: processInfo.physicalMemory,
            uptime: processInfo.systemUptime
        )
    }
    
    private func getSegmentCount() -> Int {
        // This would query the actual recording system
        return Int.random(in: 100...1000)
    }
    
    private func getTotalDataProcessed() -> Int64 {
        // This would query the actual recording system
        return Int64.random(in: 1024*1024*100...1024*1024*1000) // 100MB to 1GB
    }
    
    private func getErrorCount() -> Int {
        // This would query the actual error logging system
        return Int.random(in: 0...20)
    }
    
    private func getAverageProcessingTime() -> TimeInterval {
        // This would calculate from actual processing metrics
        return Double.random(in: 0.1...2.0)
    }
    
    private func getCurrentSegmentSize() -> Int64 {
        // This would query the current recording segment
        return Int64.random(in: 1024*1024*10...1024*1024*50) // 10MB to 50MB
    }
    
    private func getRecordingDuration() -> TimeInterval {
        // This would query the actual recording system
        return Double.random(in: 3600...86400) // 1 hour to 24 hours
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Data Structures

public struct MemoryUsage: Codable {
    public let total: UInt64
    public let used: UInt64
    public let free: UInt64
    public let appUsage: UInt64
    public let percentage: Double
    
    public init(total: UInt64 = 0, used: UInt64 = 0, free: UInt64 = 0, appUsage: UInt64 = 0, percentage: Double = 0.0) {
        self.total = total
        self.used = used
        self.free = free
        self.appUsage = appUsage
        self.percentage = percentage
    }
}

public struct DiskUsage: Codable {
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let percentage: Double
    public let readBytesPerSecond: Int64
    public let writeBytesPerSecond: Int64
    
    public init(total: Int64 = 0, used: Int64 = 0, free: Int64 = 0, percentage: Double = 0.0, readBytesPerSecond: Int64 = 0, writeBytesPerSecond: Int64 = 0) {
        self.total = total
        self.used = used
        self.free = free
        self.percentage = percentage
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
    }
}

public struct NetworkUsage: Codable {
    public let bytesInPerSecond: Int64
    public let bytesOutPerSecond: Int64
    public let totalBytesIn: Int64
    public let totalBytesOut: Int64
    
    public init(bytesInPerSecond: Int64 = 0, bytesOutPerSecond: Int64 = 0, totalBytesIn: Int64 = 0, totalBytesOut: Int64 = 0) {
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
    }
}

public struct RecordingStatistics: Codable {
    public let segmentsCreated: Int
    public let totalDataProcessed: Int64
    public let errorsCount: Int
    public let averageProcessingTime: TimeInterval
    public let currentSegmentSize: Int64
    public let recordingDuration: TimeInterval
    
    public init(segmentsCreated: Int = 0, totalDataProcessed: Int64 = 0, errorsCount: Int = 0, averageProcessingTime: TimeInterval = 0.0, currentSegmentSize: Int64 = 0, recordingDuration: TimeInterval = 0.0) {
        self.segmentsCreated = segmentsCreated
        self.totalDataProcessed = totalDataProcessed
        self.errorsCount = errorsCount
        self.averageProcessingTime = averageProcessingTime
        self.currentSegmentSize = currentSegmentSize
        self.recordingDuration = recordingDuration
    }
}

public enum SystemHealth: String, Codable, CaseIterable {
    case healthy = "healthy"
    case degraded = "degraded"
    case critical = "critical"
    
    public var color: String {
        switch self {
        case .healthy: return "green"
        case .degraded: return "yellow"
        case .critical: return "red"
        }
    }
}

public struct SystemAlert: Codable, Identifiable {
    public let id: String
    public let type: AlertType
    public let severity: AlertSeverity
    public let title: String
    public let message: String
    public let timestamp: Date
    
    public enum AlertType: String, Codable {
        case performance = "performance"
        case storage = "storage"
        case recording = "recording"
        case network = "network"
        case system = "system"
    }
    
    public enum AlertSeverity: String, Codable {
        case info = "info"
        case warning = "warning"
        case critical = "critical"
    }
}

private struct NetworkStats {
    let bytesIn: Int64
    let bytesOut: Int64
    let timestamp: Date
}

public struct SystemDiagnosticInfo: Codable {
    public let osVersion: String
    public let hostName: String
    public let processorCount: Int
    public let physicalMemory: UInt64
    public let uptime: TimeInterval
}

public struct SystemDiagnostics: Codable {
    public let timestamp: Date
    public let cpuUsage: Double
    public let memoryUsage: MemoryUsage
    public let diskUsage: DiskUsage
    public let networkUsage: NetworkUsage
    public let recordingStats: RecordingStatistics
    public let systemHealth: SystemHealth
    public let activeAlerts: [SystemAlert]
    public let systemInfo: SystemDiagnosticInfo
}