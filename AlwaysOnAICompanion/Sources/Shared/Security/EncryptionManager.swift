import Foundation
import Security
import CryptoKit

/// Manages encryption and decryption operations for the Always-On AI Companion
/// Uses AES-GCM for symmetric encryption with keys stored in macOS Keychain
public class EncryptionManager {
    
    // MARK: - Types
    
    public enum EncryptionError: Error {
        case keyGenerationFailed
        case keyRetrievalFailed
        case keyStorageFailed
        case encryptionFailed
        case decryptionFailed
        case invalidData
        case keychainError(OSStatus)
    }
    
    private struct EncryptedData {
        let nonce: Data
        let ciphertext: Data
        let tag: Data
    }
    
    // MARK: - Constants
    
    private static let keySize = 32 // 256-bit key
    private static let nonceSize = 12 // 96-bit nonce for AES-GCM
    private static let tagSize = 16 // 128-bit authentication tag
    internal static let keychainService = "com.alwayson.aicompanion.encryption"
    private static let masterKeyIdentifier = "master-encryption-key"
    
    // MARK: - Properties
    
    private let keychain: KeychainManager
    private var cachedMasterKey: SymmetricKey?
    
    // MARK: - Initialization
    
    public init() {
        self.keychain = KeychainManager()
    }
    
    // MARK: - Public Interface
    
    /// Encrypts data using AES-GCM with the master key
    public func encrypt(_ data: Data) throws -> Data {
        let masterKey = try getMasterKey()
        
        // Generate random nonce
        var nonce = Data(count: Self.nonceSize)
        let result = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, Self.nonceSize, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw EncryptionError.encryptionFailed
        }
        
        // Encrypt using AES-GCM
        do {
            let sealedBox = try AES.GCM.seal(data, using: masterKey, nonce: AES.GCM.Nonce(data: nonce))
            
            // Combine nonce + ciphertext + tag
            var encryptedData = Data()
            encryptedData.append(nonce)
            encryptedData.append(sealedBox.ciphertext)
            encryptedData.append(sealedBox.tag)
            
            return encryptedData
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    /// Decrypts data using AES-GCM with the master key
    public func decrypt(_ encryptedData: Data) throws -> Data {
        guard encryptedData.count >= Self.nonceSize + Self.tagSize else {
            throw EncryptionError.invalidData
        }
        
        let masterKey = try getMasterKey()
        
        // Extract components
        let nonce = encryptedData.prefix(Self.nonceSize)
        let ciphertext = encryptedData.dropFirst(Self.nonceSize).dropLast(Self.tagSize)
        let tag = encryptedData.suffix(Self.tagSize)
        
        // Decrypt using AES-GCM
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: ciphertext,
                tag: tag
            )
            
            return try AES.GCM.open(sealedBox, using: masterKey)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
    
    /// Encrypts a file in place
    public func encryptFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        let encryptedData = try encrypt(data)
        try encryptedData.write(to: url)
    }
    
    /// Decrypts a file in place
    public func decryptFile(at url: URL) throws {
        let encryptedData = try Data(contentsOf: url)
        let data = try decrypt(encryptedData)
        try data.write(to: url)
    }
    
    /// Creates an encrypted copy of a file
    public func encryptFile(from sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        let encryptedData = try encrypt(data)
        try encryptedData.write(to: destinationURL)
    }
    
    /// Creates a decrypted copy of a file
    public func decryptFile(from sourceURL: URL, to destinationURL: URL) throws {
        let encryptedData = try Data(contentsOf: sourceURL)
        let data = try decrypt(encryptedData)
        try data.write(to: destinationURL)
    }
    
    /// Rotates the master key (re-encrypts all data with new key)
    public func rotateMasterKey() throws {
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        
        // Store new key in keychain
        try keychain.storeKey(newKey, identifier: Self.masterKeyIdentifier)
        
        // Update cached key
        cachedMasterKey = newKey
    }
    
    // MARK: - Private Methods
    
    private func getMasterKey() throws -> SymmetricKey {
        if let cachedKey = cachedMasterKey {
            return cachedKey
        }
        
        // Try to retrieve existing key from keychain
        if let existingKey = try? keychain.retrieveKey(identifier: Self.masterKeyIdentifier) {
            cachedMasterKey = existingKey
            return existingKey
        }
        
        // Generate new key if none exists
        let newKey = SymmetricKey(size: .bits256)
        try keychain.storeKey(newKey, identifier: Self.masterKeyIdentifier)
        
        cachedMasterKey = newKey
        return newKey
    }
}

// MARK: - Keychain Manager

private class KeychainManager {
    
    func storeKey(_ key: SymmetricKey, identifier: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: EncryptionManager.keychainService,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionManager.EncryptionError.keychainError(status)
        }
    }
    
    func retrieveKey(identifier: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: EncryptionManager.keychainService,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw EncryptionManager.EncryptionError.keychainError(status)
        }
        
        guard let keyData = result as? Data else {
            throw EncryptionManager.EncryptionError.keyRetrievalFailed
        }
        
        return SymmetricKey(data: keyData)
    }
    
    func deleteKey(identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: EncryptionManager.keychainService,
            kSecAttrAccount as String: identifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionManager.EncryptionError.keychainError(status)
        }
    }
}