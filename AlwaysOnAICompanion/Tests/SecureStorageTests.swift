import XCTest
import SQLite3
@testable import Shared

class SecureStorageTests: XCTestCase {
    
    var secureStorage: SecureStorage!
    var testData: Data!
    var testString: String!
    
    override func setUp() {
        super.setUp()
        secureStorage = SecureStorage()
        testData = "Hello, Secure World! This is test data.".data(using: .utf8)!
        testString = "This is a test string for secure storage."
    }
    
    override func tearDown() {
        secureStorage = nil
        testData = nil
        testString = nil
        super.tearDown()
    }
    
    // MARK: - File Operations Tests
    
    func testWriteAndReadEncryptedData() throws {
        let tempURL = createTempFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Write encrypted data
        try secureStorage.writeEncryptedData(testData, to: tempURL)
        
        // Verify file exists and is encrypted (different from original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        let fileContent = try Data(contentsOf: tempURL)
        XCTAssertNotEqual(testData, fileContent)
        
        // Read and decrypt
        let decryptedData = try secureStorage.readEncryptedData(from: tempURL)
        XCTAssertEqual(testData, decryptedData)
    }
    
    func testWriteAndReadEncryptedString() throws {
        let tempURL = createTempFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Write encrypted string
        try secureStorage.writeEncryptedString(testString, to: tempURL)
        
        // Read and decrypt
        let decryptedString = try secureStorage.readEncryptedString(from: tempURL)
        XCTAssertEqual(testString, decryptedString)
    }
    
    func testEncryptExistingFile() throws {
        let tempURL = createTempFile(with: testData)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Encrypt existing file
        try secureStorage.encryptExistingFile(at: tempURL)
        
        // Verify file is encrypted
        let encryptedContent = try Data(contentsOf: tempURL)
        XCTAssertNotEqual(testData, encryptedContent)
        
        // Decrypt file
        try secureStorage.decryptExistingFile(at: tempURL)
        
        // Verify file is back to original
        let decryptedContent = try Data(contentsOf: tempURL)
        XCTAssertEqual(testData, decryptedContent)
    }
    
    func testCreateEncryptedBackup() throws {
        let sourceURL = createTempFile(with: testData)
        let backupURL = createTempFileURL()
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: backupURL)
        }
        
        // Create encrypted backup
        try secureStorage.createEncryptedBackup(of: sourceURL, to: backupURL)
        
        // Verify source is unchanged
        let sourceContent = try Data(contentsOf: sourceURL)
        XCTAssertEqual(testData, sourceContent)
        
        // Verify backup is encrypted
        let backupContent = try Data(contentsOf: backupURL)
        XCTAssertNotEqual(testData, backupContent)
        
        // Decrypt backup and verify
        let decryptedBackup = try secureStorage.readEncryptedData(from: backupURL)
        XCTAssertEqual(testData, decryptedBackup)
    }
    
    // MARK: - Directory Operations Tests
    
    func testEncryptDirectory() throws {
        let tempDir = createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create test files in directory
        let file1URL = tempDir.appendingPathComponent("file1.txt")
        let file2URL = tempDir.appendingPathComponent("file2.txt")
        let subDirURL = tempDir.appendingPathComponent("subdir")
        let file3URL = subDirURL.appendingPathComponent("file3.txt")
        
        try FileManager.default.createDirectory(at: subDirURL, withIntermediateDirectories: true)
        try testData.write(to: file1URL)
        try testData.write(to: file2URL)
        try testData.write(to: file3URL)
        
        // Encrypt directory
        try secureStorage.encryptDirectory(at: tempDir, recursive: true)
        
        // Verify all files are encrypted
        let encrypted1 = try Data(contentsOf: file1URL)
        let encrypted2 = try Data(contentsOf: file2URL)
        let encrypted3 = try Data(contentsOf: file3URL)
        
        XCTAssertNotEqual(testData, encrypted1)
        XCTAssertNotEqual(testData, encrypted2)
        XCTAssertNotEqual(testData, encrypted3)
        
        // Decrypt directory
        try secureStorage.decryptDirectory(at: tempDir, recursive: true)
        
        // Verify all files are decrypted
        let decrypted1 = try Data(contentsOf: file1URL)
        let decrypted2 = try Data(contentsOf: file2URL)
        let decrypted3 = try Data(contentsOf: file3URL)
        
        XCTAssertEqual(testData, decrypted1)
        XCTAssertEqual(testData, decrypted2)
        XCTAssertEqual(testData, decrypted3)
    }
    
    // MARK: - Secure File Management Tests
    
    func testSecureDelete() throws {
        let tempURL = createTempFile(with: testData)
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Securely delete
        try secureStorage.secureDelete(at: tempURL)
        
        // Verify file is gone
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
    }
    
    func testSecureDeleteNonexistentFile() throws {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString)")
        
        // Should not throw error for nonexistent file
        try secureStorage.secureDelete(at: nonexistentURL)
    }
    
    func testCreateSecureTempFile() throws {
        let tempURL = try secureStorage.createSecureTempFile(prefix: "test")
        
        // Verify temp file path is in temp directory
        XCTAssertTrue(tempURL.path.contains(FileManager.default.temporaryDirectory.path))
        XCTAssertTrue(tempURL.lastPathComponent.contains("test"))
        XCTAssertTrue(tempURL.lastPathComponent.contains("encrypted"))
    }
    
    // MARK: - Key Management Tests
    
    func testRotateEncryptionKey() throws {
        let file1URL = createTempFile(with: testData)
        let file2URL = createTempFile(with: "Different test data".data(using: .utf8)!)
        defer {
            try? FileManager.default.removeItem(at: file1URL)
            try? FileManager.default.removeItem(at: file2URL)
        }
        
        // Encrypt files
        try secureStorage.encryptExistingFile(at: file1URL)
        try secureStorage.encryptExistingFile(at: file2URL)
        
        // Store encrypted content for comparison
        let encrypted1Before = try Data(contentsOf: file1URL)
        let encrypted2Before = try Data(contentsOf: file2URL)
        
        // Rotate key
        try secureStorage.rotateEncryptionKey(for: [file1URL, file2URL])
        
        // Verify files are still encrypted but with different ciphertext
        let encrypted1After = try Data(contentsOf: file1URL)
        let encrypted2After = try Data(contentsOf: file2URL)
        
        XCTAssertNotEqual(encrypted1Before, encrypted1After)
        XCTAssertNotEqual(encrypted2Before, encrypted2After)
        
        // Verify files can still be decrypted to original content
        try secureStorage.decryptExistingFile(at: file1URL)
        try secureStorage.decryptExistingFile(at: file2URL)
        
        let decrypted1 = try Data(contentsOf: file1URL)
        let decrypted2 = try Data(contentsOf: file2URL)
        
        XCTAssertEqual(testData, decrypted1)
        XCTAssertEqual("Different test data".data(using: .utf8)!, decrypted2)
    }
    
    // MARK: - SQLite Integration Tests
    
    func testCreateEncryptedSQLiteConnection() throws {
        let tempURL = createTempFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Create encrypted SQLite connection
        let db = try secureStorage.createEncryptedSQLiteConnection(at: tempURL)
        XCTAssertNotNil(db)
        
        // Test basic operations
        var createTableSQL = "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);"
        var result = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        XCTAssertEqual(result, SQLITE_OK)
        
        var insertSQL = "INSERT INTO test (name) VALUES ('Test Name');"
        result = sqlite3_exec(db, insertSQL, nil, nil, nil)
        XCTAssertEqual(result, SQLITE_OK)
        
        // Close connection
        sqlite3_close(db)
        
        // Verify database file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
    }
    
    func testEncryptSQLiteDatabase() throws {
        let tempURL = createTempFileURL()
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(at: tempURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: tempURL.appendingPathExtension("shm"))
        }
        
        // Create a simple SQLite database
        let db = try secureStorage.createEncryptedSQLiteConnection(at: tempURL)
        var createTableSQL = "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);"
        var result = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        XCTAssertEqual(result, SQLITE_OK)
        sqlite3_close(db)
        
        // Get original content
        let originalContent = try Data(contentsOf: tempURL)
        
        // Encrypt database
        try secureStorage.encryptSQLiteDatabase(at: tempURL)
        
        // Verify database is encrypted
        let encryptedContent = try Data(contentsOf: tempURL)
        XCTAssertNotEqual(originalContent, encryptedContent)
        
        // Decrypt database
        try secureStorage.decryptSQLiteDatabase(at: tempURL)
        
        // Verify database is back to original
        let decryptedContent = try Data(contentsOf: tempURL)
        XCTAssertEqual(originalContent, decryptedContent)
    }
    
    // MARK: - Error Handling Tests
    
    func testReadNonexistentEncryptedFile() {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString)")
        
        XCTAssertThrowsError(try secureStorage.readEncryptedData(from: nonexistentURL))
        XCTAssertThrowsError(try secureStorage.readEncryptedString(from: nonexistentURL))
    }
    
    func testEncryptNonexistentFile() {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString)")
        
        XCTAssertThrowsError(try secureStorage.encryptExistingFile(at: nonexistentURL))
        XCTAssertThrowsError(try secureStorage.decryptExistingFile(at: nonexistentURL))
    }
    
    // MARK: - Performance Tests
    
    func testLargeFileEncryption() throws {
        let largeData = Data(repeating: 0x42, count: 10 * 1024 * 1024) // 10MB
        let tempURL = createTempFile(with: largeData)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        measure {
            do {
                try secureStorage.encryptExistingFile(at: tempURL)
                try secureStorage.decryptExistingFile(at: tempURL)
            } catch {
                XCTFail("Large file encryption failed: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTempFile(with data: Data) -> URL {
        let tempURL = createTempFileURL()
        try! data.write(to: tempURL)
        return tempURL
    }
    
    private func createTempFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "secure_test_\(UUID().uuidString).dat"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dirName = "secure_test_dir_\(UUID().uuidString)"
        let dirURL = tempDir.appendingPathComponent(dirName)
        try! FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
}