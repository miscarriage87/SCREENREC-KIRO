use crate::error::{IndexerError, Result};
use crate::event_detector::{DetectedEvent, EventType};
use crate::cursor_tracker::{CursorPosition, ClickEvent, MovementTrail};
use crate::navigation_detector::{WindowState, TabState, FocusEvent};
use crate::ocr_data::OCRResult;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc, Duration};
use std::collections::{HashMap, VecDeque};
use tracing::{debug, info, warn};

/// Event correlator that links cursor actions with screen changes according to requirement 4.6
pub struct EventCorrelator {
    /// Configuration for event correlation
    config: CorrelationConfig,
    /// Recent events for correlation analysis
    event_buffer: VecDeque<CorrelationEvent>,
    /// Correlation patterns learned from data
    correlation_patterns: HashMap<String, CorrelationPattern>,
    /// Maximum buffer size to maintain
    max_buffer_size: usize,
}

/// Configuration for event correlation behavior
#[derive(Debug, Clone)]
pub struct CorrelationConfig {
    /// Maximum time window for correlating events (milliseconds)
    pub max_correlation_window_ms: i64,
    /// Minimum confidence for correlation
    pub min_correlation_confidence: f32,
    /// Enable spatial correlation (proximity-based)
    pub enable_spatial_correlation: bool,
    /// Enable temporal correlation (time-based)
    pub enable_temporal_correlation: bool,
    /// Enable causal correlation (cause-effect relationships)
    pub enable_causal_correlation: bool,
    /// Spatial correlation radius (pixels)
    pub spatial_correlation_radius: f32,
}

impl Default for CorrelationConfig {
    fn default() -> Self {
        Self {
            max_correlation_window_ms: 2000, // 2 seconds
            min_correlation_confidence: 0.6,
            enable_spatial_correlation: true,
            enable_temporal_correlation: true,
            enable_causal_correlation: true,
            spatial_correlation_radius: 50.0,
        }
    }
}

/// Unified event structure for correlation analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorrelationEvent {
    pub id: String,
    pub timestamp: DateTime<Utc>,
    pub event_type: CorrelationEventType,
    pub spatial_info: Option<SpatialInfo>,
    pub metadata: HashMap<String, String>,
    pub confidence: f32,
    pub frame_id: String,
}

/// Types of events that can be correlated
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CorrelationEventType {
    CursorMovement,
    CursorClick,
    WindowChange,
    TabChange,
    FocusChange,
    FieldChange,
    ScreenChange,
    ErrorDisplay,
    ModalAppearance,
}

/// Spatial information for correlation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpatialInfo {
    pub x: f32,
    pub y: f32,
    pub width: Option<f32>,
    pub height: Option<f32>,
    pub screen_id: Option<i32>,
}

/// Correlation pattern learned from historical data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorrelationPattern {
    pub pattern_id: String,
    pub event_sequence: Vec<CorrelationEventType>,
    pub typical_timing: Vec<i64>, // Milliseconds between events
    pub spatial_relationship: Option<SpatialRelationship>,
    pub confidence: f32,
    pub occurrence_count: u32,
}

/// Spatial relationship between correlated events
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SpatialRelationship {
    SameLocation,
    NearbyLocation(f32), // Distance in pixels
    SequentialMovement,
    NoSpatialRelation,
}

/// Result of event correlation analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorrelationResult {
    pub correlation_id: String,
    pub correlated_events: Vec<String>, // Event IDs
    pub correlation_type: CorrelationType,
    pub confidence: f32,
    pub evidence: CorrelationEvidence,
    pub timestamp: DateTime<Utc>,
}

/// Types of correlations detected
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CorrelationType {
    CursorToScreenChange,    // Cursor action caused screen change
    ScreenToCursorResponse,  // Screen change influenced cursor movement
    NavigationSequence,     // Series of navigation events
    InteractionWorkflow,    // Complete user interaction workflow
    ErrorRecovery,          // Error followed by recovery actions
}

/// Evidence supporting the correlation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorrelationEvidence {
    pub temporal_proximity: i64,    // Time difference in milliseconds
    pub spatial_proximity: Option<f32>, // Distance in pixels
    pub causal_strength: f32,       // Strength of causal relationship
    pub pattern_match: Option<String>, // Matching known pattern ID
}

impl EventCorrelator {
    /// Create a new event correlator with default configuration
    pub fn new() -> Self {
        Self::with_config(CorrelationConfig::default())
    }
    
    /// Create a new event correlator with custom configuration
    pub fn with_config(config: CorrelationConfig) -> Self {
        Self {
            config,
            event_buffer: VecDeque::new(),
            correlation_patterns: HashMap::new(),
            max_buffer_size: 1000,
        }
    }
    
    /// Add cursor event for correlation analysis
    pub fn add_cursor_event(&mut self, cursor_pos: &CursorPosition, frame_id: &str) {
        let event = CorrelationEvent {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: cursor_pos.timestamp,
            event_type: CorrelationEventType::CursorMovement,
            spatial_info: Some(SpatialInfo {
                x: cursor_pos.x,
                y: cursor_pos.y,
                width: None,
                height: None,
                screen_id: cursor_pos.screen_id,
            }),
            metadata: HashMap::new(),
            confidence: 0.9,
            frame_id: frame_id.to_string(),
        };
        
        self.add_event(event);
    }
    
    /// Add click event for correlation analysis
    pub fn add_click_event(&mut self, click: &ClickEvent, frame_id: &str) {
        let mut metadata = HashMap::new();
        metadata.insert("button".to_string(), format!("{:?}", click.button));
        metadata.insert("click_type".to_string(), format!("{:?}", click.click_type));
        metadata.insert("click_count".to_string(), click.click_count.to_string());
        
        let event = CorrelationEvent {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: click.position.timestamp,
            event_type: CorrelationEventType::CursorClick,
            spatial_info: Some(SpatialInfo {
                x: click.position.x,
                y: click.position.y,
                width: None,
                height: None,
                screen_id: click.position.screen_id,
            }),
            metadata,
            confidence: click.confidence,
            frame_id: frame_id.to_string(),
        };
        
        self.add_event(event);
    }
    
    /// Add window change event for correlation analysis
    pub fn add_window_change_event(&mut self, window_state: &WindowState, frame_id: &str) {
        let mut metadata = HashMap::new();
        metadata.insert("app_name".to_string(), window_state.app_name.clone());
        metadata.insert("window_title".to_string(), window_state.window_title.clone());
        metadata.insert("process_id".to_string(), window_state.process_id.to_string());
        
        if let Some(bundle_id) = &window_state.bundle_id {
            metadata.insert("bundle_id".to_string(), bundle_id.clone());
        }
        
        let event = CorrelationEvent {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: window_state.timestamp,
            event_type: CorrelationEventType::WindowChange,
            spatial_info: None, // Window changes don't have specific spatial coordinates
            metadata,
            confidence: 0.9,
            frame_id: frame_id.to_string(),
        };
        
        self.add_event(event);
    }
    
    /// Add tab change event for correlation analysis
    pub fn add_tab_change_event(&mut self, tab_state: &TabState, frame_id: &str) {
        let mut metadata = HashMap::new();
        metadata.insert("app_name".to_string(), tab_state.app_name.clone());
        metadata.insert("tab_title".to_string(), tab_state.tab_title.clone());
        
        if let Some(url) = &tab_state.url {
            metadata.insert("url".to_string(), url.clone());
        }
        if let Some(index) = tab_state.tab_index {
            metadata.insert("tab_index".to_string(), index.to_string());
        }
        
        let event = CorrelationEvent {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: tab_state.timestamp,
            event_type: CorrelationEventType::TabChange,
            spatial_info: None,
            metadata,
            confidence: 0.85,
            frame_id: frame_id.to_string(),
        };
        
        self.add_event(event);
    }
    
    /// Add focus change event for correlation analysis
    pub fn add_focus_change_event(&mut self, focus_event: &FocusEvent, frame_id: &str) {
        let mut metadata = HashMap::new();
        metadata.insert("to_app".to_string(), focus_event.to_app.clone());
        metadata.insert("to_bundle_id".to_string(), focus_event.to_bundle_id.clone());
        
        if let Some(from_app) = &focus_event.from_app {
            metadata.insert("from_app".to_string(), from_app.clone());
        }
        if let Some(from_bundle_id) = &focus_event.from_bundle_id {
            metadata.insert("from_bundle_id".to_string(), from_bundle_id.clone());
        }
        
        let event = CorrelationEvent {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: focus_event.timestamp,
            event_type: CorrelationEventType::FocusChange,
            spatial_info: None,
            metadata,
            confidence: focus_event.confidence,
            frame_id: frame_id.to_string(),
        };
        
        self.add_event(event);
    }
    
    /// Add detected event for correlation analysis
    pub fn add_detected_event(&mut self, detected_event: &DetectedEvent) {
        let event_type = match detected_event.event_type {
            EventType::FieldChange => CorrelationEventType::FieldChange,
            EventType::Navigation => CorrelationEventType::ScreenChange,
            EventType::ErrorDisplay => CorrelationEventType::ErrorDisplay,
            EventType::ModalAppearance => CorrelationEventType::ModalAppearance,
            _ => CorrelationEventType::ScreenChange,
        };
        
        // Try to extract spatial information from metadata
        let spatial_info = self.extract_spatial_info_from_metadata(&detected_event.metadata);
        
        let event = CorrelationEvent {
            id: detected_event.id.clone(),
            timestamp: detected_event.timestamp,
            event_type,
            spatial_info,
            metadata: detected_event.metadata.clone(),
            confidence: detected_event.confidence,
            frame_id: detected_event.evidence_frames.first().unwrap_or(&"unknown".to_string()).clone(),
        };
        
        self.add_event(event);
    }
    
    /// Analyze correlations between recent events
    pub fn analyze_correlations(&mut self, current_timestamp: DateTime<Utc>) -> Result<Vec<CorrelationResult>> {
        debug!("Analyzing correlations for {} events", self.event_buffer.len());
        
        let mut correlations = Vec::new();
        
        // Clean old events outside correlation window
        self.clean_old_events(current_timestamp);
        
        if self.event_buffer.len() < 2 {
            return Ok(correlations);
        }
        
        // Analyze different types of correlations
        if self.config.enable_temporal_correlation {
            correlations.extend(self.analyze_temporal_correlations(current_timestamp)?);
        }
        
        if self.config.enable_spatial_correlation {
            correlations.extend(self.analyze_spatial_correlations(current_timestamp)?);
        }
        
        if self.config.enable_causal_correlation {
            correlations.extend(self.analyze_causal_correlations(current_timestamp)?);
        }
        
        // Update correlation patterns based on findings
        self.update_correlation_patterns(&correlations);
        
        info!("Found {} correlations", correlations.len());
        Ok(correlations)
    }
    
    /// Analyze temporal correlations (events close in time)
    fn analyze_temporal_correlations(&self, current_timestamp: DateTime<Utc>) -> Result<Vec<CorrelationResult>> {
        let mut correlations = Vec::new();
        let events: Vec<&CorrelationEvent> = self.event_buffer.iter().collect();
        
        for i in 0..events.len() {
            for j in (i + 1)..events.len() {
                let event1 = events[i];
                let event2 = events[j];
                
                let time_diff = (event2.timestamp - event1.timestamp).num_milliseconds().abs();
                
                if time_diff <= self.config.max_correlation_window_ms {
                    // Check for meaningful temporal patterns
                    if let Some(correlation) = self.evaluate_temporal_correlation(event1, event2, time_diff) {
                        if correlation.confidence >= self.config.min_correlation_confidence {
                            correlations.push(correlation);
                        }
                    }
                }
            }
        }
        
        Ok(correlations)
    }
    
    /// Analyze spatial correlations (events close in space)
    fn analyze_spatial_correlations(&self, current_timestamp: DateTime<Utc>) -> Result<Vec<CorrelationResult>> {
        let mut correlations = Vec::new();
        let events: Vec<&CorrelationEvent> = self.event_buffer.iter().collect();
        
        for i in 0..events.len() {
            for j in (i + 1)..events.len() {
                let event1 = events[i];
                let event2 = events[j];
                
                if let (Some(spatial1), Some(spatial2)) = (&event1.spatial_info, &event2.spatial_info) {
                    let distance = self.calculate_spatial_distance(spatial1, spatial2);
                    
                    if distance <= self.config.spatial_correlation_radius {
                        if let Some(correlation) = self.evaluate_spatial_correlation(event1, event2, distance) {
                            if correlation.confidence >= self.config.min_correlation_confidence {
                                correlations.push(correlation);
                            }
                        }
                    }
                }
            }
        }
        
        Ok(correlations)
    }
    
    /// Analyze causal correlations (cause-effect relationships)
    fn analyze_causal_correlations(&self, current_timestamp: DateTime<Utc>) -> Result<Vec<CorrelationResult>> {
        let mut correlations = Vec::new();
        let events: Vec<&CorrelationEvent> = self.event_buffer.iter().collect();
        
        // Look for common causal patterns
        for i in 0..events.len().saturating_sub(1) {
            let event1 = events[i];
            let event2 = events[i + 1];
            
            if let Some(correlation) = self.evaluate_causal_correlation(event1, event2) {
                if correlation.confidence >= self.config.min_correlation_confidence {
                    correlations.push(correlation);
                }
            }
        }
        
        Ok(correlations)
    }
    
    /// Evaluate temporal correlation between two events
    fn evaluate_temporal_correlation(&self, event1: &CorrelationEvent, event2: &CorrelationEvent, time_diff: i64) -> Option<CorrelationResult> {
        // Look for meaningful temporal patterns
        let correlation_type = match (&event1.event_type, &event2.event_type) {
            (CorrelationEventType::CursorClick, CorrelationEventType::ScreenChange) => CorrelationType::CursorToScreenChange,
            (CorrelationEventType::CursorClick, CorrelationEventType::WindowChange) => CorrelationType::CursorToScreenChange,
            (CorrelationEventType::CursorClick, CorrelationEventType::TabChange) => CorrelationType::CursorToScreenChange,
            (CorrelationEventType::WindowChange, CorrelationEventType::CursorMovement) => CorrelationType::ScreenToCursorResponse,
            (CorrelationEventType::ErrorDisplay, CorrelationEventType::CursorClick) => CorrelationType::ErrorRecovery,
            _ => return None,
        };
        
        // Calculate confidence based on temporal proximity
        let temporal_confidence = 1.0 - (time_diff as f32 / self.config.max_correlation_window_ms as f32);
        let base_confidence = (event1.confidence + event2.confidence) / 2.0;
        let final_confidence = (temporal_confidence * 0.6 + base_confidence * 0.4).clamp(0.0, 1.0);
        
        Some(CorrelationResult {
            correlation_id: uuid::Uuid::new_v4().to_string(),
            correlated_events: vec![event1.id.clone(), event2.id.clone()],
            correlation_type,
            confidence: final_confidence,
            evidence: CorrelationEvidence {
                temporal_proximity: time_diff,
                spatial_proximity: None,
                causal_strength: 0.7, // Default causal strength for temporal correlations
                pattern_match: None,
            },
            timestamp: Utc::now(),
        })
    }
    
    /// Evaluate spatial correlation between two events
    fn evaluate_spatial_correlation(&self, event1: &CorrelationEvent, event2: &CorrelationEvent, distance: f32) -> Option<CorrelationResult> {
        // Spatial correlations are most meaningful for cursor and screen change events
        let correlation_type = match (&event1.event_type, &event2.event_type) {
            (CorrelationEventType::CursorClick, CorrelationEventType::FieldChange) => CorrelationType::CursorToScreenChange,
            (CorrelationEventType::CursorMovement, CorrelationEventType::FieldChange) => CorrelationType::CursorToScreenChange,
            _ => return None,
        };
        
        // Calculate confidence based on spatial proximity
        let spatial_confidence = 1.0 - (distance / self.config.spatial_correlation_radius);
        let base_confidence = (event1.confidence + event2.confidence) / 2.0;
        let final_confidence = (spatial_confidence * 0.7 + base_confidence * 0.3).clamp(0.0, 1.0);
        
        Some(CorrelationResult {
            correlation_id: uuid::Uuid::new_v4().to_string(),
            correlated_events: vec![event1.id.clone(), event2.id.clone()],
            correlation_type,
            confidence: final_confidence,
            evidence: CorrelationEvidence {
                temporal_proximity: (event2.timestamp - event1.timestamp).num_milliseconds().abs(),
                spatial_proximity: Some(distance),
                causal_strength: 0.8, // Higher causal strength for spatial correlations
                pattern_match: None,
            },
            timestamp: Utc::now(),
        })
    }
    
    /// Evaluate causal correlation between two events
    fn evaluate_causal_correlation(&self, event1: &CorrelationEvent, event2: &CorrelationEvent) -> Option<CorrelationResult> {
        // Define causal relationships based on event types and timing
        let (correlation_type, causal_strength) = match (&event1.event_type, &event2.event_type) {
            (CorrelationEventType::CursorClick, CorrelationEventType::WindowChange) => (CorrelationType::CursorToScreenChange, 0.9),
            (CorrelationEventType::CursorClick, CorrelationEventType::TabChange) => (CorrelationType::CursorToScreenChange, 0.85),
            (CorrelationEventType::CursorClick, CorrelationEventType::FieldChange) => (CorrelationType::CursorToScreenChange, 0.8),
            (CorrelationEventType::ErrorDisplay, CorrelationEventType::CursorMovement) => (CorrelationType::ErrorRecovery, 0.7),
            (CorrelationEventType::ModalAppearance, CorrelationEventType::CursorClick) => (CorrelationType::ErrorRecovery, 0.75),
            _ => return None,
        };
        
        let time_diff = (event2.timestamp - event1.timestamp).num_milliseconds().abs();
        
        // Causal relationships should have reasonable timing
        if time_diff > self.config.max_correlation_window_ms {
            return None;
        }
        
        let temporal_factor = 1.0 - (time_diff as f32 / self.config.max_correlation_window_ms as f32);
        let base_confidence = (event1.confidence + event2.confidence) / 2.0;
        let final_confidence = (causal_strength * 0.5 + temporal_factor * 0.3 + base_confidence * 0.2).clamp(0.0, 1.0);
        
        Some(CorrelationResult {
            correlation_id: uuid::Uuid::new_v4().to_string(),
            correlated_events: vec![event1.id.clone(), event2.id.clone()],
            correlation_type,
            confidence: final_confidence,
            evidence: CorrelationEvidence {
                temporal_proximity: time_diff,
                spatial_proximity: None,
                causal_strength,
                pattern_match: None,
            },
            timestamp: Utc::now(),
        })
    }
    
    /// Add event to buffer and maintain size
    fn add_event(&mut self, event: CorrelationEvent) {
        self.event_buffer.push_back(event);
        
        // Maintain buffer size
        while self.event_buffer.len() > self.max_buffer_size {
            self.event_buffer.pop_front();
        }
    }
    
    /// Clean events outside correlation window
    fn clean_old_events(&mut self, current_timestamp: DateTime<Utc>) {
        let cutoff_time = current_timestamp - Duration::milliseconds(self.config.max_correlation_window_ms);
        
        while let Some(front_event) = self.event_buffer.front() {
            if front_event.timestamp < cutoff_time {
                self.event_buffer.pop_front();
            } else {
                break;
            }
        }
    }
    
    /// Calculate spatial distance between two spatial info objects
    fn calculate_spatial_distance(&self, spatial1: &SpatialInfo, spatial2: &SpatialInfo) -> f32 {
        let dx = spatial2.x - spatial1.x;
        let dy = spatial2.y - spatial1.y;
        (dx * dx + dy * dy).sqrt()
    }
    
    /// Extract spatial information from event metadata
    fn extract_spatial_info_from_metadata(&self, metadata: &HashMap<String, String>) -> Option<SpatialInfo> {
        let x = metadata.get("roi_x")?.parse().ok()?;
        let y = metadata.get("roi_y")?.parse().ok()?;
        let width = metadata.get("roi_width")?.parse().ok();
        let height = metadata.get("roi_height")?.parse().ok();
        
        Some(SpatialInfo {
            x,
            y,
            width,
            height,
            screen_id: None,
        })
    }
    
    /// Update correlation patterns based on new findings
    fn update_correlation_patterns(&mut self, correlations: &[CorrelationResult]) {
        for correlation in correlations {
            // Create or update pattern based on correlation type
            let pattern_key = format!("{:?}", correlation.correlation_type);
            
            let pattern = self.correlation_patterns.entry(pattern_key.clone()).or_insert_with(|| {
                CorrelationPattern {
                    pattern_id: pattern_key,
                    event_sequence: Vec::new(),
                    typical_timing: Vec::new(),
                    spatial_relationship: None,
                    confidence: 0.0,
                    occurrence_count: 0,
                }
            });
            
            // Update pattern statistics
            pattern.occurrence_count += 1;
            pattern.confidence = (pattern.confidence * (pattern.occurrence_count - 1) as f32 + correlation.confidence) / pattern.occurrence_count as f32;
            
            // Update timing information
            pattern.typical_timing.push(correlation.evidence.temporal_proximity);
            
            // Keep only recent timing data
            if pattern.typical_timing.len() > 100 {
                pattern.typical_timing.remove(0);
            }
        }
    }
    
    /// Get correlation statistics
    pub fn get_correlation_statistics(&self) -> HashMap<String, u32> {
        self.correlation_patterns.iter()
            .map(|(pattern_id, pattern)| (pattern_id.clone(), pattern.occurrence_count))
            .collect()
    }
    
    /// Get recent events in buffer
    pub fn get_recent_events(&self) -> &VecDeque<CorrelationEvent> {
        &self.event_buffer
    }
    
    /// Clear all correlation data
    pub fn clear_data(&mut self) {
        self.event_buffer.clear();
        self.correlation_patterns.clear();
    }
    
    /// Update configuration
    pub fn update_config(&mut self, config: CorrelationConfig) {
        self.config = config;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_event_correlator_creation() {
        let correlator = EventCorrelator::new();
        assert!(correlator.event_buffer.is_empty());
        assert!(correlator.correlation_patterns.is_empty());
    }
    
    #[test]
    fn test_spatial_distance_calculation() {
        let correlator = EventCorrelator::new();
        
        let spatial1 = SpatialInfo {
            x: 0.0,
            y: 0.0,
            width: None,
            height: None,
            screen_id: None,
        };
        
        let spatial2 = SpatialInfo {
            x: 3.0,
            y: 4.0,
            width: None,
            height: None,
            screen_id: None,
        };
        
        let distance = correlator.calculate_spatial_distance(&spatial1, &spatial2);
        assert_eq!(distance, 5.0); // 3-4-5 triangle
    }
    
    #[test]
    fn test_event_buffer_management() {
        let mut correlator = EventCorrelator::new();
        correlator.max_buffer_size = 3;
        
        // Add events beyond buffer size
        for i in 0..5 {
            let event = CorrelationEvent {
                id: format!("event_{}", i),
                timestamp: Utc::now(),
                event_type: CorrelationEventType::CursorMovement,
                spatial_info: None,
                metadata: HashMap::new(),
                confidence: 0.8,
                frame_id: "test_frame".to_string(),
            };
            correlator.add_event(event);
        }
        
        // Should only keep the last 3 events
        assert_eq!(correlator.event_buffer.len(), 3);
        assert_eq!(correlator.event_buffer[0].id, "event_2");
        assert_eq!(correlator.event_buffer[2].id, "event_4");
    }
    
    #[test]
    fn test_correlation_event_creation() {
        let cursor_pos = CursorPosition {
            x: 100.0,
            y: 200.0,
            timestamp: Utc::now(),
            screen_id: Some(1),
        };
        
        let mut correlator = EventCorrelator::new();
        correlator.add_cursor_event(&cursor_pos, "test_frame");
        
        assert_eq!(correlator.event_buffer.len(), 1);
        let event = &correlator.event_buffer[0];
        assert_eq!(event.event_type, CorrelationEventType::CursorMovement);
        assert!(event.spatial_info.is_some());
        
        let spatial = event.spatial_info.as_ref().unwrap();
        assert_eq!(spatial.x, 100.0);
        assert_eq!(spatial.y, 200.0);
    }
    
    #[test]
    fn test_old_event_cleanup() {
        let mut correlator = EventCorrelator::new();
        correlator.config.max_correlation_window_ms = 1000; // 1 second
        
        let old_time = Utc::now() - Duration::milliseconds(2000);
        let recent_time = Utc::now();
        
        // Add old event
        let old_event = CorrelationEvent {
            id: "old_event".to_string(),
            timestamp: old_time,
            event_type: CorrelationEventType::CursorMovement,
            spatial_info: None,
            metadata: HashMap::new(),
            confidence: 0.8,
            frame_id: "test_frame".to_string(),
        };
        correlator.add_event(old_event);
        
        // Add recent event
        let recent_event = CorrelationEvent {
            id: "recent_event".to_string(),
            timestamp: recent_time,
            event_type: CorrelationEventType::CursorClick,
            spatial_info: None,
            metadata: HashMap::new(),
            confidence: 0.8,
            frame_id: "test_frame".to_string(),
        };
        correlator.add_event(recent_event);
        
        assert_eq!(correlator.event_buffer.len(), 2);
        
        // Clean old events
        correlator.clean_old_events(Utc::now());
        
        // Should only keep recent event
        assert_eq!(correlator.event_buffer.len(), 1);
        assert_eq!(correlator.event_buffer[0].id, "recent_event");
    }
}