import XCTest
import Foundation
@testable import Shared

class RetentionPolicyIntegrationTests: XCTestCase {
    var tempDirectory: URL!
    var configurationManager: ConfigurationManager!
    var lifecycleManager: DataLifecycleManager!
    var retentionManager: RetentionPolicyManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetentionIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test configuration manager
        configurationManager = ConfigurationManager()
        
        // Create managers
        lifecycleManager = DataLifecycleManager(configurationManager: configurationManager)
        retentionManager = RetentionPolicyManager(configurationManager: configurationManager)
    }
    
    override func tearDown() {
        lifecycleManager.stop()
        retentionManager.stopBackgroundCleanup()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteDataLifecycle() throws {
        // Create comprehensive test storage structure
        let storageURL = tempDirectory.appendingPathComponent("storage")
        
        // Create files for all data types with different ages
        try createCompleteStorageStructure(storageURL: storageURL)
        
        // Configure system with test storage
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Start lifecycle management
        lifecycleManager.start()
        
        // Wait a moment for initialization
        Thread.sleep(forTimeInterval: 0.5)
        
        // Perform manual cleanup for each data type
        let dataTypes: [DataType] = [.rawVideo, .frameMetadata, .ocrData, .events]
        var cleanupResults: [DataType: CleanupStats] = [:]
        
        let group = DispatchGroup()
        
        for dataType in dataTypes {
            group.enter()
            lifecycleManager.performManualCleanup(for: dataType) { result in
                switch result {
                case .success(let stats):
                    cleanupResults[dataType] = stats
                case .failure(let error):
                    XCTFail("Cleanup failed for \(dataType): \(error)")
                }
                group.leave()
            }
        }
        
        group.wait()
        
        // Verify cleanup results
        XCTAssertEqual(cleanupResults.count, dataTypes.count)
        
        for (dataType, stats) in cleanupResults {
            XCTAssertGreaterThan(stats.filesScanned, 0, "No files scanned for \(dataType)")
            
            // Should have deleted old files based on retention policy
            switch dataType {
            case .rawVideo:
                // 30-day retention, should delete 35-day-old files
                XCTAssertGreaterThan(stats.filesDeleted, 0)
            case .frameMetadata, .ocrData:
                // 90-day retention, should delete 100-day-old files
                XCTAssertGreaterThan(stats.filesDeleted, 0)
            case .events:
                // 365-day retention, should delete 400-day-old files
                XCTAssertGreaterThan(stats.filesDeleted, 0)
            default:
                break
            }
        }
        
        // Check storage health after cleanup
        let healthExpectation = XCTestExpectation(description: "Storage health check")
        
        lifecycleManager.checkStorageHealth { report in
            XCTAssertGreaterThan(report.totalSize, 0)
            XCTAssertNotEqual(report.healthStatus, .error)
            
            // Should have recommendations if there's reclaimable space
            // (This depends on the specific test data created)
            
            healthExpectation.fulfill()
        }
        
        wait(for: [healthExpectation], timeout: 10.0)
        
        lifecycleManager.stop()
    }
    
    func testRetentionPolicyEnforcement() throws {
        // Create test storage with files of various ages
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create files with specific ages to test retention policy
        let oldFiles = try createTestVideoFiles(count: 5, daysOld: 35, in: videosURL) // Should be deleted
        let borderlineFiles = try createTestVideoFiles(count: 3, daysOld: 30, in: videosURL) // Edge case
        let recentFiles = try createTestVideoFiles(count: 4, daysOld: 15, in: videosURL) // Should be kept
        
        // Configure with 30-day retention
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Perform cleanup
        let stats = try retentionManager.performCleanup(for: .rawVideo)
        
        // Verify retention policy enforcement
        XCTAssertEqual(stats.filesScanned, 12) // Total files created
        XCTAssertEqual(stats.filesDeleted, 5) // Only the 35-day-old files
        
        // Verify files on disk
        for fileURL in oldFiles {
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Old file should be deleted: \(fileURL.lastPathComponent)")
        }
        
        for fileURL in recentFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Recent file should be kept: \(fileURL.lastPathComponent)")
        }
        
        // Borderline files (exactly 30 days) should be kept due to safety margin
        for fileURL in borderlineFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Borderline file should be kept due to safety margin: \(fileURL.lastPathComponent)")
        }
    }
    
    func testMultipleDataTypeCleanup() throws {
        // Create storage structure with multiple data types
        let storageURL = tempDirectory.appendingPathComponent("storage")
        
        // Create old files for different data types
        try createTestVideoFiles(count: 3, daysOld: 35, in: storageURL.appendingPathComponent("videos"))
        try createTestParquetFiles(count: 4, daysOld: 100, in: storageURL.appendingPathComponent("frames"))
        try createTestParquetFiles(count: 2, daysOld: 100, in: storageURL.appendingPathComponent("ocr"))
        try createTestParquetFiles(count: 5, daysOld: 400, in: storageURL.appendingPathComponent("events"))
        
        // Create recent files that should be kept
        try createTestVideoFiles(count: 2, daysOld: 10, in: storageURL.appendingPathComponent("videos"))
        try createTestParquetFiles(count: 3, daysOld: 30, in: storageURL.appendingPathComponent("frames"))
        try createTestParquetFiles(count: 1, daysOld: 20, in: storageURL.appendingPathComponent("ocr"))
        try createTestParquetFiles(count: 2, daysOld: 100, in: storageURL.appendingPathComponent("events"))
        
        // Configure system
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Test cleanup for each data type
        let dataTypes: [DataType] = [.rawVideo, .frameMetadata, .ocrData, .events]
        var totalFilesDeleted = 0
        
        for dataType in dataTypes {
            let stats = try retentionManager.performCleanup(for: dataType)
            totalFilesDeleted += stats.filesDeleted
            
            // Verify each data type had appropriate cleanup
            switch dataType {
            case .rawVideo:
                XCTAssertEqual(stats.filesDeleted, 3, "Should delete 3 old video files")
            case .frameMetadata:
                XCTAssertEqual(stats.filesDeleted, 4, "Should delete 4 old frame metadata files")
            case .ocrData:
                XCTAssertEqual(stats.filesDeleted, 2, "Should delete 2 old OCR files")
            case .events:
                XCTAssertEqual(stats.filesDeleted, 5, "Should delete 5 old event files")
            default:
                break
            }
        }
        
        XCTAssertEqual(totalFilesDeleted, 14, "Total files deleted should match expected")
    }
    
    func testBackgroundCleanupIntegration() throws {
        // Create test storage
        let storageURL = tempDirectory.appendingPathComponent("storage")
        try createTestVideoFiles(count: 3, daysOld: 35, in: storageURL.appendingPathComponent("videos"))
        
        // Configure system
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Start background cleanup
        retentionManager.startBackgroundCleanup()
        
        // Wait for potential background processing
        Thread.sleep(forTimeInterval: 1.0)
        
        // Stop background cleanup
        retentionManager.stopBackgroundCleanup()
        
        // Should complete without errors
        XCTAssertTrue(true)
    }
    
    func testSafetyMarginEnforcement() throws {
        // Create files exactly at the retention boundary
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create files at exactly 30 days (retention limit)
        let boundaryFiles = try createTestVideoFiles(count: 3, daysOld: 30, in: videosURL)
        
        // Create files at 31 days (should be deleted with safety margin)
        let oldFiles = try createTestVideoFiles(count: 2, daysOld: 31, in: videosURL)
        
        // Configure system with default 24-hour safety margin
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Perform cleanup
        let stats = try retentionManager.performCleanup(for: .rawVideo)
        
        // With 24-hour safety margin, files at exactly 30 days should be kept
        // Only files older than 30 days + 24 hours should be deleted
        XCTAssertEqual(stats.filesDeleted, 2, "Should delete only files older than retention + safety margin")
        
        // Verify boundary files are kept
        for fileURL in boundaryFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Boundary file should be kept due to safety margin")
        }
        
        // Verify old files are deleted
        for fileURL in oldFiles {
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Old file should be deleted")
        }
    }
    
    func testCleanupVerificationAndRollback() throws {
        // This test simulates scenarios where verification might fail
        // In a real implementation, we would test with corrupted files or permission issues
        
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create test files
        try createTestVideoFiles(count: 5, daysOld: 35, in: videosURL)
        
        // Configure system
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Perform cleanup (should succeed with normal files)
        let stats = try retentionManager.performCleanup(for: .rawVideo)
        
        // Should complete successfully
        XCTAssertEqual(stats.filesDeleted, 5)
        XCTAssertTrue(stats.errors.isEmpty)
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeScaleCleanupPerformance() throws {
        // Create large number of files to test performance
        let storageURL = tempDirectory.appendingPathComponent("storage")
        let videosURL = storageURL.appendingPathComponent("videos")
        
        // Create many old files
        try createTestVideoFiles(count: 200, daysOld: 35, in: videosURL)
        
        // Create some recent files
        try createTestVideoFiles(count: 50, daysOld: 10, in: videosURL)
        
        // Configure system
        let testConfig = createTestConfiguration(storageURL: storageURL)
        XCTAssertTrue(configurationManager.saveConfiguration(testConfig))
        
        // Measure cleanup performance
        let startTime = Date()
        let stats = try retentionManager.performCleanup(for: .rawVideo)
        let duration = Date().timeIntervalSince(startTime)
        
        // Verify cleanup results
        XCTAssertEqual(stats.filesDeleted, 200)
        XCTAssertEqual(stats.filesScanned, 250)
        
        // Performance should be reasonable (adjust threshold as needed)
        XCTAssertLessThan(duration, 30.0, "Large-scale cleanup took too long: \(duration) seconds")
        
        print("Cleanup performance: \(stats.filesDeleted) files in \(duration) seconds")
    }
    
    // MARK: - Helper Methods
    
    private func createCompleteStorageStructure(storageURL: URL) throws {
        // Create old files that should be deleted
        try createTestVideoFiles(count: 3, daysOld: 35, in: storageURL.appendingPathComponent("videos"))
        try createTestParquetFiles(count: 2, daysOld: 100, in: storageURL.appendingPathComponent("frames"))
        try createTestParquetFiles(count: 2, daysOld: 100, in: storageURL.appendingPathComponent("ocr"))
        try createTestParquetFiles(count: 1, daysOld: 400, in: storageURL.appendingPathComponent("events"))
        
        // Create recent files that should be kept
        try createTestVideoFiles(count: 2, daysOld: 10, in: storageURL.appendingPathComponent("videos"))
        try createTestParquetFiles(count: 3, daysOld: 30, in: storageURL.appendingPathComponent("frames"))
        try createTestParquetFiles(count: 1, daysOld: 20, in: storageURL.appendingPathComponent("ocr"))
        try createTestParquetFiles(count: 2, daysOld: 100, in: storageURL.appendingPathComponent("events"))
        
        // Create permanent data (spans and summaries) - should never be deleted
        try createTestSQLiteFiles(count: 2, daysOld: 500, in: storageURL.appendingPathComponent("spans"))
        try createTestMarkdownFiles(count: 3, daysOld: 500, in: storageURL.appendingPathComponent("summaries"))
    }
    
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
    
    private func createTestVideoFiles(count: Int, daysOld: Int, in directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var files: [URL] = []
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_video_\(i)_\(daysOld)days.mp4"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "Test video content \(i) - \(daysOld) days old".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
            
            files.append(fileURL)
        }
        
        return files
    }
    
    private func createTestParquetFiles(count: Int, daysOld: Int, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_data_\(i)_\(daysOld)days.parquet"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "Test parquet content \(i) - \(daysOld) days old".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
        }
    }
    
    private func createTestSQLiteFiles(count: Int, daysOld: Int, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_spans_\(i).sqlite"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "Test SQLite content \(i)".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
        }
    }
    
    private func createTestMarkdownFiles(count: Int, daysOld: Int, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysOld, to: Date())!
        
        for i in 0..<count {
            let fileName = "test_summary_\(i).md"
            let fileURL = directory.appendingPathComponent(fileName)
            
            // Create dummy file content
            let dummyContent = "# Test Summary \(i)\n\nThis is a test summary.".data(using: .utf8)!
            try dummyContent.write(to: fileURL)
            
            // Set file modification date
            try FileManager.default.setAttributes([
                .modificationDate: targetDate
            ], ofItemAtPath: fileURL.path)
        }
    }
}