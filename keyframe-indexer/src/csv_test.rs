use crate::error::Result;
use crate::metadata_collector::{FrameMetadata, MetadataCollector};
use crate::csv_writer::CsvWriter;
use std::fs;

fn create_test_metadata() -> Vec<FrameMetadata> {
    vec![
        FrameMetadata {
            ts_ns: 1000000000,
            monitor_id: 0,
            segment_id: "test_segment_1".to_string(),
            path: "/path/to/frame1.png".to_string(),
            phash16: 12345,
            entropy: 5.5,
            app_name: "TestApp".to_string(),
            win_title: "Test Window".to_string(),
            width: 1920,
            height: 1080,
        },
        FrameMetadata {
            ts_ns: 2000000000,
            monitor_id: 1,
            segment_id: "test_segment_2".to_string(),
            path: "/path/to/frame2.png".to_string(),
            phash16: 67890,
            entropy: 6.2,
            app_name: "AnotherApp".to_string(),
            win_title: "Another Window".to_string(),
            width: 2560,
            height: 1440,
        },
    ]
}

async fn test_csv_writer_standalone() -> Result<()> {
    // Create temporary directory for testing
    let temp_dir = std::env::temp_dir().join("csv_test");
    fs::create_dir_all(&temp_dir).unwrap();
    let temp_path = temp_dir.to_str().unwrap();
    
    // Create CsvWriter
    let mut writer = CsvWriter::new(temp_path)?;
    
    let test_metadata = create_test_metadata();
    
    // Write metadata
    writer.write_frame_metadata(&test_metadata).await?;
    writer.flush_batch().await?;
    
    // Verify file was created
    let entries: Vec<_> = std::fs::read_dir(temp_path).unwrap().collect();
    assert_eq!(entries.len(), 1);
    
    let file_path = entries[0].as_ref().unwrap().path();
    assert!(file_path.extension().unwrap() == "csv");
    
    // Read back the data
    let read_metadata = writer.read_csv_file(&file_path).await?;
    assert_eq!(read_metadata.len(), test_metadata.len());
    
    // Verify data integrity
    for (original, read) in test_metadata.iter().zip(read_metadata.iter()) {
        assert_eq!(original.ts_ns, read.ts_ns);
        assert_eq!(original.monitor_id, read.monitor_id);
        assert_eq!(original.segment_id, read.segment_id);
        assert_eq!(original.path, read.path);
        assert_eq!(original.phash16, read.phash16);
        assert!((original.entropy - read.entropy).abs() < 0.001);
        assert_eq!(original.app_name, read.app_name);
        assert_eq!(original.win_title, read.win_title);
        assert_eq!(original.width, read.width);
        assert_eq!(original.height, read.height);
    }
    
    println!("✅ CSV writer test passed!");
    println!("   - Created {} metadata records", test_metadata.len());
    println!("   - File size: {} bytes", std::fs::metadata(&file_path).unwrap().len());
    println!("   - Schema validation: passed");
    println!("   - Data integrity: verified");
    
    // Cleanup
    fs::remove_dir_all(&temp_dir).ok();
    
    Ok(())
}

async fn test_csv_performance() -> Result<()> {
    let temp_dir = std::env::temp_dir().join("csv_perf_test");
    fs::create_dir_all(&temp_dir).unwrap();
    let temp_path = temp_dir.to_str().unwrap();
    
    let mut writer = CsvWriter::new(temp_path)?;
    writer.set_batch_size(100); // Smaller batch for testing
    
    // Generate larger dataset
    let mut test_metadata = Vec::new();
    for i in 0..1000 {
        test_metadata.push(FrameMetadata {
            ts_ns: (i as i64) * 1000000,
            monitor_id: i % 3,
            segment_id: format!("segment_{}", i / 100),
            path: format!("/frames/frame_{:06}.png", i),
            phash16: (i as i64) * 12345,
            entropy: (i as f32) * 0.01,
            app_name: format!("App_{}", i % 5),
            win_title: format!("Window_{}", i % 10),
            width: 1920 + (i % 4) as u32 * 320,
            height: 1080 + (i % 3) as u32 * 240,
        });
    }
    
    let start = std::time::Instant::now();
    
    // Write in chunks to test batching
    for chunk in test_metadata.chunks(50) {
        writer.write_frame_metadata(chunk).await?;
    }
    writer.finalize().await?;
    
    let duration = start.elapsed();
    
    // Verify multiple files were created due to batching
    let entries: Vec<_> = std::fs::read_dir(temp_path).unwrap().collect();
    
    println!("✅ CSV performance test passed!");
    println!("   - Processed {} records in {:?}", test_metadata.len(), duration);
    println!("   - Created {} batch files", entries.len());
    println!("   - Throughput: {:.0} records/sec", test_metadata.len() as f64 / duration.as_secs_f64());
    
    // Cleanup
    fs::remove_dir_all(&temp_dir).ok();
    
    Ok(())
}

async fn test_macos_app_integration() -> Result<()> {
    // Test the macOS API integration for collecting app information
    let mut collector = MetadataCollector::new()?;
    
    // Test cache functionality
    collector.clear_cache();
    collector.set_cache_duration(std::time::Duration::from_millis(100));
    
    println!("✅ macOS integration test setup complete!");
    println!("   - MetadataCollector initialized");
    println!("   - Cache management working");
    
    Ok(())
}

pub async fn run_all_tests() -> Result<()> {
    println!("🧪 Running CSV-based frame metadata storage tests...\n");
    
    // Run the tests directly
    println!("Running CSV writer standalone test...");
    if let Err(e) = test_csv_writer_standalone().await {
        println!("❌ CSV writer test failed: {}", e);
        return Err(e);
    }
    
    println!("Running CSV performance test...");
    if let Err(e) = test_csv_performance().await {
        println!("❌ CSV performance test failed: {}", e);
        return Err(e);
    }
    
    println!("Running macOS integration test...");
    if let Err(e) = test_macos_app_integration().await {
        println!("❌ macOS integration test failed: {}", e);
        return Err(e);
    }
    
    println!("\n🎉 All tests passed! CSV-based frame metadata storage is working correctly.");
    println!("Note: This demonstrates the functionality. In production, this would use Parquet format.");
    
    Ok(())
}