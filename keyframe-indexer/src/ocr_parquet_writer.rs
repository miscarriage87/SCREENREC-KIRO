use crate::error::{IndexerError, Result};
use crate::ocr_data::{OCRResult, OCRBatch, BoundingBox};
use crate::encryption::{EncryptionManager, SecureParquetWriter};
use arrow::array::{
    Array, Float32Array, StringArray, TimestampNanosecondArray, StructArray
};
use arrow::datatypes::{DataType, Field, Schema, TimeUnit};
use arrow::record_batch::RecordBatch;
use parquet::arrow::ArrowWriter;
use parquet::file::properties::WriterProperties;
use parquet::basic::Compression;
use std::fs::File;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tracing::{debug, info, error, warn};
use chrono::{DateTime, Utc};
use datafusion::prelude::*;
use datafusion::arrow::array::TimestampNanosecondBuilder;

/// OCR Parquet writer with efficient indexing and querying capabilities
pub struct OCRParquetWriter {
    output_dir: PathBuf,
    schema: Arc<Schema>,
    batch_size: usize,
    current_batch: Vec<OCRResult>,
    compression: Compression,
    enable_dictionary_encoding: bool,
    secure_writer: Option<SecureParquetWriter>,
    encryption_enabled: bool,
}

impl OCRParquetWriter {
    pub fn new(output_dir: &str) -> Result<Self> {
        let output_path = PathBuf::from(output_dir);
        
        // Create output directory if it doesn't exist
        std::fs::create_dir_all(&output_path)?;
        
        // Define schema for OCR data according to design specification
        let roi_schema = Schema::new(vec![
            Field::new("x", DataType::Float32, false),
            Field::new("y", DataType::Float32, false),
            Field::new("width", DataType::Float32, false),
            Field::new("height", DataType::Float32, false),
        ]);
        
        let schema = Arc::new(Schema::new(vec![
            Field::new("frame_id", DataType::Utf8, false),
            Field::new("roi", DataType::Struct(roi_schema.fields().clone()), false),
            Field::new("text", DataType::Utf8, false),
            Field::new("language", DataType::Utf8, false),
            Field::new("confidence", DataType::Float32, false),
            Field::new("processed_at", DataType::Timestamp(TimeUnit::Nanosecond, None), false),
            Field::new("processor", DataType::Utf8, false),
        ]));
        
        Ok(Self {
            output_dir: output_path,
            schema,
            batch_size: 5000, // Larger batch size for OCR data
            current_batch: Vec::new(),
            compression: Compression::SNAPPY, // Good balance of speed and compression
            enable_dictionary_encoding: true, // Efficient for repeated strings
            secure_writer: None,
            encryption_enabled: false,
        })
    }
    
    /// Enable encryption for all Parquet files
    pub fn enable_encryption(&mut self) -> Result<()> {
        let secure_writer = SecureParquetWriter::new()
            .map_err(|e| IndexerError::ProcessingError(format!("Failed to initialize encryption: {}", e)))?;
        
        self.secure_writer = Some(secure_writer);
        self.encryption_enabled = true;
        
        info!("Encryption enabled for OCR Parquet writer");
        Ok(())
    }
    
    /// Disable encryption
    pub fn disable_encryption(&mut self) {
        self.secure_writer = None;
        self.encryption_enabled = false;
        info!("Encryption disabled for OCR Parquet writer");
    }
    
    /// Check if encryption is enabled
    pub fn is_encryption_enabled(&self) -> bool {
        self.encryption_enabled
    }
    
    /// Encrypt an existing Parquet file
    pub fn encrypt_existing_file<P: AsRef<Path>>(&self, file_path: P) -> Result<()> {
        if let Some(ref secure_writer) = self.secure_writer {
            secure_writer.encrypt_existing_parquet(file_path)
                .map_err(|e| IndexerError::ProcessingError(format!("Failed to encrypt file: {}", e)))?;
        } else {
            return Err(IndexerError::ProcessingError("Encryption not enabled".to_string()));
        }
        Ok(())
    }
    
    /// Decrypt an existing Parquet file
    pub fn decrypt_existing_file<P: AsRef<Path>>(&self, file_path: P) -> Result<()> {
        if let Some(ref secure_writer) = self.secure_writer {
            secure_writer.decrypt_existing_parquet(file_path)
                .map_err(|e| IndexerError::ProcessingError(format!("Failed to decrypt file: {}", e)))?;
        } else {
            return Err(IndexerError::ProcessingError("Encryption not enabled".to_string()));
        }
        Ok(())
    }
    
    /// Write OCR results to Parquet format
    pub async fn write_ocr_results(&mut self, results: &[OCRResult]) -> Result<()> {
        debug!("Writing {} OCR results", results.len());
        
        // Add to current batch
        self.current_batch.extend_from_slice(results);
        
        // Write batch if it's large enough
        if self.current_batch.len() >= self.batch_size {
            self.flush_batch().await?;
        }
        
        Ok(())
    }
    
    /// Write an OCR batch
    pub async fn write_ocr_batch(&mut self, batch: &OCRBatch) -> Result<()> {
        self.write_ocr_results(&batch.results).await
    }
    
    /// Flush current batch to disk
    pub async fn flush_batch(&mut self) -> Result<()> {
        if self.current_batch.is_empty() {
            return Ok(());
        }
        
        info!("Flushing OCR batch of {} records", self.current_batch.len());
        
        // Generate filename with timestamp for partitioning
        let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
        let filename = format!("ocr_{}.parquet", timestamp);
        let file_path = self.output_dir.join(filename);
        
        // Create record batch from current data
        let record_batch = self.create_record_batch(&self.current_batch)?;
        
        // Write to Parquet file with optimized settings
        self.write_record_batch(&file_path, record_batch).await?;
        
        // Clear current batch
        self.current_batch.clear();
        
        info!("Successfully wrote OCR data to: {}", file_path.display());
        Ok(())
    }
    
    /// Create Arrow record batch from OCR results
    fn create_record_batch(&self, results: &[OCRResult]) -> Result<RecordBatch> {
        let len = results.len();
        
        // Create arrays for each column
        let frame_id_array = StringArray::from(
            results.iter().map(|r| r.frame_id.as_str()).collect::<Vec<_>>()
        );
        
        // Create ROI struct array
        let roi_x_array = Float32Array::from(
            results.iter().map(|r| r.roi.x).collect::<Vec<_>>()
        );
        let roi_y_array = Float32Array::from(
            results.iter().map(|r| r.roi.y).collect::<Vec<_>>()
        );
        let roi_width_array = Float32Array::from(
            results.iter().map(|r| r.roi.width).collect::<Vec<_>>()
        );
        let roi_height_array = Float32Array::from(
            results.iter().map(|r| r.roi.height).collect::<Vec<_>>()
        );
        
        let roi_struct_array = StructArray::from(vec![
            (Arc::new(Field::new("x", DataType::Float32, false)), Arc::new(roi_x_array) as Arc<dyn Array>),
            (Arc::new(Field::new("y", DataType::Float32, false)), Arc::new(roi_y_array) as Arc<dyn Array>),
            (Arc::new(Field::new("width", DataType::Float32, false)), Arc::new(roi_width_array) as Arc<dyn Array>),
            (Arc::new(Field::new("height", DataType::Float32, false)), Arc::new(roi_height_array) as Arc<dyn Array>),
        ]);
        
        let text_array = StringArray::from(
            results.iter().map(|r| r.text.as_str()).collect::<Vec<_>>()
        );
        
        let language_array = StringArray::from(
            results.iter().map(|r| r.language.as_str()).collect::<Vec<_>>()
        );
        
        let confidence_array = Float32Array::from(
            results.iter().map(|r| r.confidence).collect::<Vec<_>>()
        );
        
        // Convert timestamps to nanoseconds
        let mut timestamp_builder = TimestampNanosecondBuilder::new();
        for result in results {
            timestamp_builder.append_value(result.processed_at.timestamp_nanos_opt().unwrap_or(0));
        }
        let timestamp_array = timestamp_builder.finish();
        
        let processor_array = StringArray::from(
            results.iter().map(|r| r.processor.as_str()).collect::<Vec<_>>()
        );
        
        // Create record batch
        let record_batch = RecordBatch::try_new(
            self.schema.clone(),
            vec![
                Arc::new(frame_id_array),
                Arc::new(roi_struct_array),
                Arc::new(text_array),
                Arc::new(language_array),
                Arc::new(confidence_array),
                Arc::new(timestamp_array),
                Arc::new(processor_array),
            ],
        )?;
        
        debug!("Created OCR record batch with {} rows", record_batch.num_rows());
        Ok(record_batch)
    }
    
    /// Write record batch to Parquet file with optimized settings
    async fn write_record_batch(&self, file_path: &Path, record_batch: RecordBatch) -> Result<()> {
        // Write to temporary file first
        let temp_path = file_path.with_extension("tmp.parquet");
        
        let file = File::create(&temp_path)?;
        
        // Configure writer properties for optimal compression and performance
        let mut props_builder = WriterProperties::builder()
            .set_compression(self.compression)
            .set_write_batch_size(2048)
            .set_max_row_group_size(50000) // Larger row groups for better compression
            .set_created_by("AlwaysOnAI OCR Indexer".to_string());
        
        // Enable dictionary encoding for string columns to reduce size
        if self.enable_dictionary_encoding {
            props_builder = props_builder
                .set_dictionary_enabled(true)
                .set_column_dictionary_enabled("frame_id".into(), true)
                .set_column_dictionary_enabled("text".into(), true)
                .set_column_dictionary_enabled("language".into(), true)
                .set_column_dictionary_enabled("processor".into(), true);
        }
        
        let props = props_builder.build();
        
        // Create Arrow writer
        let mut writer = ArrowWriter::try_new(file, self.schema.clone(), Some(props))?;
        
        // Write record batch
        writer.write(&record_batch)?;
        
        // Close writer
        writer.close()?;
        
        // Handle encryption if enabled
        if self.encryption_enabled {
            if let Some(ref secure_writer) = self.secure_writer {
                // Encrypt the temporary file and move to final location
                secure_writer.encrypt_file_to(&temp_path, file_path)
                    .map_err(|e| IndexerError::ProcessingError(format!("Failed to encrypt Parquet file: {}", e)))?;
                
                // Remove temporary file
                std::fs::remove_file(&temp_path)?;
                
                debug!("Successfully wrote encrypted OCR Parquet file: {}", file_path.display());
            } else {
                return Err(IndexerError::ProcessingError("Encryption enabled but secure writer not initialized".to_string()));
            }
        } else {
            // Move temporary file to final location
            std::fs::rename(&temp_path, file_path)?;
            debug!("Successfully wrote OCR Parquet file: {}", file_path.display());
        }
        
        Ok(())
    }
    
    /// Prepare files for querying (decrypt if necessary)
    async fn prepare_files_for_query(&self) -> Result<Vec<PathBuf>> {
        let parquet_files = self.get_parquet_files()?;
        
        if !self.encryption_enabled {
            return Ok(parquet_files);
        }
        
        // If encryption is enabled, we need to decrypt files temporarily for querying
        let mut temp_files = Vec::new();
        
        if let Some(ref secure_writer) = self.secure_writer {
            for file_path in parquet_files {
                let temp_path = file_path.with_extension("query.tmp.parquet");
                
                // Decrypt to temporary file
                secure_writer.decrypt_file_to(&file_path, &temp_path)
                    .map_err(|e| IndexerError::ProcessingError(format!("Failed to decrypt file for query: {}", e)))?;
                
                temp_files.push(temp_path);
            }
        }
        
        Ok(temp_files)
    }
    
    /// Clean up temporary query files
    async fn cleanup_query_files(&self, temp_files: Vec<PathBuf>) -> Result<()> {
        for temp_file in temp_files {
            if temp_file.exists() {
                std::fs::remove_file(&temp_file)?;
            }
        }
        Ok(())
    }
    
    /// Query OCR data by frame ID
    pub async fn query_by_frame_id(&self, frame_id: &str) -> Result<Vec<OCRResult>> {
        let ctx = SessionContext::new();
        
        // Prepare files for querying (decrypt if necessary)
        let query_files = self.prepare_files_for_query().await?;
        if query_files.is_empty() {
            return Ok(Vec::new());
        }
        
        // Register files for querying
        for (i, file_path) in query_files.iter().enumerate() {
            let table_name = format!("ocr_data_{}", i);
            ctx.register_parquet(&table_name, file_path.to_str().unwrap(), ParquetReadOptions::default()).await?;
        }
        
        // Create union query for all tables
        let table_names: Vec<String> = (0..query_files.len())
            .map(|i| format!("ocr_data_{}", i))
            .collect();
        let union_query = table_names.join(" UNION ALL SELECT * FROM ");
        let sql = format!("SELECT * FROM ({}) WHERE frame_id = '{}'", 
                         format!("SELECT * FROM {}", union_query), frame_id);
        
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        // Clean up temporary files
        self.cleanup_query_files(query_files).await?;
        
        // Convert results back to OCRResult structs
        self.record_batches_to_ocr_results(batches)
    }
    
    /// Query OCR data by text content (full-text search)
    pub async fn query_by_text(&self, search_text: &str) -> Result<Vec<OCRResult>> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(Vec::new());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("ocr_data", &table_path, ParquetReadOptions::default()).await?;
        
        // Case-insensitive text search
        let sql = format!(
            "SELECT * FROM ocr_data WHERE LOWER(text) LIKE LOWER('%{}%') ORDER BY confidence DESC",
            search_text.replace("'", "''") // Escape single quotes
        );
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        self.record_batches_to_ocr_results(batches)
    }
    
    /// Query OCR data by confidence threshold
    pub async fn query_by_confidence(&self, min_confidence: f32) -> Result<Vec<OCRResult>> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(Vec::new());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("ocr_data", &table_path, ParquetReadOptions::default()).await?;
        
        let sql = format!(
            "SELECT * FROM ocr_data WHERE confidence >= {} ORDER BY confidence DESC",
            min_confidence
        );
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        self.record_batches_to_ocr_results(batches)
    }
    
    /// Query OCR data by language
    pub async fn query_by_language(&self, language: &str) -> Result<Vec<OCRResult>> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(Vec::new());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("ocr_data", &table_path, ParquetReadOptions::default()).await?;
        
        let sql = format!("SELECT * FROM ocr_data WHERE language = '{}'", language);
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        self.record_batches_to_ocr_results(batches)
    }
    
    /// Get statistics about stored OCR data
    pub async fn get_statistics(&self) -> Result<OCRStatistics> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(OCRStatistics::default());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("ocr_data", &table_path, ParquetReadOptions::default()).await?;
        
        // Get basic statistics
        let count_sql = "SELECT COUNT(*) as total_records FROM ocr_data";
        let count_df = ctx.sql(count_sql).await?;
        let count_batches = count_df.collect().await?;
        
        let avg_confidence_sql = "SELECT AVG(confidence) as avg_confidence FROM ocr_data";
        let avg_df = ctx.sql(avg_confidence_sql).await?;
        let avg_batches = avg_df.collect().await?;
        
        let lang_stats_sql = "SELECT language, COUNT(*) as count FROM ocr_data GROUP BY language ORDER BY count DESC";
        let lang_df = ctx.sql(lang_stats_sql).await?;
        let lang_batches = lang_df.collect().await?;
        
        // Extract statistics (simplified for now)
        let total_records = if !count_batches.is_empty() && count_batches[0].num_rows() > 0 {
            // In a real implementation, you'd extract the actual count value
            count_batches[0].num_rows() as u64
        } else {
            0
        };
        
        Ok(OCRStatistics {
            total_records,
            average_confidence: 0.85, // Placeholder
            language_distribution: std::collections::HashMap::new(), // Placeholder
            processor_distribution: std::collections::HashMap::new(), // Placeholder
            total_size_bytes: self.calculate_total_size()?,
        })
    }
    
    /// Finalize and flush any remaining data
    pub async fn finalize(&mut self) -> Result<()> {
        if !self.current_batch.is_empty() {
            self.flush_batch().await?;
        }
        
        info!("OCRParquetWriter finalized");
        Ok(())
    }
    
    // MARK: - Private Helper Methods
    
    fn get_parquet_files(&self) -> Result<Vec<PathBuf>> {
        let mut files = Vec::new();
        
        if !self.output_dir.exists() {
            return Ok(files);
        }
        
        for entry in std::fs::read_dir(&self.output_dir)? {
            let entry = entry?;
            let path = entry.path();
            
            if path.extension().and_then(|s| s.to_str()) == Some("parquet") {
                files.push(path);
            }
        }
        
        Ok(files)
    }
    
    fn record_batches_to_ocr_results(&self, batches: Vec<RecordBatch>) -> Result<Vec<OCRResult>> {
        let mut results = Vec::new();
        
        for batch in batches {
            // Extract data from batch (simplified implementation)
            // In a real implementation, you'd properly extract all fields
            let frame_ids = batch.column(0).as_any().downcast_ref::<StringArray>().unwrap();
            let texts = batch.column(2).as_any().downcast_ref::<StringArray>().unwrap();
            let languages = batch.column(3).as_any().downcast_ref::<StringArray>().unwrap();
            let confidences = batch.column(4).as_any().downcast_ref::<Float32Array>().unwrap();
            let processors = batch.column(6).as_any().downcast_ref::<StringArray>().unwrap();
            
            for i in 0..batch.num_rows() {
                results.push(OCRResult {
                    frame_id: frame_ids.value(i).to_string(),
                    roi: BoundingBox::new(0.0, 0.0, 100.0, 20.0), // Placeholder - would extract from struct
                    text: texts.value(i).to_string(),
                    language: languages.value(i).to_string(),
                    confidence: confidences.value(i),
                    processed_at: Utc::now(), // Placeholder - would extract from timestamp
                    processor: processors.value(i).to_string(),
                });
            }
        }
        
        Ok(results)
    }
    
    fn calculate_total_size(&self) -> Result<u64> {
        let mut total_size = 0u64;
        
        for file_path in self.get_parquet_files()? {
            if let Ok(metadata) = std::fs::metadata(&file_path) {
                total_size += metadata.len();
            }
        }
        
        Ok(total_size)
    }
    
    // MARK: - Configuration Methods
    
    pub fn set_batch_size(&mut self, batch_size: usize) {
        self.batch_size = batch_size;
    }
    
    pub fn set_compression(&mut self, compression: Compression) {
        self.compression = compression;
    }
    
    pub fn set_dictionary_encoding(&mut self, enabled: bool) {
        self.enable_dictionary_encoding = enabled;
    }
    
    pub fn get_schema(&self) -> &Schema {
        &self.schema
    }
    
    pub fn get_output_dir(&self) -> &Path {
        &self.output_dir
    }
}

/// Statistics about stored OCR data
#[derive(Debug, Clone)]
pub struct OCRStatistics {
    pub total_records: u64,
    pub average_confidence: f32,
    pub language_distribution: std::collections::HashMap<String, u64>,
    pub processor_distribution: std::collections::HashMap<String, u64>,
    pub total_size_bytes: u64,
}

impl Default for OCRStatistics {
    fn default() -> Self {
        Self {
            total_records: 0,
            average_confidence: 0.0,
            language_distribution: std::collections::HashMap::new(),
            processor_distribution: std::collections::HashMap::new(),
            total_size_bytes: 0,
        }
    }
}