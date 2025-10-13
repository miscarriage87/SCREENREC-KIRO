use crate::ocr_data::{OCRResult, OCRBatch, BoundingBox};
use crate::ocr_parquet_writer::OCRParquetWriter;
use chrono::Utc;
use std::fs;

/// Integration test demonstrating OCR Parquet storage functionality
pub async fn run_integration_test() -> Result<(), Box<dyn std::error::Error>> {
    println!("🧪 Running OCR Parquet Integration Test");
    println!("=======================================");
    
    // Create temporary directory
    let temp_dir = std::env::temp_dir().join("ocr_integration_test");
    fs::create_dir_all(&temp_dir)?;
    let storage_path = temp_dir.to_str().unwrap();
    println!("📁 Storage directory: {}", storage_path);
    
    // Initialize OCR Parquet writer
    let mut writer = OCRParquetWriter::new(storage_path)?;
    println!("✅ OCR Parquet writer initialized");
    
    // Create test OCR data
    let test_results = create_test_data();
    println!("📝 Created {} test OCR results", test_results.len());
    
    // Write OCR results
    let write_start = std::time::Instant::now();
    writer.write_ocr_results(&test_results).await?;
    writer.flush_batch().await?;
    let write_duration = write_start.elapsed();
    println!("💾 Wrote OCR results in {:?}", write_duration);
    
    // Create and write batch
    let batch_data = create_batch_data(100);
    let batch = OCRBatch::new(batch_data);
    
    let batch_start = std::time::Instant::now();
    writer.write_ocr_batch(&batch).await?;
    writer.flush_batch().await?;
    let batch_duration = batch_start.elapsed();
    println!("📦 Wrote OCR batch in {:?}", batch_duration);
    
    // Test queries
    println!("\n🔍 Testing queries...");
    
    // Query by frame ID
    let frame_results = writer.query_by_frame_id("test_frame_001").await?;
    println!("🎯 Frame query: {} results", frame_results.len());
    
    // Query by text
    let text_results = writer.query_by_text("Hello").await?;
    println!("📝 Text search: {} results", text_results.len());
    
    // Query by confidence
    let confidence_results = writer.query_by_confidence(0.8).await?;
    println!("📊 High confidence: {} results", confidence_results.len());
    
    // Query by language
    let english_results = writer.query_by_language("en-US").await?;
    println!("🌐 English results: {} results", english_results.len());
    
    // Get statistics
    let stats = writer.get_statistics().await?;
    println!("\n📈 Storage Statistics:");
    println!("   Total records: {}", stats.total_records);
    println!("   Average confidence: {:.2}", stats.average_confidence);
    println!("   Total size: {} bytes", stats.total_size_bytes);
    
    println!("\n✅ Integration test completed successfully!");
    Ok(())
}

fn create_test_data() -> Vec<OCRResult> {
    vec![
        OCRResult {
            frame_id: "test_frame_001".to_string(),
            roi: BoundingBox::new(10.0, 20.0, 200.0, 30.0),
            text: "Hello World".to_string(),
            language: "en-US".to_string(),
            confidence: 0.95,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
        OCRResult {
            frame_id: "test_frame_001".to_string(),
            roi: BoundingBox::new(10.0, 60.0, 150.0, 25.0),
            text: "Welcome to the application".to_string(),
            language: "en-US".to_string(),
            confidence: 0.87,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
        OCRResult {
            frame_id: "test_frame_002".to_string(),
            roi: BoundingBox::new(50.0, 100.0, 300.0, 40.0),
            text: "Bonjour le monde".to_string(),
            language: "fr-FR".to_string(),
            confidence: 0.92,
            processed_at: Utc::now(),
            processor: "tesseract".to_string(),
        },
    ]
}

fn create_batch_data(size: usize) -> Vec<OCRResult> {
    let mut results = Vec::with_capacity(size);
    let sample_texts = vec![
        "Sample text for testing",
        "Another test string", 
        "Performance evaluation text",
        "Large dataset entry",
        "Benchmark data point",
    ];
    
    let languages = vec!["en-US", "fr-FR", "de-DE", "es-ES", "zh-Hans"];
    let processors = vec!["vision", "tesseract"];
    
    for i in 0..size {
        results.push(OCRResult {
            frame_id: format!("batch_frame_{:03}", i / 5), // 5 results per frame
            roi: BoundingBox::new(
                (i % 100) as f32 * 5.0,
                (i % 50) as f32 * 15.0,
                80.0 + (i % 150) as f32,
                15.0 + (i % 25) as f32,
            ),
            text: format!("{} {}", sample_texts[i % sample_texts.len()], i),
            language: languages[i % languages.len()].to_string(),
            confidence: 0.6 + (i % 40) as f32 / 100.0, // 0.6 to 0.99
            processed_at: Utc::now(),
            processor: processors[i % processors.len()].to_string(),
        });
    }
    
    results
}