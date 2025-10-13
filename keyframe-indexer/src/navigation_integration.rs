use crate::error::{IndexerError, Result};
use crate::event_detector::{DetectedEvent, EventType};
use crate::navigation_detector::{NavigationDetector, NavigationDetectionConfig};
use crate::cursor_tracker::{CursorTracker, CursorTrackingConfig};
use crate::event_correlator::{EventCorrelator, CorrelationConfig, CorrelationResult};
use crate::event_parquet_writer::EventParquetWriter;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use tracing::{debug, info, warn, error};

/// Integrated navigation and interaction event detection system
/// Combines navigation detection, cursor tracking, and event correlation
/// according to requirements 4.2, 4.3, and 4.6
pub struct NavigationIntegrationService {
    /// Navigation detector for window/tab changes
    navigation_detector: NavigationDetector,
    /// Cursor tracker for mouse movements and clicks
    cursor_tracker: CursorTracker,
    /// Event correlator for linking cursor actions with screen changes
    event_correlator: EventCorrelator,
    /// Event storage writer
    event_writer: EventParquetWriter,
    /// Configuration for the integration service
    pub config: NavigationIntegrationConfig,
    /// Performance metrics
    metrics: NavigationMetrics,
}

/// Configuration for the navigation integration service
#[derive(Debug, Clone)]
pub struct NavigationIntegrationConfig {
    /// Navigation detection configuration
    pub navigation_config: NavigationDetectionConfig,
    /// Cursor tracking configuration
    pub cursor_config: CursorTrackingConfig,
    /// Event correlation configuration
    pub correlation_config: CorrelationConfig,
    /// Enable comprehensive event logging
    pub enable_comprehensive_logging: bool,
    /// Batch size for event processing
    pub event_batch_size: usize,
    /// Processing interval in milliseconds
    pub processing_interval_ms: u64,
}

impl Default for NavigationIntegrationConfig {
    fn default() -> Self {
        Self {
            navigation_config: NavigationDetectionConfig::default(),
            cursor_config: CursorTrackingConfig::default(),
            correlation_config: CorrelationConfig::default(),
            enable_comprehensive_logging: true,
            event_batch_size: 50,
            processing_interval_ms: 100,
        }
    }
}

/// Performance metrics for navigation detection
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NavigationMetrics {
    pub total_events_detected: u64,
    pub navigation_events: u64,
    pub cursor_events: u64,
    pub correlation_events: u64,
    pub processing_time_ms: u64,
    pub error_count: u64,
    pub last_update: Option<DateTime<Utc>>,
}

/// Comprehensive navigation event result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NavigationEventResult {
    pub detected_events: Vec<DetectedEvent>,
    pub correlations: Vec<CorrelationResult>,
    pub metrics: NavigationMetrics,
    pub timestamp: DateTime<Utc>,
}

impl NavigationIntegrationService {
    /// Create a new navigation integration service
    pub fn new(event_storage_dir: &str) -> Result<Self> {
        Self::with_config(event_storage_dir, NavigationIntegrationConfig::default())
    }
    
    /// Create a new navigation integration service with custom configuration
    pub fn with_config(event_storage_dir: &str, config: NavigationIntegrationConfig) -> Result<Self> {
        let navigation_detector = NavigationDetector::with_config(config.navigation_config.clone());
        let cursor_tracker = CursorTracker::with_config(config.cursor_config.clone());
        let event_correlator = EventCorrelator::with_config(config.correlation_config.clone());
        let event_writer = EventParquetWriter::new(event_storage_dir)?;
        
        Ok(Self {
            navigation_detector,
            cursor_tracker,
            event_correlator,
            event_writer,
            config,
            metrics: NavigationMetrics::default(),
        })
    }
    
    /// Process a frame and detect all navigation and interaction events
    pub async fn process_frame(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<NavigationEventResult> {
        let start_time = std::time::Instant::now();
        debug!("Processing navigation events for frame {}", frame_id);
        
        let mut all_events = Vec::new();
        
        // 1. Detect navigation events (window/tab changes, focus changes)
        match self.navigation_detector.detect_navigation_events(frame_id, timestamp).await {
            Ok(nav_events) => {
                self.metrics.navigation_events += nav_events.len() as u64;
                
                // Add navigation events to correlator
                if let Some(current_window) = self.navigation_detector.get_current_window() {
                    self.event_correlator.add_window_change_event(current_window, frame_id);
                }
                
                if let Some(current_tab) = self.navigation_detector.get_current_tab() {
                    self.event_correlator.add_tab_change_event(current_tab, frame_id);
                }
                
                // Add focus events to correlator
                for focus_event in self.navigation_detector.get_focus_history() {
                    self.event_correlator.add_focus_change_event(focus_event, frame_id);
                }
                
                all_events.extend(nav_events);
            }
            Err(e) => {
                warn!("Navigation detection failed for frame {}: {}", frame_id, e);
                self.metrics.error_count += 1;
            }
        }
        
        // 2. Track cursor events (movements, clicks, trails)
        match self.cursor_tracker.track_cursor_events(frame_id, timestamp).await {
            Ok(cursor_events) => {
                self.metrics.cursor_events += cursor_events.len() as u64;
                
                // Add cursor events to correlator
                if let Some(current_position) = self.cursor_tracker.get_current_position() {
                    self.event_correlator.add_cursor_event(current_position, frame_id);
                }
                
                // Add click events to correlator
                for click_event in self.cursor_tracker.get_click_history() {
                    self.event_correlator.add_click_event(click_event, frame_id);
                }
                
                all_events.extend(cursor_events);
            }
            Err(e) => {
                warn!("Cursor tracking failed for frame {}: {}", frame_id, e);
                self.metrics.error_count += 1;
            }
        }
        
        // 3. Add all detected events to correlator for analysis
        for event in &all_events {
            self.event_correlator.add_detected_event(event);
        }
        
        // 4. Analyze correlations between events
        let correlations = match self.event_correlator.analyze_correlations(timestamp) {
            Ok(correlations) => {
                self.metrics.correlation_events += correlations.len() as u64;
                correlations
            }
            Err(e) => {
                warn!("Event correlation failed for frame {}: {}", frame_id, e);
                self.metrics.error_count += 1;
                Vec::new()
            }
        };
        
        // 5. Store events in Parquet format
        if !all_events.is_empty() {
            if let Err(e) = self.event_writer.write_events(&all_events).await {
                error!("Failed to write events for frame {}: {}", frame_id, e);
                self.metrics.error_count += 1;
            }
        }
        
        // 6. Update metrics
        self.metrics.total_events_detected += all_events.len() as u64;
        self.metrics.processing_time_ms += start_time.elapsed().as_millis() as u64;
        self.metrics.last_update = Some(timestamp);
        
        // 7. Log comprehensive information if enabled
        if self.config.enable_comprehensive_logging {
            self.log_comprehensive_results(&all_events, &correlations, frame_id);
        }
        
        info!("Processed frame {}: {} events, {} correlations", 
              frame_id, all_events.len(), correlations.len());
        
        Ok(NavigationEventResult {
            detected_events: all_events,
            correlations,
            metrics: self.metrics.clone(),
            timestamp,
        })
    }
    
    /// Process multiple frames in batch for better performance
    pub async fn process_frame_batch(&mut self, frame_ids: &[String], timestamps: &[DateTime<Utc>]) -> Result<Vec<NavigationEventResult>> {
        if frame_ids.len() != timestamps.len() {
            return Err(IndexerError::Config("Frame IDs and timestamps length mismatch".to_string()));
        }
        
        let mut results = Vec::new();
        
        for (frame_id, timestamp) in frame_ids.iter().zip(timestamps.iter()) {
            let result = self.process_frame(frame_id, *timestamp).await?;
            results.push(result);
            
            // Add small delay to avoid overwhelming system APIs
            tokio::time::sleep(tokio::time::Duration::from_millis(self.config.processing_interval_ms)).await;
        }
        
        Ok(results)
    }
    
    /// Get comprehensive navigation statistics
    pub async fn get_navigation_statistics(&self) -> Result<NavigationStatistics> {
        let event_stats = self.event_writer.get_statistics().await?;
        let correlation_stats = self.event_correlator.get_correlation_statistics();
        
        Ok(NavigationStatistics {
            total_events: self.metrics.total_events_detected,
            navigation_events: self.metrics.navigation_events,
            cursor_events: self.metrics.cursor_events,
            correlation_events: self.metrics.correlation_events,
            error_count: self.metrics.error_count,
            average_processing_time_ms: if self.metrics.total_events_detected > 0 {
                self.metrics.processing_time_ms / self.metrics.total_events_detected
            } else {
                0
            },
            event_storage_stats: event_stats,
            correlation_patterns: correlation_stats,
            last_update: self.metrics.last_update,
        })
    }
    
    /// Query navigation events by type
    pub async fn query_navigation_events_by_type(&self, event_type: &EventType) -> Result<Vec<DetectedEvent>> {
        self.event_writer.query_by_type(event_type).await
    }
    
    /// Query navigation events by time range
    pub async fn query_navigation_events_by_time_range(
        &self,
        start_time: DateTime<Utc>,
        end_time: DateTime<Utc>,
    ) -> Result<Vec<DetectedEvent>> {
        self.event_writer.query_by_time_range(start_time, end_time).await
    }
    
    /// Get recent cursor positions for analysis
    pub fn get_recent_cursor_positions(&self) -> Vec<crate::cursor_tracker::CursorPosition> {
        self.cursor_tracker.get_position_history().iter().cloned().collect()
    }
    
    /// Get recent window states for analysis
    pub fn get_current_window_state(&self) -> Option<crate::navigation_detector::WindowState> {
        self.navigation_detector.get_current_window().cloned()
    }
    
    /// Get focus change history
    pub fn get_focus_history(&self) -> Vec<crate::navigation_detector::FocusEvent> {
        self.navigation_detector.get_focus_history().to_vec()
    }
    
    /// Flush all pending data to storage
    pub async fn flush(&mut self) -> Result<()> {
        self.event_writer.flush_batch().await?;
        info!("NavigationIntegrationService flushed all pending data");
        Ok(())
    }
    
    /// Finalize the service and close all resources
    pub async fn finalize(&mut self) -> Result<()> {
        self.event_writer.finalize().await?;
        self.navigation_detector.clear_state();
        self.cursor_tracker.clear_history();
        self.event_correlator.clear_data();
        info!("NavigationIntegrationService finalized");
        Ok(())
    }
    
    /// Update service configuration
    pub fn update_config(&mut self, config: NavigationIntegrationConfig) {
        self.navigation_detector.update_config(config.navigation_config.clone());
        self.cursor_tracker.update_config(config.cursor_config.clone());
        self.event_correlator.update_config(config.correlation_config.clone());
        self.config = config;
    }
    
    /// Log comprehensive results for debugging and analysis
    fn log_comprehensive_results(&self, events: &[DetectedEvent], correlations: &[CorrelationResult], frame_id: &str) {
        if events.is_empty() && correlations.is_empty() {
            return;
        }
        
        debug!("=== Navigation Analysis Results for Frame {} ===", frame_id);
        
        // Log events by type
        let mut event_counts: HashMap<String, usize> = HashMap::new();
        for event in events {
            let event_type = format!("{:?}", event.event_type);
            *event_counts.entry(event_type).or_insert(0) += 1;
        }
        
        for (event_type, count) in event_counts {
            debug!("  {}: {} events", event_type, count);
        }
        
        // Log correlations by type
        let mut correlation_counts: HashMap<String, usize> = HashMap::new();
        for correlation in correlations {
            let correlation_type = format!("{:?}", correlation.correlation_type);
            *correlation_counts.entry(correlation_type).or_insert(0) += 1;
        }
        
        for (correlation_type, count) in correlation_counts {
            debug!("  {}: {} correlations", correlation_type, count);
        }
        
        // Log high-confidence events
        let high_confidence_events: Vec<&DetectedEvent> = events.iter()
            .filter(|e| e.confidence > 0.8)
            .collect();
        
        if !high_confidence_events.is_empty() {
            debug!("  High-confidence events ({}):", high_confidence_events.len());
            for event in high_confidence_events {
                debug!("    {:?}: {} -> {} (confidence: {:.2})", 
                       event.event_type, 
                       event.value_from.as_deref().unwrap_or("None"),
                       event.value_to.as_deref().unwrap_or("None"),
                       event.confidence);
            }
        }
        
        debug!("=== End Navigation Analysis ===");
    }
}

/// Comprehensive navigation statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NavigationStatistics {
    pub total_events: u64,
    pub navigation_events: u64,
    pub cursor_events: u64,
    pub correlation_events: u64,
    pub error_count: u64,
    pub average_processing_time_ms: u64,
    pub event_storage_stats: crate::event_parquet_writer::EventStatistics,
    pub correlation_patterns: HashMap<String, u32>,
    pub last_update: Option<DateTime<Utc>>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    
    #[tokio::test]
    async fn test_navigation_integration_service_creation() {
        let temp_dir = TempDir::new().unwrap();
        let event_dir = temp_dir.path().join("events");
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let service = NavigationIntegrationService::new(event_dir.to_str().unwrap());
        assert!(service.is_ok());
    }
    
    #[tokio::test]
    async fn test_frame_processing() {
        let temp_dir = TempDir::new().unwrap();
        let event_dir = temp_dir.path().join("events");
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let mut service = NavigationIntegrationService::new(event_dir.to_str().unwrap()).unwrap();
        
        let result = service.process_frame("test_frame_1", Utc::now()).await;
        assert!(result.is_ok());
        
        let result = result.unwrap();
        assert_eq!(result.detected_events.len(), 0); // No events expected in test environment
        assert!(result.metrics.total_events_detected >= 0);
    }
    
    #[tokio::test]
    async fn test_batch_processing() {
        let temp_dir = TempDir::new().unwrap();
        let event_dir = temp_dir.path().join("events");
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let mut service = NavigationIntegrationService::new(event_dir.to_str().unwrap()).unwrap();
        
        let frame_ids = vec!["frame1".to_string(), "frame2".to_string(), "frame3".to_string()];
        let timestamps = vec![Utc::now(), Utc::now(), Utc::now()];
        
        let results = service.process_frame_batch(&frame_ids, &timestamps).await;
        assert!(results.is_ok());
        
        let results = results.unwrap();
        assert_eq!(results.len(), 3);
    }
    
    #[tokio::test]
    async fn test_statistics_collection() {
        let temp_dir = TempDir::new().unwrap();
        let event_dir = temp_dir.path().join("events");
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let mut service = NavigationIntegrationService::new(event_dir.to_str().unwrap()).unwrap();
        
        // Process a few frames to generate some metrics
        for i in 0..3 {
            let frame_id = format!("test_frame_{}", i);
            let _ = service.process_frame(&frame_id, Utc::now()).await;
        }
        
        let stats = service.get_navigation_statistics().await;
        assert!(stats.is_ok());
        
        let stats = stats.unwrap();
        assert!(stats.total_events >= 0);
    }
    
    #[test]
    fn test_configuration_update() {
        let temp_dir = TempDir::new().unwrap();
        let event_dir = temp_dir.path().join("events");
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let mut service = NavigationIntegrationService::new(event_dir.to_str().unwrap()).unwrap();
        
        let mut new_config = NavigationIntegrationConfig::default();
        new_config.enable_comprehensive_logging = false;
        new_config.event_batch_size = 100;
        new_config.processing_interval_ms = 200;
        
        service.update_config(new_config.clone());
        assert!(!service.config.enable_comprehensive_logging);
        assert_eq!(service.config.event_batch_size, 100);
        assert_eq!(service.config.processing_interval_ms, 200);
    }
}