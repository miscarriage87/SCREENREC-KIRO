use crate::error::{IndexerError, Result};
use crate::event_detector::{DetectedEvent, EventType};
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use std::collections::{HashMap, VecDeque};
use std::process::Command;
use tracing::{debug, info, warn, error};

/// Cursor tracker for mouse movements and click events according to requirements 4.2 and 4.3
pub struct CursorTracker {
    /// Configuration for cursor tracking
    config: CursorTrackingConfig,
    /// Recent cursor positions for movement trail analysis
    position_history: VecDeque<CursorPosition>,
    /// Recent click events for pattern analysis
    click_history: VecDeque<ClickEvent>,
    /// Maximum history size to maintain
    max_history_size: usize,
    /// Last recorded cursor position
    last_position: Option<CursorPosition>,
    /// Movement trail analyzer
    trail_analyzer: MovementTrailAnalyzer,
}

/// Configuration for cursor tracking behavior
#[derive(Debug, Clone)]
pub struct CursorTrackingConfig {
    /// Enable cursor position tracking
    pub enable_position_tracking: bool,
    /// Enable click event detection
    pub enable_click_detection: bool,
    /// Enable movement trail analysis
    pub enable_trail_analysis: bool,
    /// Minimum movement distance to record (pixels)
    pub min_movement_distance: f32,
    /// Maximum time between positions for trail analysis (milliseconds)
    pub max_trail_gap_ms: u64,
    /// Confidence threshold for cursor events
    pub min_confidence: f32,
    /// Sampling interval for cursor position (milliseconds)
    pub sampling_interval_ms: u64,
}

impl Default for CursorTrackingConfig {
    fn default() -> Self {
        Self {
            enable_position_tracking: true,
            enable_click_detection: true,
            enable_trail_analysis: true,
            min_movement_distance: 5.0,
            max_trail_gap_ms: 1000,
            min_confidence: 0.8,
            sampling_interval_ms: 100,
        }
    }
}

/// Represents a cursor position at a specific time
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CursorPosition {
    pub x: f32,
    pub y: f32,
    pub timestamp: DateTime<Utc>,
    pub screen_id: Option<i32>,
}

/// Represents a mouse click event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClickEvent {
    pub position: CursorPosition,
    pub button: MouseButton,
    pub click_type: ClickType,
    pub click_count: i32, // For double-clicks, triple-clicks
    pub modifiers: Vec<KeyModifier>,
    pub confidence: f32,
}

/// Mouse button types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum MouseButton {
    Left,
    Right,
    Middle,
    Other(i32),
}

/// Click types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ClickType {
    Press,
    Release,
    Drag,
    Scroll,
}

/// Keyboard modifiers during click
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum KeyModifier {
    Command,
    Option,
    Control,
    Shift,
    Function,
}

/// Movement trail analysis results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MovementTrail {
    pub start_position: CursorPosition,
    pub end_position: CursorPosition,
    pub total_distance: f32,
    pub duration_ms: i64,
    pub average_speed: f32, // pixels per second
    pub direction_changes: i32,
    pub trail_type: TrailType,
    pub confidence: f32,
}

/// Types of movement trails
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum TrailType {
    Linear,      // Straight line movement
    Curved,      // Smooth curved movement
    Erratic,     // Random or jittery movement
    Circular,    // Circular or arc movement
    Stationary,  // Minimal movement
}

/// Analyzes cursor movement patterns
struct MovementTrailAnalyzer {
    /// Minimum points needed for trail analysis
    min_points: usize,
    /// Smoothing factor for trail analysis
    smoothing_factor: f32,
}

impl MovementTrailAnalyzer {
    fn new() -> Self {
        Self {
            min_points: 3,
            smoothing_factor: 0.8,
        }
    }
    
    /// Analyze a sequence of cursor positions to determine movement pattern
    fn analyze_trail(&self, positions: &[CursorPosition]) -> Option<MovementTrail> {
        if positions.len() < self.min_points {
            return None;
        }
        
        let start_position = positions.first()?.clone();
        let end_position = positions.last()?.clone();
        
        // Calculate total distance
        let total_distance = self.calculate_total_distance(positions);
        
        // Calculate duration
        let duration_ms = end_position.timestamp
            .signed_duration_since(start_position.timestamp)
            .num_milliseconds();
        
        if duration_ms <= 0 {
            return None;
        }
        
        // Calculate average speed (pixels per second)
        let average_speed = (total_distance * 1000.0) / duration_ms as f32;
        
        // Count direction changes
        let direction_changes = self.count_direction_changes(positions);
        
        // Determine trail type
        let trail_type = self.classify_trail_type(positions, total_distance, direction_changes);
        
        // Calculate confidence based on data quality
        let confidence = self.calculate_trail_confidence(positions, total_distance, duration_ms);
        
        Some(MovementTrail {
            start_position,
            end_position,
            total_distance,
            duration_ms,
            average_speed,
            direction_changes,
            trail_type,
            confidence,
        })
    }
    
    fn calculate_total_distance(&self, positions: &[CursorPosition]) -> f32 {
        let mut total_distance = 0.0;
        
        for i in 1..positions.len() {
            let prev = &positions[i - 1];
            let curr = &positions[i];
            
            let dx = curr.x - prev.x;
            let dy = curr.y - prev.y;
            total_distance += (dx * dx + dy * dy).sqrt();
        }
        
        total_distance
    }
    
    fn count_direction_changes(&self, positions: &[CursorPosition]) -> i32 {
        if positions.len() < 3 {
            return 0;
        }
        
        let mut direction_changes = 0;
        let mut prev_direction: Option<f32> = None;
        
        for i in 1..positions.len() {
            let prev = &positions[i - 1];
            let curr = &positions[i];
            
            let dx = curr.x - prev.x;
            let dy = curr.y - prev.y;
            
            if dx.abs() > 1.0 || dy.abs() > 1.0 {
                let current_direction = dy.atan2(dx);
                
                if let Some(prev_dir) = prev_direction {
                    let angle_diff = (current_direction - prev_dir).abs();
                    let normalized_diff = if angle_diff > std::f32::consts::PI {
                        2.0 * std::f32::consts::PI - angle_diff
                    } else {
                        angle_diff
                    };
                    
                    // Consider it a direction change if angle difference > 30 degrees
                    if normalized_diff > std::f32::consts::PI / 6.0 {
                        direction_changes += 1;
                    }
                }
                
                prev_direction = Some(current_direction);
            }
        }
        
        direction_changes
    }
    
    fn classify_trail_type(&self, positions: &[CursorPosition], total_distance: f32, direction_changes: i32) -> TrailType {
        if total_distance < 10.0 {
            return TrailType::Stationary;
        }
        
        let num_points = positions.len() as f32;
        let change_ratio = direction_changes as f32 / num_points;
        
        // Calculate linearity (ratio of direct distance to total distance)
        let direct_distance = {
            let start = positions.first().unwrap();
            let end = positions.last().unwrap();
            let dx = end.x - start.x;
            let dy = end.y - start.y;
            (dx * dx + dy * dy).sqrt()
        };
        
        let linearity = if total_distance > 0.0 {
            direct_distance / total_distance
        } else {
            0.0
        };
        
        // Classify based on linearity and direction changes
        if linearity > 0.9 && change_ratio < 0.1 {
            TrailType::Linear
        } else if change_ratio > 0.5 {
            TrailType::Erratic
        } else if self.is_circular_movement(positions) {
            TrailType::Circular
        } else {
            TrailType::Curved
        }
    }
    
    fn is_circular_movement(&self, positions: &[CursorPosition]) -> bool {
        if positions.len() < 8 {
            return false;
        }
        
        // Simple heuristic: check if the path forms a rough circle
        // by comparing the area enclosed by the path to a circle with the same perimeter
        let center_x = positions.iter().map(|p| p.x).sum::<f32>() / positions.len() as f32;
        let center_y = positions.iter().map(|p| p.y).sum::<f32>() / positions.len() as f32;
        
        // Calculate average distance from center
        let avg_radius = positions.iter()
            .map(|p| {
                let dx = p.x - center_x;
                let dy = p.y - center_y;
                (dx * dx + dy * dy).sqrt()
            })
            .sum::<f32>() / positions.len() as f32;
        
        // Calculate variance in distance from center
        let radius_variance = positions.iter()
            .map(|p| {
                let dx = p.x - center_x;
                let dy = p.y - center_y;
                let radius = (dx * dx + dy * dy).sqrt();
                (radius - avg_radius).powi(2)
            })
            .sum::<f32>() / positions.len() as f32;
        
        // If variance is low relative to radius, it might be circular
        avg_radius > 20.0 && radius_variance < (avg_radius * 0.3).powi(2)
    }
    
    fn calculate_trail_confidence(&self, positions: &[CursorPosition], total_distance: f32, duration_ms: i64) -> f32 {
        let mut confidence = 1.0;
        
        // Reduce confidence for very short trails
        if positions.len() < 5 {
            confidence *= 0.7;
        }
        
        // Reduce confidence for very short distances
        if total_distance < 20.0 {
            confidence *= 0.8;
        }
        
        // Reduce confidence for very short durations
        if duration_ms < 100 {
            confidence *= 0.6;
        }
        
        // Check for temporal consistency
        let mut temporal_gaps = 0;
        for i in 1..positions.len() {
            let gap = positions[i].timestamp
                .signed_duration_since(positions[i - 1].timestamp)
                .num_milliseconds();
            
            if gap > 500 {
                temporal_gaps += 1;
            }
        }
        
        if temporal_gaps > 0 {
            confidence *= 0.9_f32.powi(temporal_gaps);
        }
        
        confidence.clamp(0.0, 1.0)
    }
}

impl CursorTracker {
    /// Create a new cursor tracker with default configuration
    pub fn new() -> Self {
        Self::with_config(CursorTrackingConfig::default())
    }
    
    /// Create a new cursor tracker with custom configuration
    pub fn with_config(config: CursorTrackingConfig) -> Self {
        Self {
            config,
            position_history: VecDeque::new(),
            click_history: VecDeque::new(),
            max_history_size: 1000,
            last_position: None,
            trail_analyzer: MovementTrailAnalyzer::new(),
        }
    }
    
    /// Track cursor events and detect interactions
    pub async fn track_cursor_events(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        debug!("Tracking cursor events for frame {}", frame_id);
        
        let mut events = Vec::new();
        
        // Track cursor position
        if self.config.enable_position_tracking {
            if let Ok(position_events) = self.track_cursor_position(frame_id, timestamp).await {
                events.extend(position_events);
            }
        }
        
        // Detect click events
        if self.config.enable_click_detection {
            if let Ok(click_events) = self.detect_click_events(frame_id, timestamp).await {
                events.extend(click_events);
            }
        }
        
        // Analyze movement trails
        if self.config.enable_trail_analysis {
            if let Ok(trail_events) = self.analyze_movement_trails(frame_id, timestamp).await {
                events.extend(trail_events);
            }
        }
        
        info!("Detected {} cursor events for frame {}", events.len(), frame_id);
        Ok(events)
    }
    
    /// Track cursor position changes
    async fn track_cursor_position(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        let current_position = self.get_current_cursor_position().await?;
        let mut events = Vec::new();
        
        // Check if cursor has moved significantly
        if let Some(last_pos) = &self.last_position {
            let distance = self.calculate_distance(last_pos, &current_position);
            
            if distance >= self.config.min_movement_distance {
                // Record significant movement
                let event = DetectedEvent {
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp,
                    event_type: EventType::Navigation, // Cursor movement is a form of navigation
                    target: "cursor_movement".to_string(),
                    value_from: Some(format!("{:.1},{:.1}", last_pos.x, last_pos.y)),
                    value_to: Some(format!("{:.1},{:.1}", current_position.x, current_position.y)),
                    confidence: self.config.min_confidence,
                    evidence_frames: vec![frame_id.to_string()],
                    metadata: self.create_position_metadata(&current_position, last_pos, distance),
                };
                
                events.push(event);
                debug!("Detected cursor movement: distance {:.1}px", distance);
            }
        }
        
        // Add to position history
        self.position_history.push_back(current_position.clone());
        
        // Maintain history size
        while self.position_history.len() > self.max_history_size {
            self.position_history.pop_front();
        }
        
        // Update last position
        self.last_position = Some(current_position);
        
        Ok(events)
    }
    
    /// Detect mouse click events
    async fn detect_click_events(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        // Note: This is a simplified implementation
        // In a real system, we would need to hook into system events or use accessibility APIs
        // For now, we'll simulate click detection based on cursor position changes and timing
        
        let mut events = Vec::new();
        
        // Check for potential click patterns in recent position history
        if let Some(click_event) = self.detect_click_pattern(timestamp).await? {
            let event = DetectedEvent {
                id: uuid::Uuid::new_v4().to_string(),
                timestamp,
                event_type: EventType::Navigation, // Clicks are navigation events
                target: format!("click_{:.0}_{:.0}", click_event.position.x, click_event.position.y),
                value_from: None,
                value_to: Some(format!("{:?}", click_event.button)),
                confidence: click_event.confidence,
                evidence_frames: vec![frame_id.to_string()],
                metadata: self.create_click_metadata(&click_event),
            };
            
            events.push(event);
            
            // Add to click history
            self.click_history.push_back(click_event);
            
            // Maintain click history size
            while self.click_history.len() > self.max_history_size / 10 {
                self.click_history.pop_front();
            }
            
            debug!("Detected click event at ({:.1}, {:.1})", 
                   self.click_history.back().unwrap().position.x,
                   self.click_history.back().unwrap().position.y);
        }
        
        Ok(events)
    }
    
    /// Analyze movement trails for patterns
    async fn analyze_movement_trails(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        let mut events = Vec::new();
        
        // Analyze recent position history for movement patterns
        if self.position_history.len() >= 5 {
            // Get recent positions within the trail gap time
            let cutoff_time = timestamp - chrono::Duration::milliseconds(self.config.max_trail_gap_ms as i64);
            let recent_positions: Vec<CursorPosition> = self.position_history
                .iter()
                .filter(|pos| pos.timestamp >= cutoff_time)
                .cloned()
                .collect();
            
            if let Some(trail) = self.trail_analyzer.analyze_trail(&recent_positions) {
                if trail.confidence >= self.config.min_confidence * 0.8 {
                    let event = DetectedEvent {
                        id: uuid::Uuid::new_v4().to_string(),
                        timestamp,
                        event_type: EventType::Navigation,
                        target: format!("movement_trail_{:?}", trail.trail_type),
                        value_from: Some(format!("{:.1},{:.1}", trail.start_position.x, trail.start_position.y)),
                        value_to: Some(format!("{:.1},{:.1}", trail.end_position.x, trail.end_position.y)),
                        confidence: trail.confidence,
                        evidence_frames: vec![frame_id.to_string()],
                        metadata: self.create_trail_metadata(&trail),
                    };
                    
                    events.push(event);
                    debug!("Detected movement trail: {:?}, distance: {:.1}px", 
                           trail.trail_type, trail.total_distance);
                }
            }
        }
        
        Ok(events)
    }
    
    /// Get current cursor position using macOS APIs
    async fn get_current_cursor_position(&self) -> Result<CursorPosition> {
        let script = r#"
            tell application "System Events"
                set mouseLocation to (get the mouse location)
                set mouseX to item 1 of mouseLocation
                set mouseY to item 2 of mouseLocation
                return mouseX & "," & mouseY
            end tell
        "#;
        
        let output = Command::new("osascript")
            .arg("-e")
            .arg(script)
            .output()
            .map_err(|e| IndexerError::CursorTracking(format!("Failed to get cursor position: {}", e)))?;
        
        if !output.status.success() {
            return Err(IndexerError::CursorTracking(
                format!("AppleScript failed: {}", String::from_utf8_lossy(&output.stderr))
            ));
        }
        
        let result = String::from_utf8_lossy(&output.stdout);
        let coords: Vec<&str> = result.trim().split(',').collect();
        
        if coords.len() != 2 {
            return Err(IndexerError::CursorTracking("Invalid cursor position response".to_string()));
        }
        
        let x = coords[0].parse::<f32>()
            .map_err(|_| IndexerError::CursorTracking("Invalid X coordinate".to_string()))?;
        let y = coords[1].parse::<f32>()
            .map_err(|_| IndexerError::CursorTracking("Invalid Y coordinate".to_string()))?;
        
        Ok(CursorPosition {
            x,
            y,
            timestamp: Utc::now(),
            screen_id: None, // Could be enhanced to detect which screen
        })
    }
    
    /// Detect click patterns from position history
    async fn detect_click_pattern(&self, timestamp: DateTime<Utc>) -> Result<Option<ClickEvent>> {
        // Simplified click detection based on position stability
        // In a real implementation, this would use system event hooks
        
        if self.position_history.len() < 3 {
            return Ok(None);
        }
        
        // Look for periods of cursor stability (potential clicks)
        let recent_positions: Vec<&CursorPosition> = self.position_history
            .iter()
            .rev()
            .take(5)
            .collect();
        
        // Check if cursor has been relatively stable
        let mut max_distance: f32 = 0.0;
        let center_pos = recent_positions[0];
        
        for pos in &recent_positions[1..] {
            let distance = self.calculate_distance(center_pos, pos);
            max_distance = max_distance.max(distance);
        }
        
        // If cursor has been stable (small movements) and then moved, it might indicate a click
        if max_distance < 5.0 && recent_positions.len() >= 3 {
            // Check if there was recent movement before stability
            if let Some(earlier_pos) = self.position_history.iter().rev().nth(6) {
                let approach_distance = self.calculate_distance(earlier_pos, center_pos);
                
                if approach_distance > 10.0 {
                    // Pattern suggests: movement -> stability -> (potential click)
                    return Ok(Some(ClickEvent {
                        position: center_pos.clone(),
                        button: MouseButton::Left, // Default assumption
                        click_type: ClickType::Press,
                        click_count: 1,
                        modifiers: Vec::new(),
                        confidence: self.config.min_confidence * 0.7, // Lower confidence for inferred clicks
                    }));
                }
            }
        }
        
        Ok(None)
    }
    
    /// Calculate distance between two cursor positions
    fn calculate_distance(&self, pos1: &CursorPosition, pos2: &CursorPosition) -> f32 {
        let dx = pos2.x - pos1.x;
        let dy = pos2.y - pos1.y;
        (dx * dx + dy * dy).sqrt()
    }
    
    /// Create metadata for position events
    fn create_position_metadata(&self, current: &CursorPosition, previous: &CursorPosition, distance: f32) -> HashMap<String, String> {
        let mut metadata = HashMap::new();
        metadata.insert("event_type".to_string(), "cursor_movement".to_string());
        metadata.insert("distance".to_string(), distance.to_string());
        metadata.insert("current_x".to_string(), current.x.to_string());
        metadata.insert("current_y".to_string(), current.y.to_string());
        metadata.insert("previous_x".to_string(), previous.x.to_string());
        metadata.insert("previous_y".to_string(), previous.y.to_string());
        
        if let Some(screen_id) = current.screen_id {
            metadata.insert("screen_id".to_string(), screen_id.to_string());
        }
        
        metadata
    }
    
    /// Create metadata for click events
    fn create_click_metadata(&self, click: &ClickEvent) -> HashMap<String, String> {
        let mut metadata = HashMap::new();
        metadata.insert("event_type".to_string(), "mouse_click".to_string());
        metadata.insert("button".to_string(), format!("{:?}", click.button));
        metadata.insert("click_type".to_string(), format!("{:?}", click.click_type));
        metadata.insert("click_count".to_string(), click.click_count.to_string());
        metadata.insert("x".to_string(), click.position.x.to_string());
        metadata.insert("y".to_string(), click.position.y.to_string());
        
        if !click.modifiers.is_empty() {
            let modifiers_str = click.modifiers.iter()
                .map(|m| format!("{:?}", m))
                .collect::<Vec<_>>()
                .join(",");
            metadata.insert("modifiers".to_string(), modifiers_str);
        }
        
        metadata
    }
    
    /// Create metadata for movement trail events
    fn create_trail_metadata(&self, trail: &MovementTrail) -> HashMap<String, String> {
        let mut metadata = HashMap::new();
        metadata.insert("event_type".to_string(), "movement_trail".to_string());
        metadata.insert("trail_type".to_string(), format!("{:?}", trail.trail_type));
        metadata.insert("total_distance".to_string(), trail.total_distance.to_string());
        metadata.insert("duration_ms".to_string(), trail.duration_ms.to_string());
        metadata.insert("average_speed".to_string(), trail.average_speed.to_string());
        metadata.insert("direction_changes".to_string(), trail.direction_changes.to_string());
        metadata.insert("start_x".to_string(), trail.start_position.x.to_string());
        metadata.insert("start_y".to_string(), trail.start_position.y.to_string());
        metadata.insert("end_x".to_string(), trail.end_position.x.to_string());
        metadata.insert("end_y".to_string(), trail.end_position.y.to_string());
        
        metadata
    }
    
    /// Get recent cursor positions
    pub fn get_position_history(&self) -> &VecDeque<CursorPosition> {
        &self.position_history
    }
    
    /// Get recent click events
    pub fn get_click_history(&self) -> &VecDeque<ClickEvent> {
        &self.click_history
    }
    
    /// Get current cursor position (if available)
    pub fn get_current_position(&self) -> Option<&CursorPosition> {
        self.last_position.as_ref()
    }
    
    /// Clear all tracking history
    pub fn clear_history(&mut self) {
        self.position_history.clear();
        self.click_history.clear();
        self.last_position = None;
    }
    
    /// Update configuration
    pub fn update_config(&mut self, config: CursorTrackingConfig) {
        self.config = config;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_cursor_tracker_creation() {
        let tracker = CursorTracker::new();
        assert!(tracker.position_history.is_empty());
        assert!(tracker.click_history.is_empty());
        assert!(tracker.last_position.is_none());
    }
    
    #[test]
    fn test_distance_calculation() {
        let tracker = CursorTracker::new();
        
        let pos1 = CursorPosition {
            x: 0.0,
            y: 0.0,
            timestamp: Utc::now(),
            screen_id: None,
        };
        
        let pos2 = CursorPosition {
            x: 3.0,
            y: 4.0,
            timestamp: Utc::now(),
            screen_id: None,
        };
        
        let distance = tracker.calculate_distance(&pos1, &pos2);
        assert_eq!(distance, 5.0); // 3-4-5 triangle
    }
    
    #[test]
    fn test_movement_trail_analyzer() {
        let analyzer = MovementTrailAnalyzer::new();
        
        // Create a linear movement pattern
        let positions = vec![
            CursorPosition { x: 0.0, y: 0.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 10.0, y: 0.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 20.0, y: 0.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 30.0, y: 0.0, timestamp: Utc::now(), screen_id: None },
        ];
        
        let trail = analyzer.analyze_trail(&positions);
        assert!(trail.is_some());
        
        let trail = trail.unwrap();
        assert_eq!(trail.trail_type, TrailType::Linear);
        assert_eq!(trail.total_distance, 30.0);
        assert_eq!(trail.direction_changes, 0);
    }
    
    #[test]
    fn test_trail_type_classification() {
        let analyzer = MovementTrailAnalyzer::new();
        
        // Test stationary movement
        let stationary_positions = vec![
            CursorPosition { x: 100.0, y: 100.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 101.0, y: 100.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 100.0, y: 101.0, timestamp: Utc::now(), screen_id: None },
        ];
        
        let trail = analyzer.analyze_trail(&stationary_positions);
        assert!(trail.is_some());
        assert_eq!(trail.unwrap().trail_type, TrailType::Stationary);
        
        // Test erratic movement
        let erratic_positions = vec![
            CursorPosition { x: 0.0, y: 0.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 10.0, y: 5.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 5.0, y: 15.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 20.0, y: 10.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 15.0, y: 25.0, timestamp: Utc::now(), screen_id: None },
            CursorPosition { x: 30.0, y: 20.0, timestamp: Utc::now(), screen_id: None },
        ];
        
        let trail = analyzer.analyze_trail(&erratic_positions);
        assert!(trail.is_some());
        // Should be classified as erratic due to many direction changes
    }
    
    #[test]
    fn test_click_event_creation() {
        let click = ClickEvent {
            position: CursorPosition {
                x: 100.0,
                y: 200.0,
                timestamp: Utc::now(),
                screen_id: Some(1),
            },
            button: MouseButton::Left,
            click_type: ClickType::Press,
            click_count: 1,
            modifiers: vec![KeyModifier::Command],
            confidence: 0.9,
        };
        
        assert_eq!(click.button, MouseButton::Left);
        assert_eq!(click.click_count, 1);
        assert_eq!(click.modifiers.len(), 1);
        assert_eq!(click.confidence, 0.9);
    }
    
    #[test]
    fn test_configuration_update() {
        let mut tracker = CursorTracker::new();
        
        let new_config = CursorTrackingConfig {
            enable_position_tracking: false,
            enable_click_detection: true,
            enable_trail_analysis: false,
            min_movement_distance: 10.0,
            max_trail_gap_ms: 2000,
            min_confidence: 0.9,
            sampling_interval_ms: 200,
        };
        
        tracker.update_config(new_config.clone());
        assert!(!tracker.config.enable_position_tracking);
        assert_eq!(tracker.config.min_movement_distance, 10.0);
        assert_eq!(tracker.config.sampling_interval_ms, 200);
    }
}