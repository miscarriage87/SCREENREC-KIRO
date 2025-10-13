import XCTest
import SQLite3
@testable import Shared

/// Integration tests that verify encryption works end-to-end with the storage systems
class EncryptionIntegrationTests: XCTestCase {
    
    var secureStorage: SecureStorage!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        secureStorage = SecureStorage()
        tempDirectory = createTempDirectory()
    }
    
    override func tearDown() {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        secureStorage = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - End-to-End Encryption Tests
    
    func testCompleteDataLifecycle() throws {
        // Simulate the complete data lifecycle with encryption
        
        // 1. Create mock OCR data
        let ocrData = createMockOCRData()
        let ocrDataJSON = try JSONSerialization.data(withJSONObject: ocrData)
        
        // 2. Store encrypted OCR data
        let ocrFile = tempDirectory.appendingPathComponent("ocr_data.json")
        try secureStorage.writeEncryptedData(ocrDataJSON, to: ocrFile)
        
        // 3. Create mock frame metadata
        let frameMetadata = createMockFrameMetadata()
        let frameDataJSON = try JSONSerialization.data(withJSONObject: frameMetadata)
        
        // 4. Store encrypted frame metadata
        let frameFile = tempDirectory.appendingPathComponent("frame_metadata.json")
        try secureStorage.writeEncryptedData(frameDataJSON, to: frameFile)
        
        // 5. Create encrypted SQLite database for spans
        let spansDB = tempDirectory.appendingPathComponent("spans.db")
        try createEncryptedSpansDatabase(at: spansDB)
        
        // 6. Verify all files are encrypted (different from original)
        let encryptedOCR = try Data(contentsOf: ocrFile)
        let encryptedFrame = try Data(contentsOf: frameFile)
        let encryptedDB = try Data(contentsOf: spansDB)
        
        XCTAssertNotEqual(ocrDataJSON, encryptedOCR)
        XCTAssertNotEqual(frameDataJSON, encryptedFrame)
        
        // 7. Read and verify data can be decrypted correctly
        let decryptedOCR = try secureStorage.readEncryptedData(from: ocrFile)
        let decryptedFrame = try secureStorage.readEncryptedData(from: frameFile)
        
        XCTAssertEqual(ocrDataJSON, decryptedOCR)
        XCTAssertEqual(frameDataJSON, decryptedFrame)
        
        // 8. Verify database can be decrypted and queried
        try secureStorage.decryptSQLiteDatabase(at: spansDB)
        let db = try secureStorage.createEncryptedSQLiteConnection(at: spansDB)
        
        var statement: OpaquePointer?
        let query = "SELECT COUNT(*) FROM spans"
        
        XCTAssertEqual(sqlite3_prepare_v2(db, query, -1, &statement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        
        let count = sqlite3_column_int(statement, 0)
        XCTAssertGreaterThan(count, 0)
        
        sqlite3_finalize(statement)
        sqlite3_close(db)
        
        print("✓ Complete data lifecycle with encryption works")
    }
    
    func testBulkDataEncryption() throws {
        // Test encrypting a large number of files efficiently
        
        let fileCount = 50
        var createdFiles: [URL] = []
        
        // Create multiple data files
        for i in 0..<fileCount {
            let fileName = "data_file_\(i).json"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            let testData: [String: Any] = ["id": i, "content": "Test data for file \(i)"]
            let jsonData = try JSONSerialization.data(withJSONObject: testData)
            
            try secureStorage.writeEncryptedData(jsonData, to: fileURL)
            createdFiles.append(fileURL)
        }
        
        // Verify all files are encrypted
        for (index, fileURL) in createdFiles.enumerated() {
            let encryptedContent = try Data(contentsOf: fileURL)
            let originalData: [String: Any] = ["id": index, "content": "Test data for file \(index)"]
            let originalJSON = try JSONSerialization.data(withJSONObject: originalData)
            
            XCTAssertNotEqual(originalJSON, encryptedContent)
            
            // Verify can be decrypted
            let decryptedContent = try secureStorage.readEncryptedData(from: fileURL)
            XCTAssertEqual(originalJSON, decryptedContent)
        }
        
        print("✓ Bulk data encryption works for \(fileCount) files")
    }
    
    func testKeyRotationWithActiveData() throws {
        // Test key rotation with existing encrypted data
        
        // Create initial encrypted files
        let file1 = tempDirectory.appendingPathComponent("file1.txt")
        let file2 = tempDirectory.appendingPathComponent("file2.txt")
        
        let data1 = "First file content".data(using: .utf8)!
        let data2 = "Second file content".data(using: .utf8)!
        
        try secureStorage.writeEncryptedData(data1, to: file1)
        try secureStorage.writeEncryptedData(data2, to: file2)
        
        // Store encrypted content for comparison
        let encrypted1Before = try Data(contentsOf: file1)
        let encrypted2Before = try Data(contentsOf: file2)
        
        // Rotate encryption key
        try secureStorage.rotateEncryptionKey(for: [file1, file2])
        
        // Verify files are still encrypted but with different ciphertext
        let encrypted1After = try Data(contentsOf: file1)
        let encrypted2After = try Data(contentsOf: file2)
        
        XCTAssertNotEqual(encrypted1Before, encrypted1After)
        XCTAssertNotEqual(encrypted2Before, encrypted2After)
        
        // Verify files can still be decrypted to original content
        let decrypted1 = try secureStorage.readEncryptedData(from: file1)
        let decrypted2 = try secureStorage.readEncryptedData(from: file2)
        
        XCTAssertEqual(data1, decrypted1)
        XCTAssertEqual(data2, decrypted2)
        
        print("✓ Key rotation with active data works")
    }
    
    func testConcurrentEncryptionOperations() throws {
        // Test concurrent encryption operations for thread safety
        
        let operationCount = 20
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = operationCount
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for i in 0..<operationCount {
            queue.async {
                do {
                    let fileName = "concurrent_file_\(i).txt"
                    let fileURL = self.tempDirectory.appendingPathComponent(fileName)
                    let testData = "Concurrent test data \(i)".data(using: .utf8)!
                    
                    // Write encrypted
                    try self.secureStorage.writeEncryptedData(testData, to: fileURL)
                    
                    // Read and verify
                    let decrypted = try self.secureStorage.readEncryptedData(from: fileURL)
                    XCTAssertEqual(testData, decrypted)
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent operation failed: \(error)")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        print("✓ Concurrent encryption operations work")
    }
    
    func testDataIntegrityAfterSystemRestart() throws {
        // Simulate system restart by creating new storage instance
        
        let testFile = tempDirectory.appendingPathComponent("persistent_data.txt")
        let originalData = "Data that should persist across restarts".data(using: .utf8)!
        
        // Write with first storage instance
        try secureStorage.writeEncryptedData(originalData, to: testFile)
        
        // Create new storage instance (simulating restart)
        let newStorage = SecureStorage()
        
        // Verify data can still be read
        let decryptedData = try newStorage.readEncryptedData(from: testFile)
        XCTAssertEqual(originalData, decryptedData)
        
        print("✓ Data integrity maintained across system restart")
    }
    
    func testEncryptionWithLargeFiles() throws {
        // Test encryption performance with large files
        
        let largeData = Data(repeating: 0x42, count: 50 * 1024 * 1024) // 50MB
        let largeFile = tempDirectory.appendingPathComponent("large_file.dat")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try secureStorage.writeEncryptedData(largeData, to: largeFile)
        let decryptedData = try secureStorage.readEncryptedData(from: largeFile)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        XCTAssertEqual(largeData, decryptedData)
        XCTAssertLessThan(duration, 30.0, "Large file encryption should complete within 30 seconds")
        
        print("✓ Large file encryption completed in \(String(format: "%.2f", duration)) seconds")
    }
    
    // MARK: - Security Validation Tests
    
    func testEncryptionStrengthValidation() throws {
        // Test that encryption produces cryptographically strong output
        
        let testData = "Sensitive information that needs strong encryption".data(using: .utf8)!
        let testFile = tempDirectory.appendingPathComponent("security_test.dat")
        
        try secureStorage.writeEncryptedData(testData, to: testFile)
        let encryptedData = try Data(contentsOf: testFile)
        
        // Verify encrypted data doesn't contain plaintext
        let encryptedString = String(data: encryptedData, encoding: .utf8) ?? ""
        XCTAssertFalse(encryptedString.contains("Sensitive"))
        XCTAssertFalse(encryptedString.contains("information"))
        XCTAssertFalse(encryptedString.contains("encryption"))
        
        // Test byte distribution (basic entropy check)
        var byteCounts = [UInt8: Int]()
        for byte in encryptedData {
            byteCounts[byte, default: 0] += 1
        }
        
        let maxCount = byteCounts.values.max() ?? 0
        let expectedMaxCount = encryptedData.count / 4 // Allow up to 25% for any single byte
        
        XCTAssertLessThan(maxCount, expectedMaxCount, "Encrypted data should have good byte distribution")
        
        print("✓ Encryption strength validation passed")
    }
    
    func testTamperDetection() throws {
        // Test that tampered encrypted data is detected
        
        let testData = "Data that should detect tampering".data(using: .utf8)!
        let testFile = tempDirectory.appendingPathComponent("tamper_test.dat")
        
        try secureStorage.writeEncryptedData(testData, to: testFile)
        
        // Tamper with the encrypted file
        var encryptedData = try Data(contentsOf: testFile)
        if encryptedData.count > 10 {
            encryptedData[encryptedData.count / 2] ^= 0xFF // Flip bits in the middle
        }
        try encryptedData.write(to: testFile)
        
        // Attempt to decrypt tampered data should fail
        XCTAssertThrowsError(try secureStorage.readEncryptedData(from: testFile)) { error in
            // Should be a decryption error
            XCTAssertTrue(error is SecureStorage.StorageError || 
                         error is EncryptionManager.EncryptionError)
        }
        
        print("✓ Tamper detection works")
    }
    
    // MARK: - Helper Methods
    
    private func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dirName = "encryption_integration_test_\(UUID().uuidString)"
        let dirURL = tempDir.appendingPathComponent(dirName)
        try! FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
    
    private func createMockOCRData() -> [String: Any] {
        return [
            "frame_id": "frame_123",
            "results": [
                [
                    "text": "Sample OCR text",
                    "confidence": 0.95,
                    "language": "en",
                    "roi": ["x": 10.0, "y": 20.0, "width": 100.0, "height": 30.0]
                ],
                [
                    "text": "Another text block",
                    "confidence": 0.87,
                    "language": "en", 
                    "roi": ["x": 50.0, "y": 60.0, "width": 150.0, "height": 25.0]
                ]
            ]
        ]
    }
    
    private func createMockFrameMetadata() -> [String: Any] {
        return [
            "frame_id": "frame_123",
            "timestamp": Date().timeIntervalSince1970,
            "monitor_id": 1,
            "segment_id": "segment_456",
            "phash": "1234567890abcdef",
            "entropy": 0.75,
            "app_name": "TestApp",
            "window_title": "Test Window"
        ]
    }
    
    private func createEncryptedSpansDatabase(at url: URL) throws {
        let db = try secureStorage.createEncryptedSQLiteConnection(at: url)
        
        // Create spans table
        let createTableSQL = """
            CREATE TABLE spans (
                span_id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                t_start INTEGER NOT NULL,
                t_end INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary_md TEXT,
                tags TEXT,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            );
        """
        
        var result = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        XCTAssertEqual(result, SQLITE_OK)
        
        // Insert test data
        let insertSQL = """
            INSERT INTO spans (span_id, kind, t_start, t_end, title, summary_md, tags)
            VALUES ('span_1', 'activity', 1000, 2000, 'Test Activity', '# Test Summary', '["test", "activity"]');
        """
        
        result = sqlite3_exec(db, insertSQL, nil, nil, nil)
        XCTAssertEqual(result, SQLITE_OK)
        
        sqlite3_close(db)
        
        // Encrypt the database
        try secureStorage.encryptSQLiteDatabase(at: url)
    }
}