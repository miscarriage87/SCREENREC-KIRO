use crate::error::{IndexerError, Result};
use crate::event_detector::{DetectedEvent, EventType};
use arrow::array::{
    Array, Float32Array, StringArray, TimestampNanosecondArray, ListArray, 
    StringBuilder, TimestampNanosecondBuilder
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
use std::collections::HashMap;

/// Event Parquet writer for storing detected events according to design specification
pub struct EventParquetWriter {
    output_dir: PathBuf,
    schema: Arc<Schema>,
    batch_size: usize,
    current_batch: Vec<DetectedEvent>,
    compression: Compression,
    enable_dictionary_encoding: bool,
}

impl EventParquetWriter {
    pub fn new(output_dir: &str) -> Result<Self> {
        let output_path = PathBuf::from(output_dir);
        
        // Create output directory if it doesn't exist
        std::fs::create_dir_all(&output_path)?;
        
        // Define schema for events according to design specification:
        // events.parquet with type, target, value_from, value_to, confidence, evidence_frames
        let schema = Arc::new(Schema::new(vec![
            Field::new("event_id", DataType::Utf8, false),
            Field::new("ts_ns", DataType::Timestamp(TimeUnit::Nanosecond, None), false),
            Field::new("type", DataType::Utf8, false),
            Field::new("target", DataType::Utf8, false),
            Field::new("value_from", DataType::Utf8, true), // Nullable
            Field::new("value_to", DataType::Utf8, true),   // Nullable
            Field::new("confidence", DataType::Float32, false),
            Field::new("evidence_frames", DataType::List(Arc::new(Field::new("item", DataType::Utf8, true))), false),
            Field::new("metadata", DataType::Utf8, true), // JSON-encoded metadata
        ]));
        
        Ok(Self {
            output_dir: output_path,
            schema,
            batch_size: 1000, // Smaller batch size for events
            current_batch: Vec::new(),
            compression: Compression::SNAPPY,
            enable_dictionary_encoding: true,
        })
    }
    
    /// Write detected events to Parquet format
    pub async fn write_events(&mut self, events: &[DetectedEvent]) -> Result<()> {
        debug!("Writing {} events", events.len());
        
        // Add to current batch
        self.current_batch.extend_from_slice(events);
        
        // Write batch if it's large enough
        if self.current_batch.len() >= self.batch_size {
            self.flush_batch().await?;
        }
        
        Ok(())
    }
    
    /// Write a single event
    pub async fn write_event(&mut self, event: &DetectedEvent) -> Result<()> {
        self.write_events(&[event.clone()]).await
    }
    
    /// Flush current batch to disk
    pub async fn flush_batch(&mut self) -> Result<()> {
        if self.current_batch.is_empty() {
            return Ok(());
        }
        
        info!("Flushing event batch of {} records", self.current_batch.len());
        
        // Generate filename with timestamp for partitioning
        let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
        let filename = format!("events_{}.parquet", timestamp);
        let file_path = self.output_dir.join(filename);
        
        // Create record batch from current data
        let record_batch = self.create_record_batch(&self.current_batch)?;
        
        // Write to Parquet file with optimized settings
        self.write_record_batch(&file_path, record_batch).await?;
        
        // Clear current batch
        self.current_batch.clear();
        
        info!("Successfully wrote event data to: {}", file_path.display());
        Ok(())
    }
    
    /// Create Arrow record batch from detected events
    fn create_record_batch(&self, events: &[DetectedEvent]) -> Result<RecordBatch> {
        let len = events.len();
        
        // Create arrays for each column
        let event_id_array = StringArray::from(
            events.iter().map(|e| e.id.as_str()).collect::<Vec<_>>()
        );
        
        // Convert timestamps to nanoseconds
        let mut timestamp_builder = TimestampNanosecondBuilder::new();
        for event in events {
            timestamp_builder.append_value(event.timestamp.timestamp_nanos_opt().unwrap_or(0));
        }
        let timestamp_array = timestamp_builder.finish();
        
        let type_array = StringArray::from(
            events.iter().map(|e| self.event_type_to_string(&e.event_type)).collect::<Vec<_>>()
        );
        
        let target_array = StringArray::from(
            events.iter().map(|e| e.target.as_str()).collect::<Vec<_>>()
        );
        
        // Handle nullable value_from and value_to
        let value_from_array = StringArray::from(
            events.iter().map(|e| e.value_from.as_deref()).collect::<Vec<_>>()
        );
        
        let value_to_array = StringArray::from(
            events.iter().map(|e| e.value_to.as_deref()).collect::<Vec<_>>()
        );
        
        let confidence_array = Float32Array::from(
            events.iter().map(|e| e.confidence).collect::<Vec<_>>()
        );
        
        // Create evidence_frames list array
        let mut evidence_builder = arrow::array::ListBuilder::new(StringBuilder::new());
        for event in events {
            for frame_id in &event.evidence_frames {
                evidence_builder.values().append_value(frame_id);
            }
            evidence_builder.append(true);
        }
        let evidence_frames_array = evidence_builder.finish();
        
        // Serialize metadata as JSON
        let metadata_array = StringArray::from(
            events.iter().map(|e| {
                if e.metadata.is_empty() {
                    None
                } else {
                    Some(serde_json::to_string(&e.metadata).unwrap_or_default())
                }
            }).collect::<Vec<_>>()
        );
        
        // Create record batch
        let record_batch = RecordBatch::try_new(
            self.schema.clone(),
            vec![
                Arc::new(event_id_array),
                Arc::new(timestamp_array),
                Arc::new(type_array),
                Arc::new(target_array),
                Arc::new(value_from_array),
                Arc::new(value_to_array),
                Arc::new(confidence_array),
                Arc::new(evidence_frames_array),
                Arc::new(metadata_array),
            ],
        )?;
        
        debug!("Created event record batch with {} rows", record_batch.num_rows());
        Ok(record_batch)
    }
    
    /// Write record batch to Parquet file with optimized settings
    async fn write_record_batch(&self, file_path: &Path, record_batch: RecordBatch) -> Result<()> {
        let file = File::create(file_path)?;
        
        // Configure writer properties for optimal compression and performance
        let mut props_builder = WriterProperties::builder()
            .set_compression(self.compression)
            .set_write_batch_size(1024)
            .set_max_row_group_size(10000) // Smaller row groups for events
            .set_created_by("AlwaysOnAI Event Detector".to_string());
        
        // Enable dictionary encoding for string columns
        if self.enable_dictionary_encoding {
            props_builder = props_builder
                .set_dictionary_enabled(true)
                .set_column_dictionary_enabled("event_id".into(), true)
                .set_column_dictionary_enabled("type".into(), true)
                .set_column_dictionary_enabled("target".into(), true)
                .set_column_dictionary_enabled("value_from".into(), true)
                .set_column_dictionary_enabled("value_to".into(), true);
        }
        
        let props = props_builder.build();
        
        // Create Arrow writer
        let mut writer = ArrowWriter::try_new(file, self.schema.clone(), Some(props))?;
        
        // Write record batch
        writer.write(&record_batch)?;
        
        // Close writer
        writer.close()?;
        
        debug!("Successfully wrote event Parquet file: {}", file_path.display());
        Ok(())
    }
    
    /// Query events by type
    pub async fn query_by_type(&self, event_type: &EventType) -> Result<Vec<DetectedEvent>> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(Vec::new());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("events", &table_path, ParquetReadOptions::default()).await?;
        
        let type_str = self.event_type_to_string(event_type);
        let sql = format!("SELECT * FROM events WHERE type = '{}' ORDER BY ts_ns DESC", type_str);
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        self.record_batches_to_events(batches)
    }
    
    /// Query events by target
    pub async fn query_by_target(&self, target: &str) -> Result<Vec<DetectedEvent>> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(Vec::new());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("events", &table_path, ParquetReadOptions::default()).await?;
        
        let sql = format!(
            "SELECT * FROM events WHERE target = '{}' ORDER BY ts_ns DESC",
            target.replace("'", "''") // Escape single quotes
        );
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        self.record_batches_to_events(batches)
    }
    
    /// Query events by confidence threshold
    pub async fn query_by_confidence(&self, min_confidence: f32) -> Result<Vec<DetectedEvent>> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(Vec::new());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("events", &table_path, ParquetReadOptions::default()).await?;
        
        let sql = format!(
            "SELECT * FROM events WHERE confidence >= {} ORDER BY confidence DESC",
            min_confidence
        );
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        self.record_batches_to_events(batches)
    }
    
    /// Query events by time range
    pub async fn query_by_time_range(
        &self,
        start_time: DateTime<Utc>,
        end_time: DateTime<Utc>,
    ) -> Result<Vec<DetectedEvent>> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(Vec::new());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("events", &table_path, ParquetReadOptions::default()).await?;
        
        let start_ns = start_time.timestamp_nanos_opt().unwrap_or(0);
        let end_ns = end_time.timestamp_nanos_opt().unwrap_or(0);
        
        let sql = format!(
            "SELECT * FROM events WHERE ts_ns >= {} AND ts_ns <= {} ORDER BY ts_ns ASC",
            start_ns, end_ns
        );
        let df = ctx.sql(&sql).await?;
        let batches = df.collect().await?;
        
        self.record_batches_to_events(batches)
    }
    
    /// Get event statistics
    pub async fn get_statistics(&self) -> Result<EventStatistics> {
        let ctx = SessionContext::new();
        
        let parquet_files = self.get_parquet_files()?;
        if parquet_files.is_empty() {
            return Ok(EventStatistics::default());
        }
        
        let table_path = format!("{}/*.parquet", self.output_dir.display());
        ctx.register_parquet("events", &table_path, ParquetReadOptions::default()).await?;
        
        // Get basic statistics
        let count_sql = "SELECT COUNT(*) as total_events FROM events";
        let count_df = ctx.sql(count_sql).await?;
        let count_batches = count_df.collect().await?;
        
        let avg_confidence_sql = "SELECT AVG(confidence) as avg_confidence FROM events";
        let avg_df = ctx.sql(avg_confidence_sql).await?;
        let avg_batches = avg_df.collect().await?;
        
        let type_stats_sql = "SELECT type, COUNT(*) as count FROM events GROUP BY type ORDER BY count DESC";
        let type_df = ctx.sql(type_stats_sql).await?;
        let type_batches = type_df.collect().await?;
        
        // Extract statistics (simplified for now)
        let total_events = if !count_batches.is_empty() && count_batches[0].num_rows() > 0 {
            count_batches[0].num_rows() as u64
        } else {
            0
        };
        
        Ok(EventStatistics {
            total_events,
            average_confidence: 0.75, // Placeholder
            event_type_distribution: HashMap::new(), // Placeholder
            total_size_bytes: self.calculate_total_size()?,
        })
    }
    
    /// Finalize and flush any remaining data
    pub async fn finalize(&mut self) -> Result<()> {
        if !self.current_batch.is_empty() {
            self.flush_batch().await?;
        }
        
        info!("EventParquetWriter finalized");
        Ok(())
    }
    
    // MARK: - Private Helper Methods
    
    fn event_type_to_string(&self, event_type: &EventType) -> &'static str {
        match event_type {
            EventType::FieldChange => "field_change",
            EventType::FormSubmission => "form_submission",
            EventType::ModalAppearance => "modal_appearance",
            EventType::ErrorDisplay => "error_display",
            EventType::Navigation => "navigation",
            EventType::DataEntry => "data_entry",
        }
    }
    
    fn string_to_event_type(&self, type_str: &str) -> EventType {
        match type_str {
            "field_change" => EventType::FieldChange,
            "form_submission" => EventType::FormSubmission,
            "modal_appearance" => EventType::ModalAppearance,
            "error_display" => EventType::ErrorDisplay,
            "navigation" => EventType::Navigation,
            "data_entry" => EventType::DataEntry,
            _ => EventType::FieldChange, // Default fallback
        }
    }
    
    pub fn get_parquet_files(&self) -> Result<Vec<PathBuf>> {
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
    
    fn record_batches_to_events(&self, batches: Vec<RecordBatch>) -> Result<Vec<DetectedEvent>> {
        let mut events = Vec::new();
        
        for batch in batches {
            // Extract data from batch (simplified implementation)
            let event_ids = batch.column(0).as_any().downcast_ref::<StringArray>().unwrap();
            let timestamps = batch.column(1).as_any().downcast_ref::<TimestampNanosecondArray>().unwrap();
            let types = batch.column(2).as_any().downcast_ref::<StringArray>().unwrap();
            let targets = batch.column(3).as_any().downcast_ref::<StringArray>().unwrap();
            let values_from = batch.column(4).as_any().downcast_ref::<StringArray>().unwrap();
            let values_to = batch.column(5).as_any().downcast_ref::<StringArray>().unwrap();
            let confidences = batch.column(6).as_any().downcast_ref::<Float32Array>().unwrap();
            
            for i in 0..batch.num_rows() {
                let timestamp_ns = timestamps.value(i);
                let timestamp = DateTime::from_timestamp_nanos(timestamp_ns);
                
                events.push(DetectedEvent {
                    id: event_ids.value(i).to_string(),
                    timestamp,
                    event_type: self.string_to_event_type(types.value(i)),
                    target: targets.value(i).to_string(),
                    value_from: if values_from.is_null(i) { None } else { Some(values_from.value(i).to_string()) },
                    value_to: if values_to.is_null(i) { None } else { Some(values_to.value(i).to_string()) },
                    confidence: confidences.value(i),
                    evidence_frames: Vec::new(), // Simplified - would extract from list array
                    metadata: HashMap::new(), // Simplified - would parse JSON
                });
            }
        }
        
        Ok(events)
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

/// Statistics about stored event data
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct EventStatistics {
    pub total_events: u64,
    pub average_confidence: f32,
    pub event_type_distribution: HashMap<String, u64>,
    pub total_size_bytes: u64,
}

impl Default for EventStatistics {
    fn default() -> Self {
        Self {
            total_events: 0,
            average_confidence: 0.0,
            event_type_distribution: HashMap::new(),
            total_size_bytes: 0,
        }
    }
}