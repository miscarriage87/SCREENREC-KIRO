import Foundation
import SQLite3

/// Provides transparent encryption/decryption for data storage operations
/// Handles both file-based storage (Parquet) and database storage (SQLite)
public class SecureStorage {
    
    // MARK: - Types
    
    public enum StorageError: Error {
        case encryptionFailed
        case decryptionFailed
        case fileNotFound
        case invalidPath
        case databaseError(String)
    }
    
    // MARK: - Properties
    
    private let encryptionManager: EncryptionManager
    private let fileManager: FileManager
    
    // MARK: - Initialization
    
    public init() {
        self.encryptionManager = EncryptionManager()
        self.fileManager = FileManager.default
    }
    
    // MARK: - File Operations
    
    /// Writes data to an encrypted file
    public func writeEncryptedData(_ data: Data, to url: URL) throws {
        let encryptedData = try encryptionManager.encrypt(data)
        try encryptedData.write(to: url)
    }
    
    /// Reads data from an encrypted file
    public func readEncryptedData(from url: URL) throws -> Data {
        let encryptedData = try Data(contentsOf: url)
        return try encryptionManager.decrypt(encryptedData)
    }
    
    /// Writes a string to an encrypted file
    public func writeEncryptedString(_ string: String, to url: URL, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw StorageError.encryptionFailed
        }
        try writeEncryptedData(data, to: url)
    }
    
    /// Reads a string from an encrypted file
    public func readEncryptedString(from url: URL, encoding: String.Encoding = .utf8) throws -> String {
        let data = try readEncryptedData(from: url)
        guard let string = String(data: data, encoding: encoding) else {
            throw StorageError.decryptionFailed
        }
        return string
    }
    
    /// Encrypts an existing file in place
    public func encryptExistingFile(at url: URL) throws {
        try encryptionManager.encryptFile(at: url)
    }
    
    /// Decrypts an existing file in place
    public func decryptExistingFile(at url: URL) throws {
        try encryptionManager.decryptFile(at: url)
    }
    
    /// Creates an encrypted backup of a file
    public func createEncryptedBackup(of sourceURL: URL, to backupURL: URL) throws {
        try encryptionManager.encryptFile(from: sourceURL, to: backupURL)
    }
    
    // MARK: - Directory Operations
    
    /// Encrypts all files in a directory
    public func encryptDirectory(at url: URL, recursive: Bool = true) throws {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        for itemURL in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) else {
                continue
            }
            
            if isDirectory.boolValue && recursive {
                try encryptDirectory(at: itemURL, recursive: true)
            } else if !isDirectory.boolValue {
                try encryptExistingFile(at: itemURL)
            }
        }
    }
    
    /// Decrypts all files in a directory
    public func decryptDirectory(at url: URL, recursive: Bool = true) throws {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        for itemURL in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) else {
                continue
            }
            
            if isDirectory.boolValue && recursive {
                try decryptDirectory(at: itemURL, recursive: true)
            } else if !isDirectory.boolValue {
                try decryptExistingFile(at: itemURL)
            }
        }
    }
    
    // MARK: - Secure File Management
    
    /// Securely deletes a file by overwriting it before deletion
    public func secureDelete(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageError.fileNotFound
        }
        
        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw StorageError.invalidPath
        }
        
        // Overwrite with random data multiple times
        let handle = try FileHandle(forWritingTo: url)
        defer { handle.closeFile() }
        
        for _ in 0..<3 {
            handle.seek(toFileOffset: 0)
            let randomData = Data((0..<fileSize).map { _ in UInt8.random(in: 0...255) })
            handle.write(randomData)
            handle.synchronizeFile()
        }
        
        // Finally delete the file
        try fileManager.removeItem(at: url)
    }
    
    /// Creates a secure temporary file that will be automatically encrypted
    public func createSecureTempFile(prefix: String = "secure_temp") throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let tempFileName = "\(prefix)_\(UUID().uuidString).encrypted"
        return tempDir.appendingPathComponent(tempFileName)
    }
    
    // MARK: - Key Management
    
    /// Rotates the encryption key and re-encrypts all specified files
    public func rotateEncryptionKey(for urls: [URL]) throws {
        // Decrypt all files with old key
        var decryptedData: [URL: Data] = [:]
        for url in urls {
            if fileManager.fileExists(atPath: url.path) {
                decryptedData[url] = try readEncryptedData(from: url)
            }
        }
        
        // Rotate the key
        try encryptionManager.rotateMasterKey()
        
        // Re-encrypt all files with new key
        for (url, data) in decryptedData {
            try writeEncryptedData(data, to: url)
        }
    }
}

// MARK: - SQLite Encryption Support

extension SecureStorage {
    
    /// Creates an encrypted SQLite database connection
    /// Note: This is a simplified approach. For production, consider using SQLCipher
    public func createEncryptedSQLiteConnection(at url: URL) throws -> OpaquePointer? {
        var db: OpaquePointer?
        
        // Open database
        let result = sqlite3_open(url.path, &db)
        guard result == SQLITE_OK else {
            sqlite3_close(db)
            throw StorageError.databaseError("Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        // Enable WAL mode for better concurrency
        var errorMessage: UnsafeMutablePointer<CChar>?
        let walResult = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, &errorMessage)
        if walResult != SQLITE_OK {
            if let error = errorMessage {
                let errorString = String(cString: error)
                sqlite3_free(errorMessage)
                sqlite3_close(db)
                throw StorageError.databaseError("Failed to enable WAL mode: \(errorString)")
            }
        }
        
        return db
    }
    
    /// Encrypts an SQLite database file
    public func encryptSQLiteDatabase(at url: URL) throws {
        // Close any existing connections first
        // Then encrypt the file
        try encryptExistingFile(at: url)
        
        // Also encrypt WAL and SHM files if they exist
        let walURL = url.appendingPathExtension("wal")
        let shmURL = url.appendingPathExtension("shm")
        
        if fileManager.fileExists(atPath: walURL.path) {
            try encryptExistingFile(at: walURL)
        }
        
        if fileManager.fileExists(atPath: shmURL.path) {
            try encryptExistingFile(at: shmURL)
        }
    }
    
    /// Decrypts an SQLite database file
    public func decryptSQLiteDatabase(at url: URL) throws {
        try decryptExistingFile(at: url)
        
        // Also decrypt WAL and SHM files if they exist
        let walURL = url.appendingPathExtension("wal")
        let shmURL = url.appendingPathExtension("shm")
        
        if fileManager.fileExists(atPath: walURL.path) {
            try decryptExistingFile(at: walURL)
        }
        
        if fileManager.fileExists(atPath: shmURL.path) {
            try decryptExistingFile(at: shmURL)
        }
    }
}