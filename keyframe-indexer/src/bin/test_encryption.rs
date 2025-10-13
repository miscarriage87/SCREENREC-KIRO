use anyhow::Result;
use keyframe_indexer::encryption::{EncryptionManager, SecureParquetWriter};
use std::fs;
use tempfile::NamedTempFile;

#[tokio::main]
async fn main() -> Result<()> {
    println!("Testing Rust encryption implementation...");
    
    // Test basic encryption/decryption
    test_basic_encryption()?;
    
    // Test file encryption
    test_file_encryption()?;
    
    // Test secure Parquet writer
    test_secure_parquet_writer()?;
    
    // Test security properties
    test_security_properties()?;
    
    println!("All encryption tests passed!");
    Ok(())
}

fn test_basic_encryption() -> Result<()> {
    println!("Testing basic encryption/decryption...");
    
    let key = [0u8; 32]; // Test key
    let manager = EncryptionManager::with_key(&key);
    
    let test_data = b"Hello, World! This is test data for encryption.";
    
    // Test encryption/decryption roundtrip
    let encrypted = manager.encrypt(test_data)?;
    let decrypted = manager.decrypt(&encrypted)?;
    
    assert_eq!(test_data, decrypted.as_slice());
    assert_ne!(test_data, encrypted.as_slice());
    
    println!("✓ Basic encryption/decryption works");
    
    // Test that encryption produces different results each time
    let encrypted1 = manager.encrypt(test_data)?;
    let encrypted2 = manager.encrypt(test_data)?;
    
    assert_ne!(encrypted1, encrypted2);
    
    let decrypted1 = manager.decrypt(&encrypted1)?;
    let decrypted2 = manager.decrypt(&encrypted2)?;
    
    assert_eq!(decrypted1, decrypted2);
    assert_eq!(test_data, decrypted1.as_slice());
    
    println!("✓ Encryption produces unique results with random nonces");
    
    // Test empty data
    let empty_data = b"";
    let encrypted_empty = manager.encrypt(empty_data)?;
    let decrypted_empty = manager.decrypt(&encrypted_empty)?;
    
    assert_eq!(empty_data, decrypted_empty.as_slice());
    
    println!("✓ Empty data encryption works");
    
    // Test large data
    let large_data = vec![0x42u8; 1024 * 1024]; // 1MB
    let encrypted_large = manager.encrypt(&large_data)?;
    let decrypted_large = manager.decrypt(&encrypted_large)?;
    
    assert_eq!(large_data, decrypted_large);
    
    println!("✓ Large data encryption works");
    
    Ok(())
}

fn test_file_encryption() -> Result<()> {
    println!("Testing file encryption...");
    
    let key = [1u8; 32]; // Different test key
    let manager = EncryptionManager::with_key(&key);
    
    let test_data = b"Test file content for encryption";
    
    // Test in-place file encryption
    let temp_file = NamedTempFile::new()?;
    fs::write(temp_file.path(), test_data)?;
    
    // Encrypt file
    manager.encrypt_file(temp_file.path())?;
    
    // Verify file is encrypted
    let encrypted_content = fs::read(temp_file.path())?;
    assert_ne!(test_data, encrypted_content.as_slice());
    
    // Decrypt file
    manager.decrypt_file(temp_file.path())?;
    
    // Verify file is back to original
    let decrypted_content = fs::read(temp_file.path())?;
    assert_eq!(test_data, decrypted_content.as_slice());
    
    println!("✓ In-place file encryption works");
    
    // Test file encryption to new location
    let source_file = NamedTempFile::new()?;
    let dest_file = NamedTempFile::new()?;
    
    fs::write(source_file.path(), test_data)?;
    
    manager.encrypt_file_to(source_file.path(), dest_file.path())?;
    
    // Verify source is unchanged
    let source_content = fs::read(source_file.path())?;
    assert_eq!(test_data, source_content.as_slice());
    
    // Verify destination is encrypted
    let dest_content = fs::read(dest_file.path())?;
    assert_ne!(test_data, dest_content.as_slice());
    
    // Decrypt destination to verify
    let decrypted_dest = manager.decrypt(&dest_content)?;
    assert_eq!(test_data, decrypted_dest.as_slice());
    
    println!("✓ File encryption to new location works");
    
    Ok(())
}

fn test_secure_parquet_writer() -> Result<()> {
    println!("Testing secure Parquet writer...");
    
    let key = [2u8; 32]; // Another test key
    let manager = EncryptionManager::with_key(&key);
    let writer = SecureParquetWriter {
        encryption_manager: manager,
    };
    
    let mock_parquet_data = b"Mock Parquet file content with binary data";
    let temp_file = NamedTempFile::new()?;
    
    // Write encrypted Parquet data
    writer.write_encrypted_parquet(mock_parquet_data, temp_file.path())?;
    
    // Verify file exists and is encrypted
    let file_content = fs::read(temp_file.path())?;
    assert_ne!(mock_parquet_data, file_content.as_slice());
    
    // Read and decrypt
    let decrypted = writer.read_encrypted_parquet(temp_file.path())?;
    assert_eq!(mock_parquet_data, decrypted.as_slice());
    
    println!("✓ Secure Parquet writer works");
    
    // Test encrypting existing Parquet file
    let existing_file = NamedTempFile::new()?;
    fs::write(existing_file.path(), mock_parquet_data)?;
    
    writer.encrypt_existing_parquet(existing_file.path())?;
    
    let encrypted_content = fs::read(existing_file.path())?;
    assert_ne!(mock_parquet_data, encrypted_content.as_slice());
    
    writer.decrypt_existing_parquet(existing_file.path())?;
    
    let decrypted_content = fs::read(existing_file.path())?;
    assert_eq!(mock_parquet_data, decrypted_content.as_slice());
    
    println!("✓ Existing Parquet file encryption works");
    
    Ok(())
}

fn test_security_properties() -> Result<()> {
    println!("Testing security properties...");
    
    let key = [3u8; 32]; // Test key
    let manager = EncryptionManager::with_key(&key);
    
    let sensitive_data = b"password123secret";
    let encrypted = manager.encrypt(sensitive_data)?;
    
    // Verify plaintext doesn't appear in encrypted data
    let encrypted_string = String::from_utf8_lossy(&encrypted);
    assert!(!encrypted_string.contains("password123"));
    assert!(!encrypted_string.contains("secret"));
    
    // Check for plaintext pattern in raw bytes
    let mut found_pattern = false;
    if encrypted.len() >= sensitive_data.len() {
        for i in 0..=(encrypted.len() - sensitive_data.len()) {
            if &encrypted[i..i + sensitive_data.len()] == sensitive_data {
                found_pattern = true;
                break;
            }
        }
    }
    assert!(!found_pattern, "Plaintext pattern should not be found in encrypted data");
    
    println!("✓ Plaintext is not visible in encrypted data");
    
    // Test that different keys produce different results
    let key1 = [4u8; 32];
    let key2 = [5u8; 32];
    
    let manager1 = EncryptionManager::with_key(&key1);
    let manager2 = EncryptionManager::with_key(&key2);
    
    let test_data = b"Same data, different keys";
    let encrypted1 = manager1.encrypt(test_data)?;
    let encrypted2 = manager2.encrypt(test_data)?;
    
    assert_ne!(encrypted1, encrypted2);
    
    // Verify cross-decryption fails
    let decrypt_result = manager1.decrypt(&encrypted2);
    assert!(decrypt_result.is_err(), "Decryption with wrong key should fail");
    
    println!("✓ Different keys produce different results and cross-decryption fails");
    
    // Test entropy of encrypted data
    let large_repeated_data = vec![0x42u8; 1000]; // Repeated pattern
    let encrypted_repeated = manager.encrypt(&large_repeated_data)?;
    
    // Calculate basic entropy - count unique bytes
    let mut byte_counts = [0u32; 256];
    for &byte in &encrypted_repeated {
        byte_counts[byte as usize] += 1;
    }
    
    let unique_bytes = byte_counts.iter().filter(|&&count| count > 0).count();
    
    // Good encryption should produce diverse byte values
    assert!(unique_bytes > 50, "Encrypted data should have good byte diversity");
    
    println!("✓ Encrypted data has good entropy (unique bytes: {})", unique_bytes);
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_all_encryption_functionality() {
        let result = main().await;
        assert!(result.is_ok(), "Encryption tests should pass");
    }
}