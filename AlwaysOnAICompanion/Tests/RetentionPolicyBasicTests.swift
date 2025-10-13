import XCTest
import Foundation
@testable import Shared

class RetentionPolicyBasicTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetentionBasicTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    // MARK: - Basic Configuration Tests
    
    func testRetentionPolicyConfiguration() {
        // Test creating retention policy
        let videoPolicy = RetentionPolicy(dataType: .rawVideo, retentionDays: 30)
        
        XCTAssertEqual(videoPolicy.dataType, .rawVideo)
        XCTAssertEqual(videoPolicy.retentionDays, 30)
        XCTAssertTrue(videoPolicy.enabled)
        XCTAssertEqual(videoPolicy.cleanupIntervalHours, 24)
    }
    
    func testRetentionConfiguration() {
        // Test creating retention configuration
        let config = RetentionConfiguration()
        
        XCTAssertTrue(config.enableBackgroundCleanup)
        XCTAssertEqual(config.safetyMarginHours, 24)
        XCTAssertEqual(config.maxFilesPerCleanupBatch, 100)
        XCTAssertTrue(config.verificationEnabled)
        
        // Check default policies exist
        XCTAssertNotNil(config.policies[.rawVideo])
        XCTAssertNotNil(config.policies[.frameMetadata])
        XCTAssertNotNil(config.policies[.ocrData])
        XCTAssertNotNil(config.policies[.events])
        XCTAssertNotNil(config.policies[.spans])
        XCTAssertNotNil(config.policies[.summaries])
    }
    
    func testDataTypeEnumeration() {
        // Test all data types are available
        let allTypes = DataType.allCases
        
        XCTAssertTrue(allTypes.contains(.rawVideo))
        XCTAssertTrue(allTypes.contains(.frameMetadata))
        XCTAssertTrue(allTypes.contains(.ocrData))
        XCTAssertTrue(allTypes.contains(.events))
        XCTAssertTrue(allTypes.contains(.spans))
        XCTAssertTrue(allTypes.contains(.summaries))
    }
    
    // MARK: - Error Handling Tests
    
    func testRetentionPolicyErrors() {
        // Test error cases
        let configNotFoundError = RetentionPolicyError.configurationNotFound
        XCTAssertNotNil(configNotFoundError.errorDescription)
        
        let invalidDaysError = RetentionPolicyError.invalidRetentionDays(-5)
        XCTAssertNotNil(invalidDaysError.errorDescription)
        
        let cleanupFailedError = RetentionPolicyError.cleanupFailed("Test error")
        XCTAssertNotNil(cleanupFailedError.errorDescription)
    }
    
    // MARK: - CleanupStats Tests
    
    func testCleanupStats() {
        // Test creating cleanup statistics
        let stats = CleanupStats(
            dataType: .rawVideo,
            filesScanned: 10,
            filesDeleted: 5,
            bytesFreed: 1024,
            duration: 2.5,
            errors: ["Test error"]
        )
        
        XCTAssertEqual(stats.dataType, .rawVideo)
        XCTAssertEqual(stats.filesScanned, 10)
        XCTAssertEqual(stats.filesDeleted, 5)
        XCTAssertEqual(stats.bytesFreed, 1024)
        XCTAssertEqual(stats.duration, 2.5)
        XCTAssertEqual(stats.errors.count, 1)
        XCTAssertEqual(stats.errors.first, "Test error")
    }
    
    // MARK: - Storage Health Tests
    
    func testStorageHealthReport() {
        // Test creating storage health report
        let breakdown: [DataType: Int64] = [
            .rawVideo: 1000,
            .frameMetadata: 500,
            .ocrData: 200
        ]
        
        let report = StorageHealthReport(
            totalSize: 1700,
            availableSpace: 5000,
            dataTypeBreakdown: breakdown,
            recommendations: ["Test recommendation"],
            healthStatus: .healthy
        )
        
        XCTAssertEqual(report.totalSize, 1700)
        XCTAssertEqual(report.availableSpace, 5000)
        XCTAssertEqual(report.dataTypeBreakdown.count, 3)
        XCTAssertEqual(report.dataTypeBreakdown[.rawVideo], 1000)
        XCTAssertEqual(report.recommendations.count, 1)
        XCTAssertEqual(report.healthStatus, .healthy)
    }
    
    func testStorageHealthStatus() {
        // Test all health status cases
        XCTAssertNotNil(StorageHealthStatus.healthy)
        XCTAssertNotNil(StorageHealthStatus.warning)
        XCTAssertNotNil(StorageHealthStatus.critical)
        XCTAssertNotNil(StorageHealthStatus.error)
    }
    
    // MARK: - File Creation Helper Tests
    
    func testFileCreationHelpers() throws {
        // Test creating test files
        let testDir = tempDirectory.appendingPathComponent("test_files")
        
        // Create test video files
        let videoFiles = try createTestVideoFiles(count: 3, daysOld: 10, in: testDir)
        
        XCTAssertEqual(videoFiles.count, 3)
        
        for fileURL in videoFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
            XCTAssertTrue(fileURL.pathExtension == "mp4")
        }
    }
    
    // MARK: - Helper Methods
    
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
}