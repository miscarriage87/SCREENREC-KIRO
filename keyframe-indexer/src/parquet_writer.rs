use crate::error::{IndexerError, Result};
use crate::metadata_collector::FrameMetadata;
use arrow::array::{
    Array, Int32Array, Int64Array, Float32Array, StringArray, UInt32Array
};
use arrow::datatypes::{DataType, Field, Schema};
use arrow::record_batch::RecordBatch;
use parquet::arrow::ArrowWriter;
use parquet::file::properties::WriterProperties;
use std::fs::File;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tracing::{debug, info, error};
use chrono::{DateTime, Utc};

pub struct ParquetWriter {
    output_dir: PathBuf,
    schema: Arc<Schema>,
    batch_size: usize,
    current_batch: Vec<FrameMetadata>,
}

impl ParquetWriter {
    pub fn new(output_dir: &str) -> Result<Self> {
        let output_path = PathBuf::from(output_dir);
        
        // Create output directory if it doesn't exist
        std::fs::create_dir_all(&output_path)?;
        
        // Define schema for frame metadata
        let schema = Arc::new(Schema::new(vec![
            Field::new("ts_ns", DataType::Int64, false),
            Field::new("monitor_id", DataType::Int32, false),
            Field::new("segment_id", DataType::Utf8, false),
            Field::new("path", DataType::Utf8, false),
            Field::new("phash16", DataType::Int64, false),
            Field::new("entropy", DataType::Float32, false),
            Field::new("app_name", DataType::Utf8, false),
            Field::new("win_title", DataType::Utf8, false),
            Field::new("width", DataType::UInt32, false),
            Field::new("height", DataType::UInt32, false),
        ]));
        
        Ok(Self {
            output_dir: output_path,
            schema,
            batch_size: 1000, // Write in batches of 1000 records
            current_batch: Vec::new(),
        })
    }
    
    pub async fn write_frame_metadata(&mut self, metadata: &[FrameMetadata]) -> Result<()> {
        debug!("Writing {} frame metadata records", metadata.len());
        
        // Add to current batch
        self.current_batch.extend_from_slice(metadata);
        
        // Write batch if it's large enough
        if self.current_batch.len() >= self.batch_size {
            self.flush_batch().await?;
        }
        
        Ok(())
    }
    
    pub async fn flush_batch(&mut self) -> Result<()> {
        if self.current_batch.is_empty() {
            return Ok(());
        }
        
        info!("Flushing batch of {} frame metadata records", self.current_batch.len());
        
        // Generate filename with timestamp
        let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
        let filename = format!("frames_{}.parquet", timestamp);
        let file_path = self.output_dir.join(filename);
        
        // Create record batch from current data
        let record_batch = self.create_record_batch(&self.current_batch)?;
        
        // Write to Parquet file
        self.write_record_batch(&file_path, record_batch).await?;
        
        // Clear current batch
        self.current_batch.clear();
        
        info!("Successfully wrote frame metadata to: {}", file_path.display());
        Ok(())
    }
    
    fn create_record_batch(&self, metadata: &[FrameMetadata]) -> Result<RecordBatch> {
        let len = metadata.len();
        
        // Create arrays for each column
        let ts_ns_array = Int64Array::from(
            metadata.iter().map(|m| m.ts_ns).collect::<Vec<_>>()
        );
        
        let monitor_id_array = Int32Array::from(
            metadata.iter().map(|m| m.monitor_id).collect::<Vec<_>>()
        );
        
        let segment_id_array = StringArray::from(
            metadata.iter().map(|m| m.segment_id.as_str()).collect::<Vec<_>>()
        );
        
        let path_array = StringArray::from(
            metadata.iter().map(|m| m.path.as_str()).collect::<Vec<_>>()
        );
        
        let phash16_array = Int64Array::from(
            metadata.iter().map(|m| m.phash16).collect::<Vec<_>>()
        );
        
        let entropy_array = Float32Array::from(
            metadata.iter().map(|m| m.entropy).collect::<Vec<_>>()
        );
        
        let app_name_array = StringArray::from(
            metadata.iter().map(|m| m.app_name.as_str()).collect::<Vec<_>>()
        );
        
        let win_title_array = StringArray::from(
            metadata.iter().map(|m| m.win_title.as_str()).collect::<Vec<_>>()
        );
        
        let width_array = UInt32Array::from(
            metadata.iter().map(|m| m.width).collect::<Vec<_>>()
        );
        
        let height_array = UInt32Array::from(
            metadata.iter().map(|m| m.height).collect::<Vec<_>>()
        );
        
        // Create record batch
        let record_batch = RecordBatch::try_new(
            self.schema.clone(),
            vec![
                Arc::new(ts_ns_array),
                Arc::new(monitor_id_array),
                Arc::new(segment_id_array),
                Arc::new(path_array),
                Arc::new(phash16_array),
                Arc::new(entropy_array),
                Arc::new(app_name_array),
                Arc::new(win_title_array),
                Arc::new(width_array),
                Arc::new(height_array),
            ],
        )?;
        
        debug!("Created record batch with {} rows", record_batch.num_rows());
        Ok(record_batch)
    }
    
    async fn write_record_batch(&self, file_path: &Path, record_batch: RecordBatch) -> Result<()> {
        // Create file
        let file = File::create(file_path)?;
        
        // Configure writer properties for optimal compression and performance
        let props = WriterProperties::builder()
            .set_compression(parquet::basic::Compression::SNAPPY)
            .set_write_batch_size(1024)
            .set_max_row_group_size(10000)
            .build();
        
        // Create Arrow writer
        let mut writer = ArrowWriter::try_new(file, self.schema.clone(), Some(props))?;
        
        // Write record batch
        writer.write(&record_batch)?;
        
        // Close writer
        writer.close()?;
        
        debug!("Successfully wrote Parquet file: {}", file_path.display());
        Ok(())
    }
    
    pub async fn finalize(&mut self) -> Result<()> {
        // Flush any remaining data
        if !self.current_batch.is_empty() {
            self.flush_batch().await?;
        }
        
        info!("ParquetWriter finalized");
        Ok(())
    }
    
    pub fn set_batch_size(&mut self, batch_size: usize) {
        self.batch_size = batch_size;
    }
    
    pub fn get_output_dir(&self) -> &Path {
        &self.output_dir
    }
    
    pub fn get_schema(&self) -> &Schema {
        &self.schema
    }
    
    // Utility method to read back Parquet files for verification
    pub async fn read_parquet_file(&self, file_path: &Path) -> Result<Vec<FrameMetadata>> {
        use parquet::arrow::arrow_reader::ParquetRecordBatchReaderBuilder;
        use std::fs::File;
        
        let file = File::open(file_path)?;
        let builder = ParquetRecordBatchReaderBuilder::try_new(file)?;
        let mut reader = builder.build()?;
        
        let mut metadata_records = Vec::new();
        
        while let Some(batch_result) = reader.next() {
            let batch = batch_result?;
            
            // Extract data from batch
            let ts_ns = batch.column(0).as_any().downcast_ref::<Int64Array>().unwrap();
            let monitor_id = batch.column(1).as_any().downcast_ref::<Int32Array>().unwrap();
            let segment_id = batch.column(2).as_any().downcast_ref::<StringArray>().unwrap();
            let path = batch.column(3).as_any().downcast_ref::<StringArray>().unwrap();
            let phash16 = batch.column(4).as_any().downcast_ref::<Int64Array>().unwrap();
            let entropy = batch.column(5).as_any().downcast_ref::<Float32Array>().unwrap();
            let app_name = batch.column(6).as_any().downcast_ref::<StringArray>().unwrap();
            let win_title = batch.column(7).as_any().downcast_ref::<StringArray>().unwrap();
            let width = batch.column(8).as_any().downcast_ref::<UInt32Array>().unwrap();
            let height = batch.column(9).as_any().downcast_ref::<UInt32Array>().unwrap();
            
            for i in 0..batch.num_rows() {
                metadata_records.push(FrameMetadata {
                    ts_ns: ts_ns.value(i),
                    monitor_id: monitor_id.value(i),
                    segment_id: segment_id.value(i).to_string(),
                    path: path.value(i).to_string(),
                    phash16: phash16.value(i),
                    entropy: entropy.value(i),
                    app_name: app_name.value(i).to_string(),
                    win_title: win_title.value(i).to_string(),
                    width: width.value(i),
                    height: height.value(i),
                });
            }
        }
        
        Ok(metadata_records)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use uuid::Uuid;
    
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
    
    #[tokio::test]
    async fn test_parquet_writer_creation() {
        let temp_dir = TempDir::new().unwrap();
        let writer = ParquetWriter::new(temp_dir.path().to_str().unwrap());
        assert!(writer.is_ok());
    }
    
    #[tokio::test]
    async fn test_write_and_read_metadata() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = ParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_metadata = create_test_metadata();
        
        // Write metadata
        writer.write_frame_metadata(&test_metadata).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Find the written file
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
        
        let file_path = entries[0].as_ref().unwrap().path();
        assert!(file_path.extension().unwrap() == "parquet");
        
        // Read back the data
        let read_metadata = writer.read_parquet_file(&file_path).await.unwrap();
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
    }
    
    #[tokio::test]
    async fn test_batch_writing() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = ParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        writer.set_batch_size(1); // Force immediate writing
        
        let test_metadata = create_test_metadata();
        
        // Write first record
        writer.write_frame_metadata(&test_metadata[0..1]).await.unwrap();
        
        // Should have created one file
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
        
        // Write second record
        writer.write_frame_metadata(&test_metadata[1..2]).await.unwrap();
        
        // Should have created second file
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 2);
    }
    
    #[tokio::test]
    async fn test_schema_validation() {
        let temp_dir = TempDir::new().unwrap();
        let writer = ParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let schema = writer.get_schema();
        assert_eq!(schema.fields().len(), 10);
        
        // Check field names and types
        assert_eq!(schema.field(0).name(), "ts_ns");
        assert_eq!(schema.field(0).data_type(), &DataType::Int64);
        
        assert_eq!(schema.field(1).name(), "monitor_id");
        assert_eq!(schema.field(1).data_type(), &DataType::Int32);
        
        assert_eq!(schema.field(2).name(), "segment_id");
        assert_eq!(schema.field(2).data_type(), &DataType::Utf8);
    }
    
    #[tokio::test]
    async fn test_finalization() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = ParquetWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_metadata = create_test_metadata();
        writer.write_frame_metadata(&test_metadata).await.unwrap();
        
        // Finalize should flush remaining data
        writer.finalize().await.unwrap();
        
        // Should have created one file
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
    }
}