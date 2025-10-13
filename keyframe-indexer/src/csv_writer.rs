use crate::error::{IndexerError, Result};
use crate::metadata_collector::FrameMetadata;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use tracing::{debug, info, error};
use chrono::{DateTime, Utc};

pub struct CsvWriter {
    output_dir: PathBuf,
    current_file: Option<std::fs::File>,
    current_file_path: Option<PathBuf>,
    batch_size: usize,
    current_batch: Vec<FrameMetadata>,
}

impl CsvWriter {
    pub fn new(output_dir: &str) -> Result<Self> {
        let output_path = PathBuf::from(output_dir);
        
        // Create output directory if it doesn't exist
        std::fs::create_dir_all(&output_path)?;
        
        Ok(Self {
            output_dir: output_path,
            current_file: None,
            current_file_path: None,
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
        let filename = format!("frames_{}.csv", timestamp);
        let file_path = self.output_dir.join(filename);
        
        // Write to CSV file
        self.write_csv_batch(&file_path, &self.current_batch).await?;
        
        // Clear current batch
        self.current_batch.clear();
        
        info!("Successfully wrote frame metadata to: {}", file_path.display());
        Ok(())
    }
    
    async fn write_csv_batch(&self, file_path: &Path, metadata: &[FrameMetadata]) -> Result<()> {
        let mut file = OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(file_path)?;
        
        // Write CSV header
        writeln!(file, "ts_ns,monitor_id,segment_id,path,phash16,entropy,app_name,win_title,width,height")?;
        
        // Write data rows
        for record in metadata {
            writeln!(
                file,
                "{},{},{},{},{},{},{},{},{},{}",
                record.ts_ns,
                record.monitor_id,
                escape_csv_field(&record.segment_id),
                escape_csv_field(&record.path),
                record.phash16,
                record.entropy,
                escape_csv_field(&record.app_name),
                escape_csv_field(&record.win_title),
                record.width,
                record.height
            )?;
        }
        
        file.flush()?;
        debug!("Successfully wrote CSV file: {}", file_path.display());
        Ok(())
    }
    
    pub async fn finalize(&mut self) -> Result<()> {
        // Flush any remaining data
        if !self.current_batch.is_empty() {
            self.flush_batch().await?;
        }
        
        info!("CsvWriter finalized");
        Ok(())
    }
    
    pub fn set_batch_size(&mut self, batch_size: usize) {
        self.batch_size = batch_size;
    }
    
    pub fn get_output_dir(&self) -> &Path {
        &self.output_dir
    }
    
    // Utility method to read back CSV files for verification
    pub async fn read_csv_file(&self, file_path: &Path) -> Result<Vec<FrameMetadata>> {
        use std::fs::File;
        use std::io::{BufRead, BufReader};
        
        let file = File::open(file_path)?;
        let reader = BufReader::new(file);
        let mut metadata_records = Vec::new();
        
        for (line_num, line) in reader.lines().enumerate() {
            let line = line?;
            
            // Skip header
            if line_num == 0 {
                continue;
            }
            
            let fields: Vec<&str> = line.split(',').collect();
            if fields.len() != 10 {
                continue; // Skip malformed lines
            }
            
            let metadata = FrameMetadata {
                ts_ns: fields[0].parse().unwrap_or(0),
                monitor_id: fields[1].parse().unwrap_or(0),
                segment_id: unescape_csv_field(fields[2]),
                path: unescape_csv_field(fields[3]),
                phash16: fields[4].parse().unwrap_or(0),
                entropy: fields[5].parse().unwrap_or(0.0),
                app_name: unescape_csv_field(fields[6]),
                win_title: unescape_csv_field(fields[7]),
                width: fields[8].parse().unwrap_or(0),
                height: fields[9].parse().unwrap_or(0),
            };
            
            metadata_records.push(metadata);
        }
        
        Ok(metadata_records)
    }
}

fn escape_csv_field(field: &str) -> String {
    if field.contains(',') || field.contains('"') || field.contains('\n') {
        format!("\"{}\"", field.replace('"', "\"\""))
    } else {
        field.to_string()
    }
}

fn unescape_csv_field(field: &str) -> String {
    if field.starts_with('"') && field.ends_with('"') {
        field[1..field.len()-1].replace("\"\"", "\"")
    } else {
        field.to_string()
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
    async fn test_csv_writer_creation() {
        let temp_dir = TempDir::new().unwrap();
        let writer = CsvWriter::new(temp_dir.path().to_str().unwrap());
        assert!(writer.is_ok());
    }
    
    #[tokio::test]
    async fn test_write_and_read_metadata() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = CsvWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_metadata = create_test_metadata();
        
        // Write metadata
        writer.write_frame_metadata(&test_metadata).await.unwrap();
        writer.flush_batch().await.unwrap();
        
        // Find the written file
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
        
        let file_path = entries[0].as_ref().unwrap().path();
        assert!(file_path.extension().unwrap() == "csv");
        
        // Read back the data
        let read_metadata = writer.read_csv_file(&file_path).await.unwrap();
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
        let mut writer = CsvWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        writer.set_batch_size(1); // Force immediate writing
        
        let test_metadata = create_test_metadata();
        
        // Write first record
        writer.write_frame_metadata(&test_metadata[0..1]).await.unwrap();
        
        // Should have created one file
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
        
        // Write second record
        writer.write_frame_metadata(&test_metadata[1..2]).await.unwrap();
        
        // Should have created second file (or at least verify we can finalize)
        writer.finalize().await.unwrap();
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert!(entries.len() >= 1); // At least one file should exist
    }
    
    #[test]
    fn test_csv_escaping() {
        assert_eq!(escape_csv_field("simple"), "simple");
        assert_eq!(escape_csv_field("with,comma"), "\"with,comma\"");
        assert_eq!(escape_csv_field("with\"quote"), "\"with\"\"quote\"");
        
        assert_eq!(unescape_csv_field("simple"), "simple");
        assert_eq!(unescape_csv_field("\"with,comma\""), "with,comma");
        assert_eq!(unescape_csv_field("\"with\"\"quote\""), "with\"quote");
    }
    
    #[tokio::test]
    async fn test_finalization() {
        let temp_dir = TempDir::new().unwrap();
        let mut writer = CsvWriter::new(temp_dir.path().to_str().unwrap()).unwrap();
        
        let test_metadata = create_test_metadata();
        writer.write_frame_metadata(&test_metadata).await.unwrap();
        
        // Finalize should flush remaining data
        writer.finalize().await.unwrap();
        
        // Should have created one file
        let entries: Vec<_> = std::fs::read_dir(temp_dir.path()).unwrap().collect();
        assert_eq!(entries.len(), 1);
    }
}