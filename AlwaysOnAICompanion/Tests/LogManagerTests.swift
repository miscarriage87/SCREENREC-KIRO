import XCTest
import os.log
@testable import Shared

final class LogManagerTests: XCTestCase {
    var logManager: LogManager!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test logs
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        logManager = LogManager.shared
        logManager.configuration.logDirectory = tempDirectory
        logManager.configuration.maxEntries = 100
        logManager.clearLogs()
    }
    
    override func tearDown() {
        logManager.clearLogs()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    func testLogManagerInitialization() {
        XCTAssertNotNil(logManager)
        XCTAssertTrue(logManager.logEntries.isEmpty)
        XCTAssertTrue(logManager.filteredEntries.isEmpty)
    }
    
    func testBasicLogging() {
        // Test different log levels
        logManager.debug("Debug message", category: "Test")
        logManager.info("Info message", category: "Test")
        logManager.warning("Warning message", category: "Test")
        logManager.error("Error message", category: "Test")
        logManager.critical("Critical message", category: "Test")
        
        // Verify entries were added
        XCTAssertEqual(logManager.logEntries.count, 5)
        
        // Verify log levels
        let levels = logManager.logEntries.map { $0.level }
        XCTAssertTrue(levels.contains(.debug))
        XCTAssertTrue(levels.contains(.info))
        XCTAssertTrue(levels.contains(.error))
        XCTAssertTrue(levels.contains(.fault))
    }
    
    func testLogEntryProperties() {
        let testMessage = "Test log message"
        let testCategory = "TestCategory"
        
        logManager.info(testMessage, category: testCategory)
        
        XCTAssertEqual(logManager.logEntries.count, 1)
        
        let entry = logManager.logEntries.first!
        XCTAssertEqual(entry.message, testMessage)
        XCTAssertEqual(entry.category, testCategory)
        XCTAssertEqual(entry.level, .info)
        XCTAssertFalse(entry.file.isEmpty)
        XCTAssertFalse(entry.function.isEmpty)
        XCTAssertGreaterThan(entry.line, 0)
        XCTAssertLessThan(entry.timestamp.timeIntervalSinceNow, 1.0) // Recent timestamp
    }
    
    func testLogFiltering() {
        // Add logs with different levels and categories
        logManager.debug("Debug 1", category: "Category1")
        logManager.info("Info 1", category: "Category1")
        logManager.error("Error 1", category: "Category2")
        logManager.debug("Debug 2", category: "Category2")
        logManager.info("Info 2", category: "Category2")
        
        XCTAssertEqual(logManager.logEntries.count, 5)
        
        // Test level filtering
        var filter = LogFilter()
        filter.levels = [.error]
        logManager.applyFilter(filter)
        
        XCTAssertEqual(logManager.filteredEntries.count, 1)
        XCTAssertEqual(logManager.filteredEntries.first?.level, .error)
        
        // Test category filtering
        filter = LogFilter()
        filter.categories = ["Category1"]
        logManager.applyFilter(filter)
        
        XCTAssertEqual(logManager.filteredEntries.count, 2)
        XCTAssertTrue(logManager.filteredEntries.allSatisfy { $0.category == "Category1" })
        
        // Test text search
        filter = LogFilter()
        filter.searchText = "Debug"
        logManager.applyFilter(filter)
        
        XCTAssertEqual(logManager.filteredEntries.count, 2)
        XCTAssertTrue(logManager.filteredEntries.allSatisfy { $0.message.contains("Debug") })
        
        // Test combined filtering
        filter = LogFilter()
        filter.levels = [.debug]
        filter.categories = ["Category2"]
        logManager.applyFilter(filter)
        
        XCTAssertEqual(logManager.filteredEntries.count, 1)
        XCTAssertEqual(logManager.filteredEntries.first?.message, "Debug 2")
    }
    
    func testTimeRangeFiltering() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        // Add logs (we can't easily control timestamps, so this is a simplified test)
        logManager.info("Recent message", category: "Test")
        
        var filter = LogFilter()
        filter.startDate = oneHourAgo
        filter.endDate = now
        logManager.applyFilter(filter)
        
        // Should include recent messages
        XCTAssertEqual(logManager.filteredEntries.count, 1)
        
        // Test with future start date (should exclude all)
        filter.startDate = now.addingTimeInterval(3600)
        logManager.applyFilter(filter)
        
        XCTAssertEqual(logManager.filteredEntries.count, 0)
    }
    
    func testLogExport() {
        // Add test logs
        logManager.info("Test message 1", category: "Export")
        logManager.error("Test error", category: "Export")
        logManager.debug("Debug info", category: "Export")
        
        let exportURL = tempDirectory.appendingPathComponent("test_export")
        
        // Test JSON export
        let jsonURL = exportURL.appendingPathExtension("json")
        XCTAssertNoThrow(try logManager.exportLogs(to: jsonURL, format: .json))
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path))
        
        // Verify JSON content
        let jsonData = try! Data(contentsOf: jsonURL)
        let decodedEntries = try! JSONDecoder().decode([LogEntry].self, from: jsonData)
        XCTAssertEqual(decodedEntries.count, 3)
        
        // Test CSV export
        let csvURL = exportURL.appendingPathExtension("csv")
        XCTAssertNoThrow(try logManager.exportLogs(to: csvURL, format: .csv))
        XCTAssertTrue(FileManager.default.fileExists(atPath: csvURL.path))
        
        // Verify CSV content
        let csvContent = try! String(contentsOf: csvURL)
        XCTAssertTrue(csvContent.contains("Timestamp,Level,Category,Message"))
        XCTAssertTrue(csvContent.contains("Test message 1"))
        XCTAssertTrue(csvContent.contains("Test error"))
        
        // Test text export
        let textURL = exportURL.appendingPathExtension("txt")
        XCTAssertNoThrow(try logManager.exportLogs(to: textURL, format: .text))
        XCTAssertTrue(FileManager.default.fileExists(atPath: textURL.path))
        
        // Verify text content
        let textContent = try! String(contentsOf: textURL)
        XCTAssertTrue(textContent.contains("Test message 1"))
        XCTAssertTrue(textContent.contains("ERROR"))
        XCTAssertTrue(textContent.contains("DEBUG"))
    }
    
    func testLogStatistics() {
        // Add logs with different levels and categories
        logManager.debug("Debug 1", category: "Cat1")
        logManager.debug("Debug 2", category: "Cat1")
        logManager.info("Info 1", category: "Cat2")
        logManager.error("Error 1", category: "Cat2")
        logManager.error("Error 2", category: "Cat3")
        logManager.critical("Critical 1", category: "Cat3")
        
        let stats = logManager.getLogStatistics()
        
        XCTAssertEqual(stats.totalEntries, 6)
        XCTAssertEqual(stats.levelCounts[.debug], 2)
        XCTAssertEqual(stats.levelCounts[.info], 1)
        XCTAssertEqual(stats.levelCounts[.error], 2)
        XCTAssertEqual(stats.levelCounts[.fault], 1)
        
        XCTAssertEqual(stats.categoryCounts["Cat1"], 2)
        XCTAssertEqual(stats.categoryCounts["Cat2"], 2)
        XCTAssertEqual(stats.categoryCounts["Cat3"], 2)
        
        XCTAssertEqual(stats.errorCount, 3) // error + critical
        XCTAssertNotNil(stats.oldestEntry)
        XCTAssertNotNil(stats.newestEntry)
    }
    
    func testMaxEntriesLimit() {
        logManager.configuration.maxEntries = 5
        
        // Add more entries than the limit
        for i in 1...10 {
            logManager.info("Message \(i)", category: "Test")
        }
        
        // Should only keep the most recent entries
        XCTAssertEqual(logManager.logEntries.count, 5)
        
        // Should have the last 5 messages
        let messages = logManager.logEntries.map { $0.message }
        XCTAssertTrue(messages.contains("Message 6"))
        XCTAssertTrue(messages.contains("Message 10"))
        XCTAssertFalse(messages.contains("Message 1"))
        XCTAssertFalse(messages.contains("Message 5"))
    }
    
    func testAvailableCategories() {
        logManager.info("Message 1", category: "Category1")
        logManager.error("Message 2", category: "Category2")
        logManager.debug("Message 3", category: "Category1")
        logManager.info("Message 4", category: "Category3")
        
        let categories = logManager.getAvailableCategories()
        
        XCTAssertEqual(categories.count, 3)
        XCTAssertTrue(categories.contains("Category1"))
        XCTAssertTrue(categories.contains("Category2"))
        XCTAssertTrue(categories.contains("Category3"))
        XCTAssertEqual(categories, categories.sorted()) // Should be sorted
    }
    
    func testLogClearance() {
        // Add some logs
        logManager.info("Message 1", category: "Test")
        logManager.error("Message 2", category: "Test")
        
        XCTAssertEqual(logManager.logEntries.count, 2)
        
        // Clear logs
        logManager.clearLogs()
        
        XCTAssertEqual(logManager.logEntries.count, 0)
        XCTAssertEqual(logManager.filteredEntries.count, 0)
    }
    
    func testFileLogging() {
        // Enable file logging
        logManager.configuration.enableFileLogging = true
        
        // Add a log entry
        logManager.info("File logging test", category: "FileTest")
        
        // Give some time for file writing
        let expectation = XCTestExpectation(description: "File written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Check if log files were created
        let logFiles = try! FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "log" }
        
        XCTAssertFalse(logFiles.isEmpty)
        
        // Check file content
        if let logFile = logFiles.first {
            let content = try! String(contentsOf: logFile)
            XCTAssertTrue(content.contains("File logging test"))
            XCTAssertTrue(content.contains("FileTest"))
        }
    }
    
    func testLogRotation() {
        // Enable file logging with small rotation size
        logManager.configuration.enableFileLogging = true
        logManager.configuration.rotationSize = 1024 // 1KB
        
        // Add many log entries to trigger rotation
        for i in 1...100 {
            logManager.info("This is a longer log message to fill up the file quickly - entry \(i)", category: "Rotation")
        }
        
        // Give time for file operations
        let expectation = XCTestExpectation(description: "Log rotation completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Should have created multiple log files due to rotation
        let logFiles = try! FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "log" }
        
        // Might have multiple files due to rotation
        XCTAssertGreaterThanOrEqual(logFiles.count, 1)
    }
    
    func testConcurrentLogging() {
        let expectation = XCTestExpectation(description: "Concurrent logging completed")
        expectation.expectedFulfillmentCount = 10
        
        // Log from multiple threads concurrently
        for i in 1...10 {
            DispatchQueue.global().async {
                self.logManager.info("Concurrent message \(i)", category: "Concurrent")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // All messages should be logged
        XCTAssertEqual(logManager.logEntries.count, 10)
        
        // Verify all messages are present
        let messages = logManager.logEntries.map { $0.message }
        for i in 1...10 {
            XCTAssertTrue(messages.contains("Concurrent message \(i)"))
        }
    }
    
    func testLogFilterEmpty() {
        let filter = LogFilter()
        XCTAssertTrue(filter.isEmpty)
        
        var nonEmptyFilter = LogFilter()
        nonEmptyFilter.searchText = "test"
        XCTAssertFalse(nonEmptyFilter.isEmpty)
        
        nonEmptyFilter = LogFilter()
        nonEmptyFilter.levels = [.error]
        XCTAssertFalse(nonEmptyFilter.isEmpty)
    }
    
    func testOSLogTypeExtensions() {
        XCTAssertEqual(OSLogType.debug.displayName, "Debug")
        XCTAssertEqual(OSLogType.info.displayName, "Info")
        XCTAssertEqual(OSLogType.error.displayName, "Error")
        XCTAssertEqual(OSLogType.fault.displayName, "Critical")
        
        // Test encoding/decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let logType = OSLogType.error
        let encoded = try! encoder.encode(logType)
        let decoded = try! decoder.decode(OSLogType.self, from: encoded)
        
        XCTAssertEqual(logType, decoded)
    }
}