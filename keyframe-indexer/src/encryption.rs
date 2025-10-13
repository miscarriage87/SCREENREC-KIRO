use aes_gcm::{
    aead::{Aead, AeadCore, KeyInit, OsRng},
    Aes256Gcm, Key, Nonce,
};
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Encryption manager for Parquet files and other data
/// Uses AES-256-GCM for authenticated encryption
pub struct EncryptionManager {
    cipher: Aes256Gcm,
}

#[derive(Debug, Serialize, Deserialize)]
struct EncryptedData {
    nonce: Vec<u8>,
    ciphertext: Vec<u8>,
}

impl EncryptionManager {
    /// Creates a new encryption manager with a key from the environment
    /// In production, this should integrate with the Swift keychain manager
    pub fn new() -> Result<Self> {
        let key = Self::get_or_create_key()?;
        let cipher = Aes256Gcm::new(&key);
        Ok(Self { cipher })
    }

    /// Creates a new encryption manager with a specific key
    pub fn with_key(key_bytes: &[u8; 32]) -> Self {
        let key = Key::<Aes256Gcm>::from_slice(key_bytes);
        let cipher = Aes256Gcm::new(key);
        Self { cipher }
    }

    /// Encrypts data using AES-256-GCM
    pub fn encrypt(&self, plaintext: &[u8]) -> Result<Vec<u8>> {
        let nonce = Aes256Gcm::generate_nonce(&mut OsRng);
        let ciphertext = self
            .cipher
            .encrypt(&nonce, plaintext)
            .map_err(|e| anyhow::anyhow!("Encryption failed: {}", e))?;

        let encrypted_data = EncryptedData {
            nonce: nonce.to_vec(),
            ciphertext,
        };

        bincode::serialize(&encrypted_data).context("Failed to serialize encrypted data")
    }

    /// Decrypts data using AES-256-GCM
    pub fn decrypt(&self, encrypted_bytes: &[u8]) -> Result<Vec<u8>> {
        let encrypted_data: EncryptedData =
            bincode::deserialize(encrypted_bytes).context("Failed to deserialize encrypted data")?;

        let nonce = Nonce::from_slice(&encrypted_data.nonce);
        let plaintext = self
            .cipher
            .decrypt(nonce, encrypted_data.ciphertext.as_ref())
            .map_err(|e| anyhow::anyhow!("Decryption failed: {}", e))?;

        Ok(plaintext)
    }

    /// Encrypts a file in place
    pub fn encrypt_file<P: AsRef<Path>>(&self, file_path: P) -> Result<()> {
        let path = file_path.as_ref();
        let plaintext = fs::read(path).context("Failed to read file for encryption")?;
        let encrypted = self.encrypt(&plaintext)?;
        fs::write(path, encrypted).context("Failed to write encrypted file")?;
        Ok(())
    }

    /// Decrypts a file in place
    pub fn decrypt_file<P: AsRef<Path>>(&self, file_path: P) -> Result<()> {
        let path = file_path.as_ref();
        let encrypted = fs::read(path).context("Failed to read encrypted file")?;
        let plaintext = self.decrypt(&encrypted)?;
        fs::write(path, plaintext).context("Failed to write decrypted file")?;
        Ok(())
    }

    /// Encrypts a file to a new location
    pub fn encrypt_file_to<P: AsRef<Path>, Q: AsRef<Path>>(
        &self,
        source_path: P,
        dest_path: Q,
    ) -> Result<()> {
        let plaintext = fs::read(source_path).context("Failed to read source file")?;
        let encrypted = self.encrypt(&plaintext)?;
        fs::write(dest_path, encrypted).context("Failed to write encrypted file")?;
        Ok(())
    }

    /// Decrypts a file to a new location
    pub fn decrypt_file_to<P: AsRef<Path>, Q: AsRef<Path>>(
        &self,
        source_path: P,
        dest_path: Q,
    ) -> Result<()> {
        let encrypted = fs::read(source_path).context("Failed to read encrypted file")?;
        let plaintext = self.decrypt(&encrypted)?;
        fs::write(dest_path, plaintext).context("Failed to write decrypted file")?;
        Ok(())
    }

    /// Securely deletes a file by overwriting it with random data
    pub fn secure_delete<P: AsRef<Path>>(&self, file_path: P) -> Result<()> {
        let path = file_path.as_ref();
        if !path.exists() {
            return Ok(());
        }

        let file_size = fs::metadata(path)?.len() as usize;
        
        // Overwrite with random data 3 times
        for _ in 0..3 {
            let random_data: Vec<u8> = (0..file_size).map(|_| rand::random::<u8>()).collect();
            fs::write(path, &random_data)?;
        }

        // Finally delete the file
        fs::remove_file(path).context("Failed to delete file after secure overwrite")?;
        Ok(())
    }

    /// Gets or creates an encryption key
    /// In production, this should integrate with the Swift keychain manager
    fn get_or_create_key() -> Result<Key<Aes256Gcm>> {
        // For now, use a key from environment or generate a new one
        // In production, this should call into the Swift keychain manager
        if let Ok(key_hex) = std::env::var("ENCRYPTION_KEY") {
            let key_bytes = hex::decode(key_hex).context("Invalid encryption key format")?;
            if key_bytes.len() != 32 {
                return Err(anyhow::anyhow!("Encryption key must be 32 bytes"));
            }
            Ok(*Key::<Aes256Gcm>::from_slice(&key_bytes))
        } else {
            // Generate a new key and warn that it should be stored securely
            let key = Aes256Gcm::generate_key(OsRng);
            eprintln!(
                "Warning: Generated new encryption key. Store this securely: {}",
                hex::encode(&key)
            );
            Ok(key)
        }
    }
}

/// Secure Parquet writer that encrypts data before writing
pub struct SecureParquetWriter {
    encryption_manager: EncryptionManager,
}

impl SecureParquetWriter {
    pub fn new() -> Result<Self> {
        Ok(Self {
            encryption_manager: EncryptionManager::new()?,
        })
    }

    /// Writes encrypted Parquet data to a file
    pub fn write_encrypted_parquet<P: AsRef<Path>>(
        &self,
        parquet_data: &[u8],
        file_path: P,
    ) -> Result<()> {
        let encrypted_data = self.encryption_manager.encrypt(parquet_data)?;
        fs::write(file_path, encrypted_data).context("Failed to write encrypted Parquet file")?;
        Ok(())
    }

    /// Reads and decrypts Parquet data from a file
    pub fn read_encrypted_parquet<P: AsRef<Path>>(&self, file_path: P) -> Result<Vec<u8>> {
        let encrypted_data = fs::read(file_path).context("Failed to read encrypted Parquet file")?;
        self.encryption_manager.decrypt(&encrypted_data)
    }

    /// Encrypts an existing Parquet file
    pub fn encrypt_existing_parquet<P: AsRef<Path>>(&self, file_path: P) -> Result<()> {
        self.encryption_manager.encrypt_file(file_path)
    }

    /// Decrypts an existing Parquet file
    pub fn decrypt_existing_parquet<P: AsRef<Path>>(&self, file_path: P) -> Result<()> {
        self.encryption_manager.decrypt_file(file_path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_encrypt_decrypt_roundtrip() {
        let key = [0u8; 32]; // Test key
        let manager = EncryptionManager::with_key(&key);
        
        let original_data = b"Hello, World! This is test data for encryption.";
        
        let encrypted = manager.encrypt(original_data).unwrap();
        let decrypted = manager.decrypt(&encrypted).unwrap();
        
        assert_eq!(original_data, decrypted.as_slice());
    }

    #[test]
    fn test_file_encryption() {
        let key = [0u8; 32]; // Test key
        let manager = EncryptionManager::with_key(&key);
        
        let temp_file = NamedTempFile::new().unwrap();
        let original_data = b"Test file content for encryption";
        
        // Write original data
        fs::write(temp_file.path(), original_data).unwrap();
        
        // Encrypt file
        manager.encrypt_file(temp_file.path()).unwrap();
        
        // Verify file is encrypted (different from original)
        let encrypted_content = fs::read(temp_file.path()).unwrap();
        assert_ne!(original_data, encrypted_content.as_slice());
        
        // Decrypt file
        manager.decrypt_file(temp_file.path()).unwrap();
        
        // Verify file is back to original
        let decrypted_content = fs::read(temp_file.path()).unwrap();
        assert_eq!(original_data, decrypted_content.as_slice());
    }

    #[test]
    fn test_secure_parquet_writer() {
        let key = [0u8; 32]; // Test key
        let manager = EncryptionManager::with_key(&key);
        let writer = SecureParquetWriter {
            encryption_manager: manager,
        };
        
        let temp_file = NamedTempFile::new().unwrap();
        let parquet_data = b"Mock Parquet file content";
        
        // Write encrypted
        writer.write_encrypted_parquet(parquet_data, temp_file.path()).unwrap();
        
        // Read and decrypt
        let decrypted = writer.read_encrypted_parquet(temp_file.path()).unwrap();
        
        assert_eq!(parquet_data, decrypted.as_slice());
    }
}