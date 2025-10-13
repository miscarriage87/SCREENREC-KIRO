use crate::error::{IndexerError, Result};
use crate::ocr_data::{OCRResult, BoundingBox};
use crate::event_detector::{EventDetector, DetectedEvent, EventDetectionConfig};
use crate::event_parquet_writer::EventParquetWriter;
use crate::ocr_parquet_writer::OCRParquetWriter;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use std::path::Path;
use tracing::{debug, info, warn, error};

/// Delta analyzer that compares OCR results between consecutive frames
/// and detects field changes according to requirements 4.1 and 4.5
pub struct DeltaAnalyzer {
    /// Event detector for identifying changes
    event_detector: EventDetector,
    /// Event storage writer
    event_writer: EventParquetWriter,
    /// OCR data reader for querying previous frames
    ocr_reader: OCRParquetWriter,
    /// Configuration for delta analysis
    config: DeltaAnalysisConfig,
    /// Frame sequence tracking for temporal analysis
    frame_sequence: FrameSequenceTracker,
}

/// Configuration for delta analysis behavior
#[derive(Debug, Clone)]
pub struct DeltaAnalysisConfig {
    /// Maximum time gap between frames for comparison (seconds)
    pub max_frame_gap_seconds: f64,
    /// Minimum confidence threshold for processing OCR results
    pub min_ocr_confidence: f32,
    /// Minimum confidence threshold for reporting events
    pub min_event_confidence: f32,
    /// Enable temporal context analysis
    pub enable_temporal_context: bool,
    /// Maximum number of previous frames to consider
    pub max_previous_frames: usize,
}

impl Default for DeltaAnalysisConfig {
    fn default() -> Self {
        Self {
            max_frame_gap_seconds: 10.0,
            min_ocr_confidence: 0.7,
            min_event_confidence: 0.6,
            enable_temporal_context: true,
            max_previous_frames: 5,
        }
    }
}

/// Tracks frame sequences for temporal analysis
#[derive(Debug, Clone)]
struct FrameSequenceTracker {
    /// Recent frames with their timestamps
    recent_frames: Vec<FrameInfo>,
    /// Maximum number of frames to track
    max_frames: usize,
}

/// Information about a processed frame
#[derive(Debug, Clone)]
struct FrameInfo {
    pub frame_id: String,
    pub timestamp: DateTime<Utc>,
    pub ocr_results: Vec<OCRResult>,
    pub detected_events: Vec<DetectedEvent>,
}

impl DeltaAnalyzer {
    /// Create a new delta analyzer with default configuration
    pub fn new(
        ocr_storage_dir: &str,
        event_storage_dir: &str,
    ) -> Result<Self> {
        Self::with_config(
            ocr_storage_dir,
            event_storage_dir,
            DeltaAnalysisConfig::default(),
        )
    }
    
    /// Create a new delta analyzer with custom configuration
    pub fn with_config(
        ocr_storage_dir: &str,
        event_storage_dir: &str,
        config: DeltaAnalysisConfig,
    ) -> Result<Self> {
        let event_detection_config = EventDetectionConfig {
            min_ocr_confidence: config.min_ocr_confidence,
            min_event_confidence: config.min_event_confidence,
            max_frame_gap_seconds: config.max_frame_gap_seconds,
            ..EventDetectionConfig::default()
        };
        
        let event_detector = EventDetector::with_config(event_detection_config)?;
        let event_writer = EventParquetWriter::new(event_storage_dir)?;
        let ocr_reader = OCRParquetWriter::new(ocr_storage_dir)?;
        
        let frame_sequence = FrameSequenceTracker {
            recent_frames: Vec::new(),
            max_frames: config.max_previous_frames,
        };
        
        Ok(Self {
            event_detector,
            event_writer,
            ocr_reader,
            config,
            frame_sequence,
        })
    }
    
    /// Analyze a new frame and detect events by comparing with previous frames
    pub async fn analyze_frame(
        &mut self,
        frame_id: &str,
        ocr_results: Vec<OCRResult>,
        timestamp: DateTime<Utc>,
    ) -> Result<Vec<DetectedEvent>> {
        info!("Analyzing frame {} with {} OCR results", frame_id, ocr_results.len());
        
        // Filter OCR results by confidence threshold
        let high_confidence_results: Vec<OCRResult> = ocr_results
            .into_iter()
            .filter(|r| r.confidence >= self.config.min_ocr_confidence)
            .collect();
        
        if high_confidence_results.is_empty() {
            debug!("No high-confidence OCR results in frame {}", frame_id);
            return Ok(Vec::new());
        }
        
        // Detect events using the event detector
        let detected_events = self.event_detector.analyze_frame(
            frame_id,
            &high_confidence_results,
            timestamp,
            1920.0, // Default screen width
            1080.0, // Default screen height
        )?;
        
        // Perform additional temporal context analysis if enabled
        let enhanced_events = if self.config.enable_temporal_context {
            self.enhance_events_with_temporal_context(&detected_events, &high_confidence_results)?
        } else {
            detected_events
        };
        
        // Filter events by confidence threshold
        let final_events: Vec<DetectedEvent> = enhanced_events
            .into_iter()
            .filter(|e| e.confidence >= self.config.min_event_confidence)
            .collect();
        
        // Store events in Parquet format
        if !final_events.is_empty() {
            self.event_writer.write_events(&final_events).await?;
            info!("Stored {} events for frame {}", final_events.len(), frame_id);
        }
        
        // Update frame sequence tracker
        self.update_frame_sequence(frame_id, high_confidence_results, final_events.clone(), timestamp);
        
        Ok(final_events)
    }
    
    /// Enhance events with temporal context analysis
    fn enhance_events_with_temporal_context(
        &self,
        events: &[DetectedEvent],
        current_ocr_results: &[OCRResult],
    ) -> Result<Vec<DetectedEvent>> {
        let mut enhanced_events = Vec::new();
        
        for event in events {
            let mut enhanced_event = event.clone();
            
            // Add temporal context based on recent frames
            if let Some(context) = self.analyze_temporal_context(event, current_ocr_results) {
                // Adjust confidence based on temporal patterns
                enhanced_event.confidence = self.calculate_temporal_confidence(
                    event.confidence,
                    &context,
                );
                
                // Add temporal metadata
                enhanced_event.metadata.insert(
                    "temporal_pattern".to_string(),
                    context.pattern_type.clone(),
                );
                enhanced_event.metadata.insert(
                    "pattern_confidence".to_string(),
                    context.pattern_confidence.to_string(),
                );
            }
            
            enhanced_events.push(enhanced_event);
        }
        
        Ok(enhanced_events)
    }
    
    /// Analyze temporal context for an event
    fn analyze_temporal_context(
        &self,
        event: &DetectedEvent,
        current_ocr_results: &[OCRResult],
    ) -> Option<TemporalContext> {
        // Look for patterns in recent frames
        let mut pattern_matches = 0;
        let mut total_frames = 0;
        
        for frame_info in &self.frame_sequence.recent_frames {
            total_frames += 1;
            
            // Check if similar events occurred in previous frames
            for prev_event in &frame_info.detected_events {
                if self.events_are_similar(event, prev_event) {
                    pattern_matches += 1;
                    break;
                }
            }
        }
        
        if total_frames == 0 {
            return None;
        }
        
        let pattern_frequency = pattern_matches as f32 / total_frames as f32;
        
        let pattern_type = if pattern_frequency > 0.7 {
            "frequent_pattern".to_string()
        } else if pattern_frequency > 0.3 {
            "occasional_pattern".to_string()
        } else {
            "rare_event".to_string()
        };
        
        Some(TemporalContext {
            pattern_type,
            pattern_confidence: pattern_frequency,
            recent_occurrences: pattern_matches,
            total_frames_analyzed: total_frames,
        })
    }
    
    /// Check if two events are similar for pattern analysis
    fn events_are_similar(&self, event1: &DetectedEvent, event2: &DetectedEvent) -> bool {
        event1.event_type == event2.event_type &&
        event1.target == event2.target
    }
    
    /// Calculate temporal confidence adjustment
    fn calculate_temporal_confidence(
        &self,
        base_confidence: f32,
        context: &TemporalContext,
    ) -> f32 {
        let temporal_boost = match context.pattern_type.as_str() {
            "frequent_pattern" => 0.1,  // Boost confidence for frequent patterns
            "occasional_pattern" => 0.05, // Small boost for occasional patterns
            "rare_event" => -0.05,      // Slight penalty for rare events
            _ => 0.0,
        };
        
        (base_confidence + temporal_boost).clamp(0.0, 1.0)
    }
    
    /// Update frame sequence tracker
    fn update_frame_sequence(
        &mut self,
        frame_id: &str,
        ocr_results: Vec<OCRResult>,
        events: Vec<DetectedEvent>,
        timestamp: DateTime<Utc>,
    ) {
        let frame_info = FrameInfo {
            frame_id: frame_id.to_string(),
            timestamp,
            ocr_results,
            detected_events: events,
        };
        
        // Add new frame
        self.frame_sequence.recent_frames.push(frame_info);
        
        // Remove old frames if we exceed the limit
        while self.frame_sequence.recent_frames.len() > self.frame_sequence.max_frames {
            self.frame_sequence.recent_frames.remove(0);
        }
        
        // Sort by timestamp to maintain chronological order
        self.frame_sequence.recent_frames.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));
    }
    
    /// Query events by type from storage
    pub async fn query_events_by_type(&self, event_type: &crate::event_detector::EventType) -> Result<Vec<DetectedEvent>> {
        self.event_writer.query_by_type(event_type).await
    }
    
    /// Query events by target from storage
    pub async fn query_events_by_target(&self, target: &str) -> Result<Vec<DetectedEvent>> {
        self.event_writer.query_by_target(target).await
    }
    
    /// Query events by confidence threshold from storage
    pub async fn query_events_by_confidence(&self, min_confidence: f32) -> Result<Vec<DetectedEvent>> {
        self.event_writer.query_by_confidence(min_confidence).await
    }
    
    /// Query events by time range from storage
    pub async fn query_events_by_time_range(
        &self,
        start_time: DateTime<Utc>,
        end_time: DateTime<Utc>,
    ) -> Result<Vec<DetectedEvent>> {
        self.event_writer.query_by_time_range(start_time, end_time).await
    }
    
    /// Get event statistics from storage
    pub async fn get_event_statistics(&self) -> Result<crate::event_parquet_writer::EventStatistics> {
        self.event_writer.get_statistics().await
    }
    
    /// Get field change history from the event detector
    pub fn get_field_changes(&self) -> Vec<FieldChangeInfo> {
        self.event_detector.get_field_changes()
            .iter()
            .map(|change| FieldChangeInfo {
                field_id: change.field_id.clone(),
                value_from: change.value_from.clone(),
                value_to: change.value_to.clone(),
                timestamp: change.timestamp,
                confidence: change.confidence,
            })
            .collect()
    }
    
    /// Get current field states from the event detector
    pub fn get_current_field_states(&self) -> Vec<FieldStateInfo> {
        self.event_detector.get_field_states()
            .iter()
            .map(|(field_id, state)| FieldStateInfo {
                field_id: field_id.clone(),
                current_value: state.value.clone(),
                last_updated: state.last_updated,
                confidence: state.confidence,
                frame_id: state.frame_id.clone(),
            })
            .collect()
    }
    
    /// Flush any pending writes to storage
    pub async fn flush(&mut self) -> Result<()> {
        self.event_writer.flush_batch().await?;
        info!("DeltaAnalyzer flushed all pending data");
        Ok(())
    }
    
    /// Finalize the analyzer and close all resources
    pub async fn finalize(&mut self) -> Result<()> {
        self.event_writer.finalize().await?;
        self.event_detector.clear_cache();
        info!("DeltaAnalyzer finalized");
        Ok(())
    }
}

/// Temporal context information for event analysis
#[derive(Debug, Clone)]
struct TemporalContext {
    pub pattern_type: String,
    pub pattern_confidence: f32,
    pub recent_occurrences: usize,
    pub total_frames_analyzed: usize,
}

/// Field change information for external consumption
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldChangeInfo {
    pub field_id: String,
    pub value_from: String,
    pub value_to: String,
    pub timestamp: DateTime<Utc>,
    pub confidence: f32,
}

/// Field state information for external consumption
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldStateInfo {
    pub field_id: String,
    pub current_value: String,
    pub last_updated: DateTime<Utc>,
    pub confidence: f32,
    pub frame_id: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    
    fn create_test_ocr_result(frame_id: &str, text: &str, x: f32, y: f32) -> OCRResult {
        OCRResult {
            frame_id: frame_id.to_string(),
            roi: BoundingBox::new(x, y, 100.0, 20.0),
            text: text.to_string(),
            language: "en-US".to_string(),
            confidence: 0.9,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        }
    }
    
    #[tokio::test]
    async fn test_delta_analyzer_creation() {
        let temp_dir = TempDir::new().unwrap();
        let ocr_dir = temp_dir.path().join("ocr");
        let event_dir = temp_dir.path().join("events");
        
        std::fs::create_dir_all(&ocr_dir).unwrap();
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let analyzer = DeltaAnalyzer::new(
            ocr_dir.to_str().unwrap(),
            event_dir.to_str().unwrap(),
        );
        
        assert!(analyzer.is_ok());
    }
    
    #[tokio::test]
    async fn test_frame_analysis_with_field_changes() {
        let temp_dir = TempDir::new().unwrap();
        let ocr_dir = temp_dir.path().join("ocr");
        let event_dir = temp_dir.path().join("events");
        
        std::fs::create_dir_all(&ocr_dir).unwrap();
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let mut analyzer = DeltaAnalyzer::new(
            ocr_dir.to_str().unwrap(),
            event_dir.to_str().unwrap(),
        ).unwrap();
        
        // Analyze first frame
        let frame1_ocr = vec![
            create_test_ocr_result("frame1", "Username:", 10.0, 10.0),
            create_test_ocr_result("frame1", "", 120.0, 10.0), // Empty field
        ];
        
        let events1 = analyzer.analyze_frame("frame1", frame1_ocr, Utc::now()).await.unwrap();
        
        // Analyze second frame with field change
        let frame2_ocr = vec![
            create_test_ocr_result("frame2", "Username:", 10.0, 10.0),
            create_test_ocr_result("frame2", "john.doe", 120.0, 10.0), // Field filled
        ];
        
        let events2 = analyzer.analyze_frame("frame2", frame2_ocr, Utc::now()).await.unwrap();
        
        // Should detect field change in second frame
        assert!(!events2.is_empty());
        
        // Check field changes
        let field_changes = analyzer.get_field_changes();
        assert!(!field_changes.is_empty());
    }
    
    #[tokio::test]
    async fn test_temporal_context_analysis() {
        let temp_dir = TempDir::new().unwrap();
        let ocr_dir = temp_dir.path().join("ocr");
        let event_dir = temp_dir.path().join("events");
        
        std::fs::create_dir_all(&ocr_dir).unwrap();
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let config = DeltaAnalysisConfig {
            enable_temporal_context: true,
            max_previous_frames: 3,
            ..DeltaAnalysisConfig::default()
        };
        
        let mut analyzer = DeltaAnalyzer::with_config(
            ocr_dir.to_str().unwrap(),
            event_dir.to_str().unwrap(),
            config,
        ).unwrap();
        
        // Analyze multiple frames to build temporal context
        for i in 1..=5 {
            let frame_id = format!("frame{}", i);
            let ocr_results = vec![
                create_test_ocr_result(&frame_id, "Error: Invalid input", 10.0, 10.0),
            ];
            
            let events = analyzer.analyze_frame(&frame_id, ocr_results, Utc::now()).await.unwrap();
            
            // Later frames should have enhanced confidence due to temporal patterns
            if i > 3 {
                for event in &events {
                    if event.metadata.contains_key("temporal_pattern") {
                        assert!(event.confidence > 0.6);
                    }
                }
            }
        }
    }
}