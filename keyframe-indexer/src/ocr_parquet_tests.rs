use crate::ocr_data::{OCRResult, OCRBatch, BoundingBox};
use crate::ocr_parquet_writer::{OCRParquetWriter, OCRStatistics};
use chrono::{DateTime, Utc};
use tempfile::TempDir;
use std::collections::HashMap;

/// Create test OCR results for testing
fn create_test_ocr_results() -> Vec<OCRResult> {
    vec![
        OCRResult {
            frame_id: "frame_001".to_string(),
            roi: BoundingBox::new(10.0, 20.0, 200.0, 30.0),
            text: "Hello World".to_string(),
            language: "en-US".to_string(),
            confidence: 0.95,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
        OCRResult {
            frame_id: "frame_001".to_string(),
            roi: BoundingBox::new(10.0, 60.0, 150.0, 25.0),
            text: "Welcome to the application".to_string(),
            language: "en-US".to_string(),
            confidence: 0.87,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
        OCRResult {
            frame_id: "frame_002".to_string(),
            roi: BoundingBox::new(50.0, 100.0, 300.0, 40.0),
            text: "Bonjour le monde".to_string(),
            language: "fr-FR".to_string(),
            confidence: 0.92,
            processed_at: Utc::now(),
            processor: "tesseract".to_string(),
        },
        OCRResult {
            frame_id: "frame_003".to_string(),
            roi: BoundingBox::new(20.0, 150.0, 180.0, 35.0),
            text: "Low confidence text".to_string(),
            language: "en-US".to_string(),
            confidence: 0.45,
            processed_at: Utc::now(),
            processor: "tesseract".to_string(),
        },
        OCRResult {
            frame_id: "frame_004".to_string(),
            roi: BoundingBox::new(30.0, 200.0, 250.0, 28.0),
            text: "你好世界".to_string(),
            language: "zh-Hans".to_string(),
            confidence: 0.88,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
    ]
}

/// Create large dataset for performance testing
fn create_large_ocr_dataset(size: usize) -> Vec<OCRResult> {
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
            frame_id: format!("frame_{:06}", i / 10), // 10 results per frame
            roi: BoundingBox::new(
                (i % 100) as f32 * 10.0,
                (i % 50) as f32 * 20.0,
                100.0 + (i % 200) as f32,
                20.0 + (i % 30) as f32,
            ),
            text: format!("{} {}", sample_texts[i % sample_texts.len()], i),
            language: languages[i % languages.len()].to_string(),
            confidence: 0.5 + (i % 50) as f32 / 100.0, // 0.5 to 0.99
            processed_at: Utc::now(),
            processor: processors[i % processors.len()].to_string(),
        });
    }
    
    results
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio;
    
    #[tokio::test]
    async fn test_ocr_parquet_writer_creation() {
        let temp_dir = TempDir::new().unwrap();
        let writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap());
        assert!(writer.is_ok());
        
        let writer = writer.unwrap();
        assert_eq!(writer.get_schema().fields().len(), 7);
    }
    
    #[tokio::test]
    async fn test_write_and_flush_ocr_results() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        
        // Write OCR results
        writer.write_ocr_results(&test_results).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Verify file was created
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
        
        let file_path = entries[0].as_ref().unwrap().path();
        assert!(file_path.extension().unwrap() == "parquet");
        assert!(file_path.file_name().unwrap().to_str().unwrap().starts_with("ocr_"));
    }
    
    #[tokio::test]
    async fn test_write_ocr_batch() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        let batch = OCRBatch::new(test_results);
        
        // Write batch
        writer.write_ocr_batch(&batch).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Verify file was created
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
    }
    
    #[tokio::test]
    async fn test_batch_size_management() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        writer.set_batch_size(2); // Force frequent flushes
        
        let test_results = create_test_ocr_results();
        
        // Write results one by one
        for result in &test_results {
            writer.write_ocr_results(&[result.clone()]).await.unwrap();
        }
        
        // Should have created multiple files due to small batch size
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert!(entries.len() >= 2);
    }
    
    #[tokio::test]
    async fn test_query_by_frame_id() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        writer.write_ocr_results(&test_results).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Query by frame ID
        let results = writer.query_by_frame_id("frame_001").await.unwrap();
        assert_eq!(results.len(), 2); // Two results for frame_001
        
        for result in &results {
            assert_eq!(result.frame_id, "frame_001");
        }
    }
    
    #[tokio::test]
    async fn test_query_by_text() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        writer.write_ocr_results(&test_results).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Query by text content
        let results = writer.query_by_text("Hello").await.unwrap();
        assert!(!results.is_empty());
        
        // Should find results containing "Hello"
        let found_hello = results.iter().any(|r| r.text.contains("Hello"));
        assert!(found_hello);
    }
    
    #[tokio::test]
    async fn test_query_by_confidence() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        writer.write_ocr_results(&test_results).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Query by high confidence threshold
        let high_confidence_results = writer.query_by_confidence(0.8).await.unwrap();
        assert!(!high_confidence_results.is_empty());
        
        // All results should have confidence >= 0.8
        for result in &high_confidence_results {
            assert!(result.confidence >= 0.8);
        }
        
        // Query by very high confidence threshold
        let very_high_confidence_results = writer.query_by_confidence(0.95).await.unwrap();
        assert!(!very_high_confidence_results.is_empty());
        
        for result in &very_high_confidence_results {
            assert!(result.confidence >= 0.95);
        }
    }
    
    #[tokio::test]
    async fn test_query_by_language() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        writer.write_ocr_results(&test_results).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Query by English language
        let english_results = writer.query_by_language("en-US").await.unwrap();
        assert!(!english_results.is_empty());
        
        for result in &english_results {
            assert_eq!(result.language, "en-US");
        }
        
        // Query by French language
        let french_results = writer.query_by_language("fr-FR").await.unwrap();
        assert!(!french_results.is_empty());
        
        for result in &french_results {
            assert_eq!(result.language, "fr-FR");
        }
        
        // Query by Chinese language
        let chinese_results = writer.query_by_language("zh-Hans").await.unwrap();
        assert!(!chinese_results.is_empty());
        
        for result in &chinese_results {
            assert_eq!(result.language, "zh-Hans");
        }
    }
    
    #[tokio::test]
    async fn test_compression_settings() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        // Test different compression settings
        writer.set_compression(parquet::basic::Compression::GZIP(Default::default()));
        writer.set_dictionary_encoding(true);
        
        let test_results = create_test_ocr_results();
        writer.write_ocr_results(&test_results).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Verify file was created successfully with compression
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
        
        let file_path = entries[0].as_ref().unwrap().path();
        let metadata = std::fs::metadata(&file_path).unwrap();
        assert!(metadata.len() > 0);
    }
    
    #[tokio::test]
    async fn test_finalization() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        writer.write_ocr_results(&test_results).await.unwrap();
        
        // Finalize should flush remaining data
        writer.finalize().await.unwrap();
        
        // Verify file was created
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
    }
    
    #[tokio::test]
    async fn test_empty_queries() {
        let temp_dir = TempDir::new().unwrap();
        let writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        // Queries on empty dataset should return empty results
        let results = writer.query_by_frame_id("nonexistent").await.unwrap();
        assert!(results.is_empty());
        
        let results = writer.query_by_text("nonexistent").await.unwrap();
        assert!(results.is_empty());
        
        let results = writer.query_by_confidence(0.5).await.unwrap();
        assert!(results.is_empty());
        
        let results = writer.query_by_language("nonexistent").await.unwrap();
        assert!(results.is_empty());
    }
    
    #[tokio::test]
    async fn test_statistics() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_results = create_test_ocr_results();
        writer.write_ocr_results(&test_results).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Get statistics
        let stats = writer.get_statistics().await.unwrap();
        assert!(stats.total_size_bytes > 0);
    }
    
    #[tokio::test]
    async fn test_performance_large_dataset() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        writer.set_batch_size(10000); // Large batch for performance
        
        // Create large dataset
        let large_dataset = create_large_ocr_dataset(50000);
        
        let start_time = std::time::Instant::now();
        
        // Write large dataset
        writer.write_ocr_results(&large_dataset).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        let write_duration = start_time.elapsed();
        println!("Write performance: {} records in {:?}", large_dataset.len(), write_duration);
        
        // Verify file was created
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
        
        let file_path = entries[0].as_ref().unwrap().path();
        let metadata = std::fs::metadata(&file_path).unwrap();
        println!("File size: {} bytes", metadata.len());
        
        // Test query performance
        let query_start = std::time::Instant::now();
        let results = writer.query_by_confidence(0.8).await.unwrap();
        let query_duration = query_start.elapsed();
        
        println!("Query performance: {} results in {:?}", results.len(), query_duration);
        assert!(!results.is_empty());
    }
    
    #[tokio::test]
    async fn test_concurrent_writes() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        writer.set_batch_size(1000);
        
        let test_results1 = create_test_ocr_results();
        let test_results2 = create_large_ocr_dataset(500);
        
        // Write multiple batches
        writer.write_ocr_results(&test_results1).await.unwrap();
        writer.write_ocr_results(&test_results2).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Verify data integrity
        let all_results = writer.query_by_confidence(0.0).await.unwrap();
        assert!(all_results.len() >= test_results1.len());
    }
    
    #[tokio::test]
    async fn test_schema_validation() {
        let temp_dir = TempDir::new().unwrap();
        let writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let schema = writer.get_schema();
        
        // Verify schema structure matches design specification
        assert_eq!(schema.fields().len(), 7);
        
        let field_names: Vec<&str> = schema.fields().iter().map(|f| f.name().as_str()).collect();
        assert!(field_names.contains(&"frame_id"));
        assert!(field_names.contains(&"roi"));
        assert!(field_names.contains(&"text"));
        assert!(field_names.contains(&"language"));
        assert!(field_names.contains(&"confidence"));
        assert!(field_names.contains(&"processed_at"));
        assert!(field_names.contains(&"processor"));
        
        // Verify data types
        let frame_id_field = schema.field_with_name("frame_id").unwrap();
        assert_eq!(frame_id_field.data_type(), &arrow::datatypes::DataType::Utf8);
        
        let confidence_field = schema.field_with_name("confidence").unwrap();
        assert_eq!(confidence_field.data_type(), &arrow::datatypes::DataType::Float32);
        
        let roi_field = schema.field_with_name("roi").unwrap();
        assert!(matches!(roi_field.data_type(), arrow::datatypes::DataType::Struct(_)));
    }
}

/// Performance benchmarks for OCR Parquet storage
#[cfg(test)]
mod benchmarks {
    use super::*;
    use std::time::Instant;
    
    #[tokio::test]
    async fn benchmark_write_performance() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let dataset_sizes = vec![1000, 5000, 10000, 25000];
        
        for size in dataset_sizes {
            let dataset = create_large_ocr_dataset(size);
            
            let start = Instant::now();
            writer.write_ocr_results(&dataset).await.unwrap();
            writer.flush_batch().await.unwrap();
            let duration = start.elapsed();
            
            let throughput = size as f64 / duration.as_secs_f64();
            println!("Write throughput for {} records: {:.2} records/sec", size, throughput);
            
            // Performance requirement: Should handle at least 1000 records/sec
            assert!(throughput > 1000.0, "Write throughput too low: {:.2} records/sec", throughput);
        }
    }
    
    #[tokio::test]
    async fn benchmark_query_performance() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = OCRParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        // Create large dataset for querying
        let large_dataset = create_large_ocr_dataset(100000);
        writer.write_ocr_results(&large_dataset).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Benchmark different query types
        let start = Instant::now();
        let frame_results = writer.query_by_frame_id("frame_000001").await.unwrap();
        let frame_query_duration = start.elapsed();
        println!("Frame ID query: {} results in {:?}", frame_results.len(), frame_query_duration);
        
        let start = Instant::now();
        let confidence_results = writer.query_by_confidence(0.9).await.unwrap();
        let confidence_query_duration = start.elapsed();
        println!("Confidence query: {} results in {:?}", confidence_results.len(), confidence_query_duration);
        
        let start = Instant::now();
        let text_results = writer.query_by_text("Sample").await.unwrap();
        let text_query_duration = start.elapsed();
        println!("Text search query: {} results in {:?}", text_results.len(), text_query_duration);
        
        // Performance requirements: Queries should complete within reasonable time
        assert!(frame_query_duration.as_millis() < 1000, "Frame query too slow");
        assert!(confidence_query_duration.as_millis() < 2000, "Confidence query too slow");
        assert!(text_query_duration.as_millis() < 5000, "Text search too slow");
    }
    
    #[tokio::test]
    async fn benchmark_compression_efficiency() {
        let temp_dir = TempDir::new().unwrap();
        
        let dataset = create_large_ocr_dataset(10000);
        let compressions = vec![
            parquet::basic::Compression::UNCOMPRESSED,
            parquet::basic::Compression::SNAPPY,
            parquet::basic::Compression::GZIP(Default::default()),
            parquet::basic::Compression::LZ4,
        ];
        
        for compression in compressions {
            let compression_dir = temp_dir.path().join(format!("{:?}", compression));
            std::fs::create_dir_all(&compression_dir).unwrap();
            
            let mut writer = OCRParquetWriter::new(compression_dir.to_str().unwrap()).unwrap();
            writer.set_compression(compression);
            
            let start = Instant::now();
            writer.write_ocr_results(&dataset).await.unwrap();
            writer.flush_batch().await.unwrap();
            let write_duration = start.elapsed();
            
            // Get file size
            let entries: Vec<_> = std::fs::read_dir(&compression_dir).unwrap().collect();
            let file_size = if !entries.is_empty() {
                std::fs::metadata(entries[0].as_ref().unwrap().path()).unwrap().len()
            } else {
                0
            };
            
            println!("Compression {:?}: {} bytes in {:?}", compression, file_size, write_duration);
        }
    }
}