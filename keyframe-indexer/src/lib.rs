pub mod keyframe_extractor;
pub mod scene_detector;
pub mod file_watcher;
pub mod metadata_collector;
pub mod csv_writer;
pub mod error;
pub mod config;
pub mod csv_test;
pub mod parquet_writer;
pub mod ocr_data;
pub mod ocr_parquet_writer;
pub mod event_detector;
pub mod event_parquet_writer;
pub mod delta_analyzer;
pub mod navigation_detector;
pub mod cursor_tracker;
pub mod event_correlator;
pub mod navigation_integration;
pub mod integration_test;
pub mod error_modal_detector;
pub mod encryption;

#[cfg(test)]
pub mod ocr_parquet_tests;

#[cfg(test)]
pub mod event_detection_tests;

#[cfg(test)]
pub mod navigation_integration_tests;

#[cfg(test)]
pub mod error_modal_tests;

pub mod simple_event_test;

pub use keyframe_extractor::KeyframeExtractor;
pub use scene_detector::SceneDetector;
pub use file_watcher::FileWatcher;
pub use metadata_collector::MetadataCollector;
pub use csv_writer::CsvWriter;
pub use error::{IndexerError, Result};
pub use config::IndexerConfig;
pub use parquet_writer::ParquetWriter;
pub use ocr_data::{OCRResult, OCRBatch, BoundingBox};
pub use ocr_parquet_writer::{OCRParquetWriter, OCRStatistics};
pub use event_detector::{EventDetector, DetectedEvent, EventType, EventDetectionConfig};
pub use event_parquet_writer::{EventParquetWriter, EventStatistics};
pub use delta_analyzer::{DeltaAnalyzer, DeltaAnalysisConfig, FieldChangeInfo, FieldStateInfo};
pub use navigation_detector::{NavigationDetector, NavigationDetectionConfig, WindowState, TabState, FocusEvent};
pub use cursor_tracker::{CursorTracker, CursorTrackingConfig, CursorPosition, ClickEvent, MovementTrail, TrailType};
pub use event_correlator::{EventCorrelator, CorrelationConfig, CorrelationResult, CorrelationType};
pub use navigation_integration::{NavigationIntegrationService, NavigationIntegrationConfig, NavigationStatistics};
pub use error_modal_detector::{ErrorModalDetector, ErrorModalDetectionConfig, ErrorModalEvent, ErrorModalType, SeverityLevel, PatternMatch, LayoutAnalysis};
pub use encryption::{EncryptionManager, SecureParquetWriter};

use anyhow::Result as AnyhowResult;
use std::path::Path;
use tokio::sync::mpsc;
use tracing::{info, error, warn};

pub struct IndexerService {
    config: IndexerConfig,
    extractor: KeyframeExtractor,
    detector: SceneDetector,
    metadata_collector: MetadataCollector,
    csv_writer: CsvWriter,
}

impl IndexerService {
    pub fn new(config: IndexerConfig) -> AnyhowResult<Self> {
        let extractor = KeyframeExtractor::new(config.extraction_fps)?;
        let detector = SceneDetector::new(config.scene_detection.clone())?;
        let metadata_collector = MetadataCollector::new()?;
        let csv_writer = CsvWriter::new(&config.output_dir)?;
        
        Ok(Self {
            config,
            extractor,
            detector,
            metadata_collector,
            csv_writer,
        })
    }
    
    pub async fn start_watching(&mut self, watch_dir: &str) -> AnyhowResult<()> {
        let (tx, mut rx) = mpsc::channel(100);
        let mut file_watcher = FileWatcher::new(watch_dir, tx)?;
        
        info!("Starting file watcher for directory: {}", watch_dir);
        file_watcher.start().await?;
        
        while let Some(video_path) = rx.recv().await {
            if let Err(e) = self.process_video_segment(&video_path).await {
                error!("Failed to process video segment {}: {}", video_path.display(), e);
            }
        }
        
        Ok(())
    }
    
    async fn process_video_segment(&mut self, video_path: &Path) -> AnyhowResult<()> {
        info!("Processing video segment: {}", video_path.display());
        
        // Extract keyframes
        let keyframes = match self.extractor.extract_keyframes(video_path).await {
            Ok(frames) => frames,
            Err(e) => {
                error!("Failed to extract keyframes from {}: {}", video_path.display(), e);
                return Err(e.into());
            }
        };
        
        if keyframes.is_empty() {
            warn!("No keyframes extracted from {}", video_path.display());
            return Ok(());
        }
        
        info!("Extracted {} keyframes from {}", keyframes.len(), video_path.display());
        
        // Detect scene changes
        let scene_changes = self.detector.detect_scene_changes(&keyframes)?;
        info!("Detected {} scene changes", scene_changes.len());
        
        // Collect metadata for each keyframe
        let mut frame_metadata = Vec::new();
        for keyframe in &keyframes {
            let metadata = self.metadata_collector.collect_metadata(keyframe).await?;
            frame_metadata.push(metadata);
        }
        
        // Write to CSV
        self.csv_writer.write_frame_metadata(&frame_metadata).await?;
        
        info!("Successfully processed video segment: {}", video_path.display());
        Ok(())
    }
}