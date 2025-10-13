import XCTest
import Foundation
@testable import Shared

class RetentionPolicyManagerTests: XCTestCase {
    var tempDirectory: URL!
    var configurationManager: ConfigurationManager!
    var retentionManager: RetentionPolicyManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetentionPolicyTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test configuration manager
        configurationManager = ConfigurationManager()
        
        // Create retention manager
        retentionManager = RetentionPolicyManager(configurationManager: configurationManager)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultRetentionConfiguration() {
        let config = retentionManager.loadRetentionConfiguration()
        
        XCTAssertTrue(config.enableBackgroundCleanup)
        XCTAssertEqual(config.safetyMarginHours, 24)
        XCTAssertEqual(config.maxFilesPerCleanupBatch, 100)
        XCTAssertTrue(config.verificationEnabled)
        
        // Check default policies
        XCTAssertEqual(config.policies[.rawVideo]?.retentionDays, 30)
        XCTAssertEqual(config.policies[.frameMetadata]?.retentionDays, 90)
        XCTAssertEqual(config.policies[.ocrData]?.retentionDays, 90)
        XCTAssertEqual(config.policies[.events]?.retentionDays, 365)
        XCTAssertEqual(config.policies[.spans]?.retentionDays, -1) // Permanent
        XCTAssertEqual(config.policies[.summaries]?.retentionDays, -1) // Permanent
    }
    
    func testCustomRetentionConfiguration() {
        let customPolicies: [DataType: RetentionPolicy] = [
            .rawVideo: RetentionPolicy(dataType: .rawVideo, retentionDays: 14),
            .frameMetadata: RetentionPolicy(dataType: .frameMetadata, retentionDays: 60)
        ]
        
        let customConfig = RetentionConfiguration(
            policies: customPolicies,
            enableBackgroundCleanup: false,
            safetyMarginHours: 12,
            maxFilesPerCleanupBatch: 50,
            verificationEnabled: false
        )
        
        XCTAssertNoThrow(try retentionManager.saveRetentionConfiguration(customConfig))
    }
    
    // MARK: - File Creation Helpers
    
    private func createTestVideoFiles(count: Int, daysOld: Int, in directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var files: [URL] = []
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_video_\(i).mp4"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "Test video content \(i)".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
            
            files.append(fileURL)
        }
        
        return files
    }
    
    private func createTestParquetFiles(count: Int, daysOld: Int, in directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var files: [URL] = []
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_data_\(i).parquet"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "Test parquet content \(i)".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
            
            files.append(fileURL)
        }
        
        return files
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupOldVideoFiles() throws {
        // Create test storage structure
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create old files (should be deleted)
        let oldFiles = try createTestVideoFiles(count: 5, daysOld: 35, in: videosURL)
        
        // Create recent files (should be kept)
        let recentFiles = try createTestVideoFiles(count: 3, daysOld: 10, in: videosURL)
        
        // Update configuration to use test storage
        let testConfig = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: storageURL,
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info,
            enableRetentionPolicies: true,
            retentionCheckIntervalHours: 24
        )
        
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Perform cleanup
        let stats = try retentionManager.performCleanup(for: .rawVideo)
        
        // Verify results
        XCTAssertEqual(stats.dataType, .rawVideo)
        XCTAssertEqual(stats.filesScanned, 8) // 5 old + 3 recent
        XCTAssertEqual(stats.filesDeleted, 5) // Only old files
        XCTAssertTrue(stats.bytesFreed > 0)
        XCTAssertTrue(stats.errors.isEmpty)
        
        // Verify old files are deleted
        for fileURL in oldFiles {
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        }
        
        // Verify recent files are kept
        for fileURL in recentFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }
    
    func testCleanupFrameMetadata() throws {
        // Create test storage structure
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let framesURL = storageURL.appendingPathComponent("frames")
        
        // Create old files (should be deleted)
        let oldFiles = try createTestParquetFiles(count: 3, daysOld: 100, in: framesURL)
        
        // Create recent files (should be kept)
        let recentFiles = try createTestParquetFiles(count: 2, daysOld: 30, in: framesURL)
        
        // Update configuration
        let testConfig = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: storageURL,
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info,
            enableRetentionPolicies: true,
            retentionCheckIntervalHours: 24
        )
        
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Perform cleanup
        let stats = try retentionManager.performCleanup(for: .frameMetadata)
        
        // Verify results
        XCTAssertEqual(stats.dataType, .frameMetadata)
        XCTAssertEqual(stats.filesScanned, 5)
        XCTAssertEqual(stats.filesDeleted, 3) // Only old files
        
        // Verify old files are deleted
        for fileURL in oldFiles {
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        }
        
        // Verify recent files are kept
        for fileURL in recentFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }
    
    func testCleanupWithNonExistentDirectory() throws {
        // Create test configuration with non-existent storage
        let storageURL = tempDirectory.appendingPathComponent("nonexistent")
        
        let testConfig = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: storageURL,
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info,
            enableRetentionPolicies: true,
            retentionCheckIntervalHours: 24
        )
        
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Perform cleanup - should handle gracefully
        let stats = try retentionManager.performCleanup(for: .rawVideo)
        
        XCTAssertEqual(stats.filesScanned, 0)
        XCTAssertEqual(stats.filesDeleted, 0)
        XCTAssertEqual(stats.bytesFreed, 0)
        XCTAssertFalse(stats.errors.isEmpty) // Should have error about missing path
    }
    
    // MARK: - Estimation Tests
    
    func testCleanupSpaceEstimation() throws {
        // Create test storage structure
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create old files with known sizes
        let oldFiles = try createTestVideoFiles(count: 3, daysOld: 35, in: videosURL)
        let recentFiles = try createTestVideoFiles(count: 2, daysOld: 10, in: videosURL)
        
        // Update configuration
        let testConfig = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: storageURL,
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info,
            enableRetentionPolicies: true,
            retentionCheckIntervalHours: 24
        )
        
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Get estimation
        let estimatedSpace = try retentionManager.estimateCleanupSpace(for: .rawVideo)
        
        // Should estimate space for old files only
        XCTAssertGreaterThan(estimatedSpace, 0)
        
        // Calculate expected size of old files
        var expectedSize: Int64 = 0
        for fileURL in oldFiles {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            expectedSize += attributes[.size] as? Int64 ?? 0
        }
        
        XCTAssertEqual(estimatedSpace, expectedSize)
    }
    
    // MARK: - Background Cleanup Tests
    
    func testBackgroundCleanupStartStop() {
        // Test starting background cleanup
        retentionManager.startBackgroundCleanup()
        
        // Test stopping background cleanup
        retentionManager.stopBackgroundCleanup()
        
        // Should not crash or throw errors
        XCTAssertTrue(true)
    }
    
    // MARK: - Error Handling Tests
    
    func testCleanupWithInvalidConfiguration() {
        // Clear configuration
        let invalidConfig = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: URL(fileURLWithPath: "/invalid/path"),
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info,
            enableRetentionPolicies: true,
            retentionCheckIntervalHours: 24
        )
        
        XCTAssertTrue(configurationManager.saveConfiguration(invalidConfig))
        
        // Should handle invalid configuration gracefully
        XCTAssertNoThrow(try retentionManager.performCleanup(for: .rawVideo))
    }
    
    // MARK: - Performance Tests
    
    func testCleanupPerformanceWithManyFiles() throws {
        // Create test storage structure
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create many old files
        let oldFiles = try createTestVideoFiles(count: 100, daysOld: 35, in: videosURL)
        
        // Update configuration
        let testConfig = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: storageURL,
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info,
            enableRetentionPolicies: true,
            retentionCheckIntervalHours: 24
        )
        
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Measure cleanup performance
        let startTime = Date()
        let stats = try retentionManager.performCleanup(for: .rawVideo)
        let duration = Date().timeIntervalSince(startTime)
        
        // Verify cleanup completed
        XCTAssertEqual(stats.filesDeleted, 100)
        
        // Should complete within reasonable time (adjust threshold as needed)
        XCTAssertLessThan(duration, 10.0, "Cleanup took too long: \(duration) seconds")
    }
}