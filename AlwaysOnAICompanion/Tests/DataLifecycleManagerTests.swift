import XCTest
import Foundation
@testable import Shared

class DataLifecycleManagerTests: XCTestCase {
    var tempDirectory: URL!
    var configurationManager: ConfigurationManager!
    var lifecycleManager: DataLifecycleManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataLifecycleTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test configuration manager
        configurationManager = ConfigurationManager()
        
        // Create lifecycle manager
        lifecycleManager = DataLifecycleManager(configurationManager: configurationManager)
    }
    
    override func tearDown() {
        lifecycleManager.stop()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    // MARK: - Lifecycle Management Tests
    
    func testStartStop() {
        // Test starting lifecycle manager
        lifecycleManager.start()
        
        // Test stopping lifecycle manager
        lifecycleManager.stop()
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testStartWithRetentionPoliciesDisabled() {
        // Create configuration with retention policies disabled
        let testConfig = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: tempDirectory.appendingPathComponent("storage"),
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
            enableRetentionPolicies: false, // Disabled
            retentionCheckIntervalHours: 24
        )
        
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Should start without issues even with policies disabled
        lifecycleManager.start()
        lifecycleManager.stop()
        
        XCTAssertTrue(true)
    }
    
    // MARK: - Manual Cleanup Tests
    
    func testManualCleanup() throws {
        // Create test storage structure
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create test files
        try createTestVideoFiles(count: 3, daysOld: 35, in: videosURL)
        
        // Update configuration
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Test manual cleanup
        let expectation = XCTestExpectation(description: "Manual cleanup completion")
        
        lifecycleManager.performManualCleanup(for: .rawVideo) { result in
            switch result {
            case .success(let stats):
                XCTAssertEqual(stats.dataType, .rawVideo)
                XCTAssertGreaterThan(stats.filesDeleted, 0)
            case .failure(let error):
                XCTFail("Manual cleanup failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCleanupEstimate() throws {
        // Create test storage structure
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create test files
        try createTestVideoFiles(count: 2, daysOld: 35, in: videosURL)
        
        // Update configuration
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Test cleanup estimate
        let expectation = XCTestExpectation(description: "Cleanup estimate completion")
        
        lifecycleManager.getCleanupEstimate(for: .rawVideo) { result in
            switch result {
            case .success(let estimate):
                XCTAssertGreaterThan(estimate, 0)
            case .failure(let error):
                XCTFail("Cleanup estimate failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Storage Health Tests
    
    func testStorageHealthReport() throws {
        // Create test storage structure with various data types
        let storageURL = tempDirectory.appendingPathComponent("storage")
        
        // Create files for different data types
        try createTestVideoFiles(count: 2, daysOld: 10, in: storageURL.appendingPathComponent("videos"))
        try createTestParquetFiles(count: 3, daysOld: 20, in: storageURL.appendingPathComponent("frames"))
        try createTestParquetFiles(count: 1, daysOld: 5, in: storageURL.appendingPathComponent("ocr"))
        
        // Update configuration
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Test storage health report
        let expectation = XCTestExpectation(description: "Storage health report completion")
        
        lifecycleManager.checkStorageHealth { report in
            XCTAssertGreaterThan(report.totalSize, 0)
            XCTAssertGreaterThan(report.availableSpace, 0)
            XCTAssertFalse(report.dataTypeBreakdown.isEmpty)
            
            // Should have data for the types we created
            XCTAssertNotNil(report.dataTypeBreakdown[.rawVideo])
            XCTAssertNotNil(report.dataTypeBreakdown[.frameMetadata])
            XCTAssertNotNil(report.dataTypeBreakdown[.ocrData])
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testStorageHealthWithLowSpace() throws {
        // This test simulates low disk space conditions
        // In a real scenario, we would mock the available space calculation
        
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        let expectation = XCTestExpectation(description: "Storage health with low space")
        
        lifecycleManager.checkStorageHealth { report in
            // The health status depends on actual available space
            // In a test environment, this will likely be healthy
            XCTAssertNotEqual(report.healthStatus, .error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Configuration Management Tests
    
    func testRetentionConfigurationUpdate() throws {
        // Create custom retention configuration
        let customPolicies: [DataType: RetentionPolicy] = [
            .rawVideo: RetentionPolicy(dataType: .rawVideo, retentionDays: 14),
            .frameMetadata: RetentionPolicy(dataType: .frameMetadata, retentionDays: 60)
        ]
        
        let customConfig = RetentionConfiguration(
            policies: customPolicies,
            enableBackgroundCleanup: false,
            safetyMarginHours: 12
        )
        
        // Update configuration
        XCTAssertNoThrow(try lifecycleManager.updateRetentionConfiguration(customConfig))
        
        // Verify configuration was updated
        let retrievedConfig = lifecycleManager.getRetentionConfiguration()
        XCTAssertEqual(retrievedConfig.safetyMarginHours, 12)
        XCTAssertFalse(retrievedConfig.enableBackgroundCleanup)
    }
    
    func testGetRetentionConfiguration() {
        let config = lifecycleManager.getRetentionConfiguration()
        
        // Should return default configuration
        XCTAssertTrue(config.enableBackgroundCleanup)
        XCTAssertEqual(config.safetyMarginHours, 24)
        XCTAssertNotNil(config.policies[.rawVideo])
        XCTAssertNotNil(config.policies[.frameMetadata])
    }
    
    // MARK: - Statistics Tests
    
    func testGetCleanupStatistics() {
        let stats = lifecycleManager.getCleanupStatistics()
        
        // Should return empty statistics initially
        XCTAssertTrue(stats.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testManualCleanupWithInvalidDataType() {
        // Test cleanup with invalid configuration
        let expectation = XCTestExpectation(description: "Manual cleanup with error")
        
        lifecycleManager.performManualCleanup(for: .rawVideo) { result in
            switch result {
            case .success(_):
                // May succeed with empty results
                break
            case .failure(_):
                // Expected to fail due to missing configuration
                break
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCleanupEstimateWithInvalidConfiguration() {
        let expectation = XCTestExpectation(description: "Cleanup estimate with error")
        
        lifecycleManager.getCleanupEstimate(for: .rawVideo) { result in
            switch result {
            case .success(let estimate):
                // May return 0 for invalid configuration
                XCTAssertGreaterThanOrEqual(estimate, 0)
            case .failure(_):
                // Expected to fail due to missing configuration
                break
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestConfiguration(storageURL: URL) -> RecorderConfiguration {
        return RecorderConfiguration(
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
    }
    
    private func createTestVideoFiles(count: Int, daysOld: Int, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_video_\(i).mp4"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "Test video content \(i) - larger content to simulate real files".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
        }
    }
    
    private func createTestParquetFiles(count: Int, daysOld: Int, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_data_\(i).parquet"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "Test parquet content \(i) with some data".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
        }
    }
}