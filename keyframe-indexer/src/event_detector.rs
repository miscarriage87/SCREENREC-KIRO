use crate::error::{IndexerError, Result};
use crate::ocr_data::{OCRResult, BoundingBox};
use crate::error_modal_detector::{ErrorModalDetector, ErrorModalEvent, ErrorModalType};
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use tracing::{debug, info, warn};

/// Event detection engine for identifying field changes and interactions
pub struct EventDetector {
    /// Configuration for event detection
    config: EventDetectionConfig,
    /// Previous frame OCR results for delta analysis
    previous_frame_cache: HashMap<String, Vec<OCRResult>>,
    /// Field tracking for maintaining state across frames
    field_tracker: FieldTracker,
    /// Specialized error and modal detector
    error_modal_detector: ErrorModalDetector,
}

/// Configuration for event detection behavior
#[derive(Debug, Clone)]
pub struct EventDetectionConfig {
    /// Minimum confidence threshold for considering OCR results
    pub min_ocr_confidence: f32,
    /// Minimum IoU threshold for matching text regions between frames
    pub min_iou_threshold: f32,
    /// Minimum text similarity threshold for field matching
    pub min_text_similarity: f32,
    /// Maximum time gap between frames for delta analysis (seconds)
    pub max_frame_gap_seconds: f64,
    /// Minimum confidence for event detection
    pub min_event_confidence: f32,
}

impl Default for EventDetectionConfig {
    fn default() -> Self {
        Self {
            min_ocr_confidence: 0.7,
            min_iou_threshold: 0.3,
            min_text_similarity: 0.8,
            max_frame_gap_seconds: 10.0,
            min_event_confidence: 0.6,
        }
    }
}

/// Tracks field states across frames for change detection
#[derive(Debug, Clone)]
struct FieldTracker {
    /// Current field states indexed by field identifier
    fields: HashMap<String, FieldState>,
    /// History of field changes for pattern analysis
    change_history: Vec<FieldChange>,
}

/// Represents the state of a tracked field
#[derive(Debug, Clone)]
pub struct FieldState {
    /// Current text value
    pub value: String,
    /// Bounding box location
    pub roi: BoundingBox,
    /// Last update timestamp
    pub last_updated: DateTime<Utc>,
    /// Confidence in current value
    pub confidence: f32,
    /// Frame ID where this state was observed
    pub frame_id: String,
}

/// Represents a detected field change
#[derive(Debug, Clone)]
pub struct FieldChange {
    /// Field identifier
    pub field_id: String,
    /// Previous value
    pub value_from: String,
    /// New value
    pub value_to: String,
    /// Timestamp of change
    pub timestamp: DateTime<Utc>,
    /// Confidence in change detection
    pub confidence: f32,
}

/// Detected event types according to requirements 4.1 and 4.5
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum EventType {
    /// Field value change (text input, dropdown selection, etc.)
    FieldChange,
    /// Form submission or button click
    FormSubmission,
    /// Modal dialog appearance
    ModalAppearance,
    /// Error message display
    ErrorDisplay,
    /// Navigation event (page/tab change)
    Navigation,
    /// Data entry completion
    DataEntry,
}

/// Detected event with evidence and confidence scoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedEvent {
    /// Unique event identifier
    pub id: String,
    /// Event timestamp
    pub timestamp: DateTime<Utc>,
    /// Type of event detected
    pub event_type: EventType,
    /// Target element or field identifier
    pub target: String,
    /// Previous value (if applicable)
    pub value_from: Option<String>,
    /// New value (if applicable)
    pub value_to: Option<String>,
    /// Confidence score for this event (0.0 to 1.0)
    pub confidence: f32,
    /// Frame IDs that provide evidence for this event
    pub evidence_frames: Vec<String>,
    /// Additional metadata about the event
    pub metadata: HashMap<String, String>,
}

impl EventDetector {
    /// Create a new event detector with default configuration
    pub fn new() -> Result<Self> {
        Self::with_config(EventDetectionConfig::default())
    }
    
    /// Create a new event detector with custom configuration
    pub fn with_config(config: EventDetectionConfig) -> Result<Self> {
        let error_modal_detector = ErrorModalDetector::new()?;
        
        Ok(Self {
            config,
            previous_frame_cache: HashMap::new(),
            field_tracker: FieldTracker {
                fields: HashMap::new(),
                change_history: Vec::new(),
            },
            error_modal_detector,
        })
    }
    
    /// Analyze OCR results from a frame and detect events
    pub fn analyze_frame(&mut self, frame_id: &str, ocr_results: &[OCRResult], timestamp: DateTime<Utc>, screen_width: f32, screen_height: f32) -> Result<Vec<DetectedEvent>> {
        debug!("Analyzing frame {} with {} OCR results", frame_id, ocr_results.len());
        
        // Filter OCR results by confidence threshold
        let high_confidence_results: Vec<&OCRResult> = ocr_results
            .iter()
            .filter(|r| r.confidence >= self.config.min_ocr_confidence)
            .collect();
        
        if high_confidence_results.is_empty() {
            debug!("No high-confidence OCR results in frame {}", frame_id);
            return Ok(Vec::new());
        }
        
        let mut detected_events = Vec::new();
        
        // Check if we have previous frame data for delta analysis
        let previous_results = self.get_previous_frame_results(frame_id).cloned();
        if let Some(previous_results) = previous_results {
            // Perform delta analysis between current and previous frame
            let delta_events = self.perform_delta_analysis(
                frame_id,
                &high_confidence_results,
                &previous_results,
                timestamp,
            )?;
            detected_events.extend(delta_events);
        }
        
        // Detect standalone events (modals, errors, etc.)
        let standalone_events = self.detect_standalone_events(
            frame_id,
            &high_confidence_results,
            timestamp,
        )?;
        detected_events.extend(standalone_events);
        
        // Use specialized error and modal detector
        let error_modal_events = self.error_modal_detector.detect_errors_and_modals(
            frame_id,
            ocr_results,
            timestamp,
            screen_width,
            screen_height,
        )?;
        
        // Convert ErrorModalEvents to DetectedEvents
        for error_modal_event in error_modal_events {
            let detected_event = self.convert_error_modal_to_detected_event(error_modal_event);
            detected_events.push(detected_event);
        }
        
        // Update field tracker with current frame data
        self.update_field_tracker(frame_id, &high_confidence_results, timestamp)?;
        
        // Cache current frame results for next comparison
        self.cache_frame_results(frame_id, high_confidence_results.into_iter().cloned().collect());
        
        info!("Detected {} events in frame {}", detected_events.len(), frame_id);
        Ok(detected_events)
    }
    
    /// Perform delta analysis between current and previous frame
    fn perform_delta_analysis(
        &mut self,
        frame_id: &str,
        current_results: &[&OCRResult],
        previous_results: &[OCRResult],
        timestamp: DateTime<Utc>,
    ) -> Result<Vec<DetectedEvent>> {
        let mut events = Vec::new();
        
        // Create spatial index for efficient region matching
        let current_regions = self.create_spatial_index(current_results);
        let previous_regions: Vec<&OCRResult> = previous_results.iter().collect();
        let previous_regions = self.create_spatial_index(&previous_regions);
        
        // Find matching regions between frames using IoU
        let region_matches = self.match_regions(&current_regions, &previous_regions);
        
        // Analyze each matched region for changes
        for (current_idx, previous_idx) in region_matches {
            let current = current_results[current_idx];
            let previous = &previous_results[previous_idx];
            
            // Check for text changes
            if current.text != previous.text {
                let change_event = self.create_field_change_event(
                    frame_id,
                    current,
                    previous,
                    timestamp,
                )?;
                
                if change_event.confidence >= self.config.min_event_confidence {
                    events.push(change_event);
                }
            }
        }
        
        // Detect new regions (potential form fields or UI elements)
        let new_regions = self.find_new_regions(&current_regions, &previous_regions);
        for region_idx in new_regions {
            let new_region = current_results[region_idx];
            
            // Check if this looks like a new form field or interactive element
            if self.is_interactive_element(&new_region.text) {
                let event = DetectedEvent {
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp,
                    event_type: EventType::DataEntry,
                    target: self.generate_field_id(&new_region.roi),
                    value_from: None,
                    value_to: Some(new_region.text.clone()),
                    confidence: new_region.confidence * 0.8, // Slightly lower confidence for new elements
                    evidence_frames: vec![frame_id.to_string()],
                    metadata: self.create_metadata(new_region),
                };
                
                if event.confidence >= self.config.min_event_confidence {
                    events.push(event);
                }
            }
        }
        
        Ok(events)
    }
    
    /// Detect standalone events like modals, errors, and navigation
    fn detect_standalone_events(
        &self,
        frame_id: &str,
        ocr_results: &[&OCRResult],
        timestamp: DateTime<Utc>,
    ) -> Result<Vec<DetectedEvent>> {
        let mut events = Vec::new();
        
        for result in ocr_results {
            // Check for error messages
            if self.is_error_message(&result.text) {
                let event = DetectedEvent {
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp,
                    event_type: EventType::ErrorDisplay,
                    target: "error_dialog".to_string(),
                    value_from: None,
                    value_to: Some(result.text.clone()),
                    confidence: result.confidence * 0.9,
                    evidence_frames: vec![frame_id.to_string()],
                    metadata: self.create_metadata(result),
                };
                events.push(event);
            }
            
            // Check for modal dialogs
            if self.is_modal_dialog(&result.text) {
                let event = DetectedEvent {
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp,
                    event_type: EventType::ModalAppearance,
                    target: "modal_dialog".to_string(),
                    value_from: None,
                    value_to: Some(result.text.clone()),
                    confidence: result.confidence * 0.85,
                    evidence_frames: vec![frame_id.to_string()],
                    metadata: self.create_metadata(result),
                };
                events.push(event);
            }
            
            // Check for form submission indicators
            if self.is_form_submission(&result.text) {
                let event = DetectedEvent {
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp,
                    event_type: EventType::FormSubmission,
                    target: "form_submit".to_string(),
                    value_from: None,
                    value_to: Some(result.text.clone()),
                    confidence: result.confidence * 0.8,
                    evidence_frames: vec![frame_id.to_string()],
                    metadata: self.create_metadata(result),
                };
                events.push(event);
            }
        }
        
        Ok(events)
    }
    
    /// Create a field change event with confidence scoring
    fn create_field_change_event(
        &self,
        frame_id: &str,
        current: &OCRResult,
        previous: &OCRResult,
        timestamp: DateTime<Utc>,
    ) -> Result<DetectedEvent> {
        // Calculate confidence based on multiple factors
        let text_similarity = self.calculate_text_similarity(&current.text, &previous.text);
        let spatial_similarity = current.roi.iou(&previous.roi);
        let ocr_confidence = (current.confidence + previous.confidence) / 2.0;
        
        // Weighted confidence calculation
        let confidence = (
            ocr_confidence * 0.4 +
            spatial_similarity * 0.3 +
            (1.0 - text_similarity) * 0.3 // Higher confidence for more different text
        ).min(1.0);
        
        let field_id = self.generate_field_id(&current.roi);
        
        Ok(DetectedEvent {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp,
            event_type: EventType::FieldChange,
            target: field_id,
            value_from: Some(previous.text.clone()),
            value_to: Some(current.text.clone()),
            confidence,
            evidence_frames: vec![frame_id.to_string()],
            metadata: self.create_metadata(current),
        })
    }
    
    /// Create spatial index for efficient region matching
    fn create_spatial_index<'a>(&self, results: &[&'a OCRResult]) -> Vec<(usize, &'a BoundingBox)> {
        results.iter()
            .enumerate()
            .map(|(idx, result)| (idx, &result.roi))
            .collect()
    }
    
    /// Match regions between current and previous frames using IoU
    fn match_regions(
        &self,
        current: &[(usize, &BoundingBox)],
        previous: &[(usize, &BoundingBox)],
    ) -> Vec<(usize, usize)> {
        let mut matches = Vec::new();
        
        for (current_idx, current_roi) in current {
            let mut best_match = None;
            let mut best_iou = self.config.min_iou_threshold;
            
            for (previous_idx, previous_roi) in previous {
                let iou = current_roi.iou(previous_roi);
                if iou > best_iou {
                    best_iou = iou;
                    best_match = Some(*previous_idx);
                }
            }
            
            if let Some(previous_idx) = best_match {
                matches.push((*current_idx, previous_idx));
            }
        }
        
        matches
    }
    
    /// Find regions that are new in the current frame
    fn find_new_regions(
        &self,
        current: &[(usize, &BoundingBox)],
        previous: &[(usize, &BoundingBox)],
    ) -> Vec<usize> {
        let mut new_regions = Vec::new();
        
        for (current_idx, current_roi) in current {
            let mut has_match = false;
            
            for (_, previous_roi) in previous {
                if current_roi.iou(previous_roi) >= self.config.min_iou_threshold {
                    has_match = true;
                    break;
                }
            }
            
            if !has_match {
                new_regions.push(*current_idx);
            }
        }
        
        new_regions
    }
    
    /// Generate a unique field identifier based on spatial location
    fn generate_field_id(&self, roi: &BoundingBox) -> String {
        format!("field_{}_{}_{}_{}", 
            (roi.x as i32), 
            (roi.y as i32), 
            (roi.width as i32), 
            (roi.height as i32)
        )
    }
    
    /// Calculate text similarity between two strings
    pub fn calculate_text_similarity(&self, text1: &str, text2: &str) -> f32 {
        if text1 == text2 {
            return 1.0;
        }
        
        if text1.is_empty() || text2.is_empty() {
            return 0.0;
        }
        
        // Simple Levenshtein distance-based similarity
        let distance = levenshtein_distance(text1, text2);
        let max_len = text1.len().max(text2.len()) as f32;
        
        if max_len == 0.0 {
            1.0
        } else {
            1.0 - (distance as f32 / max_len)
        }
    }
    
    /// Check if text represents an error message
    fn is_error_message(&self, text: &str) -> bool {
        let error_patterns = [
            "error", "failed", "invalid", "incorrect", "wrong",
            "cannot", "unable", "denied", "forbidden", "timeout",
            "exception", "warning", "alert", "problem"
        ];
        
        let text_lower = text.to_lowercase();
        error_patterns.iter().any(|pattern| text_lower.contains(pattern))
    }
    
    /// Check if text represents a modal dialog
    fn is_modal_dialog(&self, text: &str) -> bool {
        let modal_patterns = [
            "confirm", "cancel", "ok", "yes", "no", "close",
            "dialog", "popup", "modal", "alert", "notification"
        ];
        
        let text_lower = text.to_lowercase();
        modal_patterns.iter().any(|pattern| text_lower.contains(pattern))
    }
    
    /// Check if text represents a form submission
    fn is_form_submission(&self, text: &str) -> bool {
        let submit_patterns = [
            "submit", "send", "save", "create", "update",
            "login", "register", "sign in", "sign up", "continue"
        ];
        
        let text_lower = text.to_lowercase();
        submit_patterns.iter().any(|pattern| text_lower.contains(pattern))
    }
    
    /// Check if text represents an interactive element
    fn is_interactive_element(&self, text: &str) -> bool {
        // Check for common form field patterns
        let text_lower = text.to_lowercase();
        
        // Common form field indicators
        text_lower.contains("enter") ||
        text_lower.contains("input") ||
        text_lower.contains("select") ||
        text_lower.contains("choose") ||
        text_lower.ends_with(":") ||
        text_lower.contains("@") || // Email fields
        text.chars().all(|c| c.is_numeric()) // Numeric inputs
    }
    
    /// Create metadata for an event
    fn create_metadata(&self, ocr_result: &OCRResult) -> HashMap<String, String> {
        let mut metadata = HashMap::new();
        metadata.insert("language".to_string(), ocr_result.language.clone());
        metadata.insert("processor".to_string(), ocr_result.processor.clone());
        metadata.insert("roi_x".to_string(), ocr_result.roi.x.to_string());
        metadata.insert("roi_y".to_string(), ocr_result.roi.y.to_string());
        metadata.insert("roi_width".to_string(), ocr_result.roi.width.to_string());
        metadata.insert("roi_height".to_string(), ocr_result.roi.height.to_string());
        metadata
    }
    
    /// Update field tracker with current frame data
    fn update_field_tracker(
        &mut self,
        frame_id: &str,
        ocr_results: &[&OCRResult],
        timestamp: DateTime<Utc>,
    ) -> Result<()> {
        for result in ocr_results {
            let field_id = self.generate_field_id(&result.roi);
            
            // Check if this field has changed
            if let Some(previous_state) = self.field_tracker.fields.get(&field_id) {
                if previous_state.value != result.text {
                    // Record the change
                    let change = FieldChange {
                        field_id: field_id.clone(),
                        value_from: previous_state.value.clone(),
                        value_to: result.text.clone(),
                        timestamp,
                        confidence: result.confidence,
                    };
                    self.field_tracker.change_history.push(change);
                }
            }
            
            // Update field state
            let field_state = FieldState {
                value: result.text.clone(),
                roi: result.roi.clone(),
                last_updated: timestamp,
                confidence: result.confidence,
                frame_id: frame_id.to_string(),
            };
            
            self.field_tracker.fields.insert(field_id, field_state);
        }
        
        Ok(())
    }
    
    /// Cache frame results for delta analysis
    fn cache_frame_results(&mut self, frame_id: &str, results: Vec<OCRResult>) {
        // Keep only recent frames to manage memory
        const MAX_CACHED_FRAMES: usize = 10;
        
        if self.previous_frame_cache.len() >= MAX_CACHED_FRAMES {
            // Remove oldest frame (simple FIFO for now)
            if let Some(oldest_key) = self.previous_frame_cache.keys().next().cloned() {
                self.previous_frame_cache.remove(&oldest_key);
            }
        }
        
        self.previous_frame_cache.insert(frame_id.to_string(), results);
    }
    
    /// Get previous frame results for comparison
    fn get_previous_frame_results(&self, current_frame_id: &str) -> Option<&Vec<OCRResult>> {
        // For now, just get any previous frame
        // In a more sophisticated implementation, we'd find the chronologically previous frame
        self.previous_frame_cache.values().next()
    }
    
    /// Get field change history
    pub fn get_field_changes(&self) -> &[FieldChange] {
        &self.field_tracker.change_history
    }
    
    /// Get current field states
    pub fn get_field_states(&self) -> &HashMap<String, FieldState> {
        &self.field_tracker.fields
    }
    
    /// Clear cached data to free memory
    pub fn clear_cache(&mut self) {
        self.previous_frame_cache.clear();
        self.field_tracker.change_history.clear();
    }
    
    /// Convert ErrorModalEvent to DetectedEvent
    fn convert_error_modal_to_detected_event(&self, error_modal_event: ErrorModalEvent) -> DetectedEvent {
        let event_type = match error_modal_event.event_type {
            ErrorModalType::SystemError | ErrorModalType::ApplicationError | 
            ErrorModalType::NetworkError | ErrorModalType::AuthError | 
            ErrorModalType::ValidationError => EventType::ErrorDisplay,
            ErrorModalType::Warning => EventType::ErrorDisplay,
            ErrorModalType::ConfirmationDialog | ErrorModalType::InfoDialog | 
            ErrorModalType::AlertDialog | ErrorModalType::FileDialog | 
            ErrorModalType::SettingsDialog | ErrorModalType::ProgressDialog | 
            ErrorModalType::CustomDialog => EventType::ModalAppearance,
        };
        
        DetectedEvent {
            id: error_modal_event.id,
            timestamp: error_modal_event.timestamp,
            event_type,
            target: format!("{}_{}", error_modal_event.event_type.to_string(), error_modal_event.severity.to_string()),
            value_from: None,
            value_to: Some(error_modal_event.message),
            confidence: error_modal_event.confidence,
            evidence_frames: vec![error_modal_event.frame_id],
            metadata: error_modal_event.metadata,
        }
    }
}

/// Calculate Levenshtein distance between two strings
fn levenshtein_distance(s1: &str, s2: &str) -> usize {
    let len1 = s1.chars().count();
    let len2 = s2.chars().count();
    
    if len1 == 0 {
        return len2;
    }
    if len2 == 0 {
        return len1;
    }
    
    let mut matrix = vec![vec![0; len2 + 1]; len1 + 1];
    
    // Initialize first row and column
    for i in 0..=len1 {
        matrix[i][0] = i;
    }
    for j in 0..=len2 {
        matrix[0][j] = j;
    }
    
    let s1_chars: Vec<char> = s1.chars().collect();
    let s2_chars: Vec<char> = s2.chars().collect();
    
    // Fill the matrix
    for i in 1..=len1 {
        for j in 1..=len2 {
            let cost = if s1_chars[i - 1] == s2_chars[j - 1] { 0 } else { 1 };
            
            matrix[i][j] = (matrix[i - 1][j] + 1)
                .min(matrix[i][j - 1] + 1)
                .min(matrix[i - 1][j - 1] + cost);
        }
    }
    
    matrix[len1][len2]
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_levenshtein_distance() {
        assert_eq!(levenshtein_distance("hello", "hello"), 0);
        assert_eq!(levenshtein_distance("hello", "hallo"), 1);
        assert_eq!(levenshtein_distance("hello", ""), 5);
        assert_eq!(levenshtein_distance("", "world"), 5);
    }
    
    #[test]
    fn test_text_similarity() {
        let detector = EventDetector::new().unwrap();
        
        assert_eq!(detector.calculate_text_similarity("hello", "hello"), 1.0);
        assert!(detector.calculate_text_similarity("hello", "hallo") > 0.8);
        assert!(detector.calculate_text_similarity("hello", "world") < 0.5);
    }
    
    #[test]
    fn test_error_message_detection() {
        let detector = EventDetector::new().unwrap();
        
        assert!(detector.is_error_message("Error: Invalid input"));
        assert!(detector.is_error_message("Login failed"));
        assert!(detector.is_error_message("Cannot connect to server"));
        assert!(!detector.is_error_message("Welcome to the application"));
    }
    
    #[test]
    fn test_modal_dialog_detection() {
        let detector = EventDetector::new().unwrap();
        
        assert!(detector.is_modal_dialog("Confirm deletion"));
        assert!(detector.is_modal_dialog("OK"));
        assert!(detector.is_modal_dialog("Cancel"));
        assert!(!detector.is_modal_dialog("Regular text content"));
    }
    
    #[test]
    fn test_form_submission_detection() {
        let detector = EventDetector::new().unwrap();
        
        assert!(detector.is_form_submission("Submit"));
        assert!(detector.is_form_submission("Login"));
        assert!(detector.is_form_submission("Sign up"));
        assert!(!detector.is_form_submission("Regular button"));
    }
}