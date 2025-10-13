import XCTest
import CryptoKit
@testable import Shared

class EncryptionManagerTests: XCTestCase {
    
    var encryptionManager: EncryptionManager!
    var testData: Data!
    
    override func setUp() {
        super.setUp()
        encryptionManager = EncryptionManager()
        testData = "Hello, World! This is test data for encryption testing.".data(using: .utf8)!
    }
    
    override func tearDown() {
        encryptionManager = nil
        testData = nil
        super.tearDown()
    }
    
    // MARK: - Basic Encryption/Decryption Tests
    
    func testEncryptDecryptRoundtrip() throws {
        // Test basic encryption and decryption
        let encryptedData = try encryptionManager.encrypt(testData)
        let decryptedData = try encryptionManager.decrypt(encryptedData)
        
        XCTAssertEqual(testData, decryptedData, "Decrypted data should match original")
        XCTAssertNotEqual(testData, encryptedData, "Encrypted data should be different from original")
    }
    
    func testEncryptionProducesUniqueResults() throws {
        // Test that encryption produces different results each time (due to random nonce)
        let encrypted1 = try encryptionManager.encrypt(testData)
        let encrypted2 = try encryptionManager.encrypt(testData)
        
        XCTAssertNotEqual(encrypted1, encrypted2, "Encryption should produce unique results due to random nonce")
        
        // But both should decrypt to the same original data
        let decrypted1 = try encryptionManager.decrypt(encrypted1)
        let decrypted2 = try encryptionManager.decrypt(encrypted2)
        
        XCTAssertEqual(decrypted1, testData)
        XCTAssertEqual(decrypted2, testData)
    }
    
    func testEmptyDataEncryption() throws {
        let emptyData = Data()
        let encrypted = try encryptionManager.encrypt(emptyData)
        let decrypted = try encryptionManager.decrypt(encrypted)
        
        XCTAssertEqual(emptyData, decrypted)
    }
    
    func testLargeDataEncryption() throws {
        // Test with 1MB of data
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        let encrypted = try encryptionManager.encrypt(largeData)
        let decrypted = try encryptionManager.decrypt(encrypted)
        
        XCTAssertEqual(largeData, decrypted)
    }
    
    // MARK: - File Encryption Tests
    
    func testFileEncryptionInPlace() throws {
        let tempURL = createTempFile(with: testData)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Encrypt file in place
        try encryptionManager.encryptFile(at: tempURL)
        
        // Verify file is encrypted (different from original)
        let encryptedContent = try Data(contentsOf: tempURL)
        XCTAssertNotEqual(testData, encryptedContent)
        
        // Decrypt file in place
        try encryptionManager.decryptFile(at: tempURL)
        
        // Verify file is back to original
        let decryptedContent = try Data(contentsOf: tempURL)
        XCTAssertEqual(testData, decryptedContent)
    }
    
    func testFileEncryptionToNewLocation() throws {
        let sourceURL = createTempFile(with: testData)
        let destURL = createTempFileURL()
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: destURL)
        }
        
        // Encrypt to new location
        try encryptionManager.encryptFile(from: sourceURL, to: destURL)
        
        // Verify source is unchanged
        let sourceContent = try Data(contentsOf: sourceURL)
        XCTAssertEqual(testData, sourceContent)
        
        // Verify destination is encrypted
        let encryptedContent = try Data(contentsOf: destURL)
        XCTAssertNotEqual(testData, encryptedContent)
        
        // Decrypt destination
        try encryptionManager.decryptFile(at: destURL)
        let decryptedContent = try Data(contentsOf: destURL)
        XCTAssertEqual(testData, decryptedContent)
    }
    
    // MARK: - Error Handling Tests
    
    func testDecryptionWithInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // Too short to be valid encrypted data
        
        XCTAssertThrowsError(try encryptionManager.decrypt(invalidData)) { error in
            XCTAssertTrue(error is EncryptionManager.EncryptionError)
        }
    }
    
    func testDecryptionWithCorruptedData() throws {
        var encryptedData = try encryptionManager.encrypt(testData)
        
        // Corrupt the data by flipping some bits
        encryptedData[encryptedData.count / 2] ^= 0xFF
        
        XCTAssertThrowsError(try encryptionManager.decrypt(encryptedData)) { error in
            XCTAssertTrue(error is EncryptionManager.EncryptionError)
        }
    }
    
    func testFileEncryptionWithNonexistentFile() {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_file_\(UUID().uuidString)")
        
        XCTAssertThrowsError(try encryptionManager.encryptFile(at: nonexistentURL))
        XCTAssertThrowsError(try encryptionManager.decryptFile(at: nonexistentURL))
    }
    
    // MARK: - Key Management Tests
    
    func testKeyRotation() throws {
        // Encrypt some data with the current key
        let originalEncrypted = try encryptionManager.encrypt(testData)
        
        // Rotate the key
        try encryptionManager.rotateMasterKey()
        
        // The old encrypted data should no longer be decryptable
        XCTAssertThrowsError(try encryptionManager.decrypt(originalEncrypted))
        
        // But new encryption should work
        let newEncrypted = try encryptionManager.encrypt(testData)
        let decrypted = try encryptionManager.decrypt(newEncrypted)
        XCTAssertEqual(testData, decrypted)
    }
    
    // MARK: - Performance Tests
    
    func testEncryptionPerformance() throws {
        let largeData = Data(repeating: 0x42, count: 10 * 1024 * 1024) // 10MB
        
        measure {
            do {
                let _ = try encryptionManager.encrypt(largeData)
            } catch {
                XCTFail("Encryption failed: \(error)")
            }
        }
    }
    
    func testDecryptionPerformance() throws {
        let largeData = Data(repeating: 0x42, count: 10 * 1024 * 1024) // 10MB
        let encrypted = try encryptionManager.encrypt(largeData)
        
        measure {
            do {
                let _ = try encryptionManager.decrypt(encrypted)
            } catch {
                XCTFail("Decryption failed: \(error)")
            }
        }
    }
    
    // MARK: - Security Tests
    
    func testEncryptedDataContainsNoPlaintext() throws {
        let sensitiveData = "password123".data(using: .utf8)!
        let encrypted = try encryptionManager.encrypt(sensitiveData)
        
        // Verify that the plaintext doesn't appear in the encrypted data
        let encryptedString = String(data: encrypted, encoding: .utf8) ?? ""
        XCTAssertFalse(encryptedString.contains("password123"))
        
        // Also check as raw bytes
        let plaintextBytes = sensitiveData
        let encryptedBytes = encrypted
        
        // Look for the plaintext pattern in encrypted data
        var found = false
        if encryptedBytes.count >= plaintextBytes.count {
            for i in 0...(encryptedBytes.count - plaintextBytes.count) {
                let slice = encryptedBytes[i..<(i + plaintextBytes.count)]
                if Data(slice) == plaintextBytes {
                    found = true
                    break
                }
            }
        }
        XCTAssertFalse(found, "Plaintext should not be found in encrypted data")
    }
    
    func testEncryptionStrength() throws {
        // Test that encryption produces sufficiently random-looking output
        let encrypted = try encryptionManager.encrypt(testData)
        
        // Basic entropy check - encrypted data should have reasonable byte distribution
        var byteCounts = [UInt8: Int]()
        for byte in encrypted {
            byteCounts[byte, default: 0] += 1
        }
        
        // With good encryption, we shouldn't see any byte value dominating
        let maxCount = byteCounts.values.max() ?? 0
        let expectedMaxCount = encrypted.count / 4 // Allow up to 25% for any single byte value
        
        XCTAssertLessThan(maxCount, expectedMaxCount, "Encrypted data should have good byte distribution")
    }
    
    // MARK: - Helper Methods
    
    private func createTempFile(with data: Data) -> URL {
        let tempURL = createTempFileURL()
        try! data.write(to: tempURL)
        return tempURL
    }
    
    private func createTempFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).dat"
        return tempDir.appendingPathComponent(fileName)
    }
}

// MARK: - Keychain Tests

class KeychainManagerTests: XCTestCase {
    
    func testKeychainIntegration() throws {
        let encryptionManager = EncryptionManager()
        let testData = "Test keychain integration".data(using: .utf8)!
        
        // This test verifies that the keychain integration works
        // by encrypting data, creating a new manager instance, and decrypting
        let encrypted = try encryptionManager.encrypt(testData)
        
        // Create a new manager instance (should retrieve the same key from keychain)
        let newManager = EncryptionManager()
        let decrypted = try newManager.decrypt(encrypted)
        
        XCTAssertEqual(testData, decrypted)
    }
}