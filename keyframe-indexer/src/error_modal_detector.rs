use crate::error::{IndexerError, Result};
use crate::ocr_data::{OCRResult, BoundingBox};
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use regex::Regex;
use tracing::{debug, info, warn};

/// Specialized detector for error messages and modal dialogs
pub struct ErrorModalDetector {
    /// Configuration for error and modal detection
    config: ErrorModalDetectionConfig,
    /// Compiled regex patterns for efficient matching
    error_patterns: Vec<CompiledPattern>,
    modal_patterns: Vec<CompiledPattern>,
    system_alert_patterns: Vec<CompiledPattern>,
    /// Layout analysis for dialog detection
    layout_analyzer: DialogLayoutAnalyzer,
}

/// Configuration for error and modal detection behavior
#[derive(Debug, Clone)]
pub struct ErrorModalDetectionConfig {
    /// Minimum confidence threshold for OCR results
    pub min_ocr_confidence: f32,
    /// Minimum confidence for error detection
    pub min_error_confidence: f32,
    /// Minimum confidence for modal detection
    pub min_modal_confidence: f32,
    /// Enable layout-based detection
    pub enable_layout_detection: bool,
    /// Minimum dialog size for layout detection
    pub min_dialog_width: f32,
    pub min_dialog_height: f32,
    /// Maximum dialog size (to avoid detecting full-screen content)
    pub max_dialog_width_ratio: f32,
    pub max_dialog_height_ratio: f32,
}

impl Default for ErrorModalDetectionConfig {
    fn default() -> Self {
        Self {
            min_ocr_confidence: 0.7,
            min_error_confidence: 0.6,
            min_modal_confidence: 0.6,
            enable_layout_detection: true,
            min_dialog_width: 200.0,
            min_dialog_height: 100.0,
            max_dialog_width_ratio: 0.8,
            max_dialog_height_ratio: 0.8,
        }
    }
}

/// Compiled regex pattern with metadata
#[derive(Debug, Clone)]
struct CompiledPattern {
    regex: Regex,
    pattern_type: String,
    confidence_weight: f32,
    description: String,
}

/// Types of errors and modals that can be detected
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ErrorModalType {
    /// System error messages
    SystemError,
    /// Application error messages
    ApplicationError,
    /// Network/connectivity errors
    NetworkError,
    /// Authentication/permission errors
    AuthError,
    /// Validation errors (form fields, input validation)
    ValidationError,
    /// Warning messages
    Warning,
    /// Confirmation dialogs
    ConfirmationDialog,
    /// Information dialogs
    InfoDialog,
    /// Alert dialogs
    AlertDialog,
    /// File dialogs (open/save)
    FileDialog,
    /// Settings/preferences dialogs
    SettingsDialog,
    /// Progress dialogs
    ProgressDialog,
    /// Custom application dialogs
    CustomDialog,
}

/// Detected error or modal with detailed classification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorModalEvent {
    /// Unique event identifier
    pub id: String,
    /// Event timestamp
    pub timestamp: DateTime<Utc>,
    /// Type of error or modal detected
    pub event_type: ErrorModalType,
    /// Severity level (Critical, High, Medium, Low, Info)
    pub severity: SeverityLevel,
    /// Main message or title
    pub title: String,
    /// Detailed message content
    pub message: String,
    /// Confidence score for this detection (0.0 to 1.0)
    pub confidence: f32,
    /// Frame ID that contains this error/modal
    pub frame_id: String,
    /// Bounding box of the error/modal region
    pub roi: BoundingBox,
    /// Additional context and metadata
    pub metadata: HashMap<String, String>,
    /// Pattern matches that contributed to detection
    pub pattern_matches: Vec<PatternMatch>,
    /// Layout analysis results
    pub layout_analysis: Option<LayoutAnalysis>,
}

/// Severity levels for errors and alerts
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SeverityLevel {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

impl std::fmt::Display for ErrorModalType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ErrorModalType::SystemError => write!(f, "system_error"),
            ErrorModalType::ApplicationError => write!(f, "application_error"),
            ErrorModalType::NetworkError => write!(f, "network_error"),
            ErrorModalType::AuthError => write!(f, "auth_error"),
            ErrorModalType::ValidationError => write!(f, "validation_error"),
            ErrorModalType::Warning => write!(f, "warning"),
            ErrorModalType::ConfirmationDialog => write!(f, "confirmation_dialog"),
            ErrorModalType::InfoDialog => write!(f, "info_dialog"),
            ErrorModalType::AlertDialog => write!(f, "alert_dialog"),
            ErrorModalType::FileDialog => write!(f, "file_dialog"),
            ErrorModalType::SettingsDialog => write!(f, "settings_dialog"),
            ErrorModalType::ProgressDialog => write!(f, "progress_dialog"),
            ErrorModalType::CustomDialog => write!(f, "custom_dialog"),
        }
    }
}

impl std::fmt::Display for SeverityLevel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SeverityLevel::Critical => write!(f, "critical"),
            SeverityLevel::High => write!(f, "high"),
            SeverityLevel::Medium => write!(f, "medium"),
            SeverityLevel::Low => write!(f, "low"),
            SeverityLevel::Info => write!(f, "info"),
        }
    }
}

/// Information about a pattern match
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternMatch {
    /// Pattern type that matched
    pub pattern_type: String,
    /// Matched text
    pub matched_text: String,
    /// Confidence contribution from this pattern
    pub confidence_weight: f32,
    /// Description of what this pattern detects
    pub description: String,
}

/// Layout analysis results for dialog detection
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayoutAnalysis {
    /// Whether this appears to be a dialog based on layout
    pub is_dialog_layout: bool,
    /// Dialog dimensions
    pub dialog_width: f32,
    pub dialog_height: f32,
    /// Position relative to screen
    pub center_x_ratio: f32,
    pub center_y_ratio: f32,
    /// Whether dialog appears centered
    pub is_centered: bool,
    /// Confidence in layout analysis
    pub layout_confidence: f32,
}

/// Analyzes layout patterns for dialog detection
struct DialogLayoutAnalyzer {
    config: ErrorModalDetectionConfig,
}

impl ErrorModalDetector {
    /// Create a new error and modal detector with default configuration
    pub fn new() -> Result<Self> {
        Self::with_config(ErrorModalDetectionConfig::default())
    }
    
    /// Create a new detector with custom configuration
    pub fn with_config(config: ErrorModalDetectionConfig) -> Result<Self> {
        let error_patterns = Self::compile_error_patterns()?;
        let modal_patterns = Self::compile_modal_patterns()?;
        let system_alert_patterns = Self::compile_system_alert_patterns()?;
        let layout_analyzer = DialogLayoutAnalyzer::new(config.clone());
        
        Ok(Self {
            config,
            error_patterns,
            modal_patterns,
            system_alert_patterns,
            layout_analyzer,
        })
    }
    
    /// Analyze OCR results from a frame and detect errors and modals
    pub fn detect_errors_and_modals(
        &self,
        frame_id: &str,
        ocr_results: &[OCRResult],
        timestamp: DateTime<Utc>,
        screen_width: f32,
        screen_height: f32,
    ) -> Result<Vec<ErrorModalEvent>> {
        debug!("Analyzing frame {} for errors and modals with {} OCR results", frame_id, ocr_results.len());
        
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
        
        // Detect individual error messages and modals
        for result in &high_confidence_results {
            if let Some(event) = self.analyze_text_for_errors_modals(
                frame_id,
                result,
                timestamp,
                screen_width,
                screen_height,
            )? {
                detected_events.push(event);
            }
        }
        
        // Perform layout-based detection for dialog boxes
        if self.config.enable_layout_detection {
            let layout_events = self.detect_dialog_layouts(
                frame_id,
                &high_confidence_results,
                timestamp,
                screen_width,
                screen_height,
            )?;
            detected_events.extend(layout_events);
        }
        
        // Group related OCR results that might form a single dialog
        let grouped_events = self.group_related_elements(detected_events)?;
        
        info!("Detected {} error/modal events in frame {}", grouped_events.len(), frame_id);
        Ok(grouped_events)
    }
    
    /// Analyze individual OCR result for error/modal patterns
    fn analyze_text_for_errors_modals(
        &self,
        frame_id: &str,
        ocr_result: &OCRResult,
        timestamp: DateTime<Utc>,
        screen_width: f32,
        screen_height: f32,
    ) -> Result<Option<ErrorModalEvent>> {
        let text = &ocr_result.text;
        let mut pattern_matches = Vec::new();
        let mut total_confidence = 0.0;
        let mut event_type = None;
        let mut severity = SeverityLevel::Info;
        
        // Check error patterns
        for pattern in &self.error_patterns {
            if pattern.regex.is_match(text) {
                let match_info = PatternMatch {
                    pattern_type: pattern.pattern_type.clone(),
                    matched_text: text.clone(),
                    confidence_weight: pattern.confidence_weight,
                    description: pattern.description.clone(),
                };
                pattern_matches.push(match_info);
                total_confidence += pattern.confidence_weight;
                
                // Determine event type and severity based on pattern
                match pattern.pattern_type.as_str() {
                    "critical_error" => {
                        event_type = Some(ErrorModalType::SystemError);
                        severity = SeverityLevel::Critical;
                    }
                    "network_error" => {
                        event_type = Some(ErrorModalType::NetworkError);
                        severity = SeverityLevel::High;
                    }
                    "auth_error" => {
                        event_type = Some(ErrorModalType::AuthError);
                        severity = SeverityLevel::High;
                    }
                    "validation_error" => {
                        event_type = Some(ErrorModalType::ValidationError);
                        severity = SeverityLevel::Medium;
                    }
                    "warning" => {
                        event_type = Some(ErrorModalType::Warning);
                        severity = SeverityLevel::Medium;
                    }
                    _ => {
                        event_type = Some(ErrorModalType::ApplicationError);
                        severity = SeverityLevel::Medium;
                    }
                }
            }
        }
        
        // Check modal patterns
        for pattern in &self.modal_patterns {
            if pattern.regex.is_match(text) {
                let match_info = PatternMatch {
                    pattern_type: pattern.pattern_type.clone(),
                    matched_text: text.clone(),
                    confidence_weight: pattern.confidence_weight,
                    description: pattern.description.clone(),
                };
                pattern_matches.push(match_info);
                total_confidence += pattern.confidence_weight;
                
                // Determine modal type
                match pattern.pattern_type.as_str() {
                    "confirmation_dialog" => {
                        event_type = Some(ErrorModalType::ConfirmationDialog);
                        severity = SeverityLevel::Info;
                    }
                    "file_dialog" => {
                        event_type = Some(ErrorModalType::FileDialog);
                        severity = SeverityLevel::Info;
                    }
                    "settings_dialog" => {
                        event_type = Some(ErrorModalType::SettingsDialog);
                        severity = SeverityLevel::Info;
                    }
                    "progress_dialog" => {
                        event_type = Some(ErrorModalType::ProgressDialog);
                        severity = SeverityLevel::Info;
                    }
                    _ => {
                        event_type = Some(ErrorModalType::InfoDialog);
                        severity = SeverityLevel::Info;
                    }
                }
            }
        }
        
        // Check system alert patterns
        for pattern in &self.system_alert_patterns {
            if pattern.regex.is_match(text) {
                let match_info = PatternMatch {
                    pattern_type: pattern.pattern_type.clone(),
                    matched_text: text.clone(),
                    confidence_weight: pattern.confidence_weight,
                    description: pattern.description.clone(),
                };
                pattern_matches.push(match_info);
                total_confidence += pattern.confidence_weight;
                
                event_type = Some(ErrorModalType::AlertDialog);
                severity = SeverityLevel::High;
            }
        }
        
        // If no patterns matched, return None
        if pattern_matches.is_empty() {
            return Ok(None);
        }
        
        // Calculate final confidence
        let base_confidence = (total_confidence / pattern_matches.len() as f32).min(1.0);
        let ocr_confidence_factor = ocr_result.confidence;
        let final_confidence = (base_confidence * 0.7 + ocr_confidence_factor * 0.3).min(1.0);
        
        // Check minimum confidence thresholds
        let min_confidence = match event_type {
            Some(ErrorModalType::SystemError) | 
            Some(ErrorModalType::NetworkError) | 
            Some(ErrorModalType::AuthError) => self.config.min_error_confidence,
            _ => self.config.min_modal_confidence,
        };
        
        if final_confidence < min_confidence {
            return Ok(None);
        }
        
        // Perform layout analysis if enabled
        let layout_analysis = if self.config.enable_layout_detection {
            Some(self.layout_analyzer.analyze_layout(
                &ocr_result.roi,
                screen_width,
                screen_height,
            ))
        } else {
            None
        };
        
        // Create metadata
        let mut metadata = HashMap::new();
        metadata.insert("language".to_string(), ocr_result.language.clone());
        metadata.insert("processor".to_string(), ocr_result.processor.clone());
        metadata.insert("screen_width".to_string(), screen_width.to_string());
        metadata.insert("screen_height".to_string(), screen_height.to_string());
        metadata.insert("pattern_count".to_string(), pattern_matches.len().to_string());
        
        let event = ErrorModalEvent {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp,
            event_type: event_type.unwrap_or(ErrorModalType::CustomDialog),
            severity,
            title: self.extract_title(text),
            message: text.clone(),
            confidence: final_confidence,
            frame_id: frame_id.to_string(),
            roi: ocr_result.roi.clone(),
            metadata,
            pattern_matches,
            layout_analysis,
        };
        
        Ok(Some(event))
    }
    
    /// Detect dialog layouts based on spatial arrangement of OCR results
    fn detect_dialog_layouts(
        &self,
        frame_id: &str,
        ocr_results: &[&OCRResult],
        timestamp: DateTime<Utc>,
        screen_width: f32,
        screen_height: f32,
    ) -> Result<Vec<ErrorModalEvent>> {
        let mut dialog_events = Vec::new();
        
        // Group OCR results by spatial proximity
        let spatial_groups = self.group_by_spatial_proximity(ocr_results);
        
        for group in spatial_groups {
            if group.len() < 2 {
                continue; // Need at least 2 elements for a dialog
            }
            
            // Calculate bounding box for the entire group
            let group_bbox = self.calculate_group_bounding_box(&group);
            
            // Check if this looks like a dialog layout
            let layout_analysis = self.layout_analyzer.analyze_layout(
                &group_bbox,
                screen_width,
                screen_height,
            );
            
            if layout_analysis.is_dialog_layout && layout_analysis.layout_confidence >= 0.6 {
                // Extract text content from the group
                let combined_text = group.iter()
                    .map(|r| r.text.as_str())
                    .collect::<Vec<_>>()
                    .join(" ");
                
                // Determine dialog type based on content
                let dialog_type = self.classify_dialog_by_content(&combined_text);
                let severity = self.determine_severity_by_content(&combined_text);
                
                let mut metadata = HashMap::new();
                metadata.insert("group_size".to_string(), group.len().to_string());
                metadata.insert("detection_method".to_string(), "layout_analysis".to_string());
                metadata.insert("screen_width".to_string(), screen_width.to_string());
                metadata.insert("screen_height".to_string(), screen_height.to_string());
                
                let event = ErrorModalEvent {
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp,
                    event_type: dialog_type,
                    severity,
                    title: self.extract_title(&combined_text),
                    message: combined_text,
                    confidence: layout_analysis.layout_confidence,
                    frame_id: frame_id.to_string(),
                    roi: group_bbox,
                    metadata,
                    pattern_matches: Vec::new(),
                    layout_analysis: Some(layout_analysis),
                };
                
                dialog_events.push(event);
            }
        }
        
        Ok(dialog_events)
    }
    
    /// Group OCR results by spatial proximity
    fn group_by_spatial_proximity<'a>(&self, ocr_results: &[&'a OCRResult]) -> Vec<Vec<&'a OCRResult>> {
        let mut groups = Vec::new();
        let mut used = vec![false; ocr_results.len()];
        
        for i in 0..ocr_results.len() {
            if used[i] {
                continue;
            }
            
            let mut group = vec![ocr_results[i]];
            used[i] = true;
            
            // Find nearby OCR results
            for j in (i + 1)..ocr_results.len() {
                if used[j] {
                    continue;
                }
                
                let distance = self.calculate_spatial_distance(
                    &ocr_results[i].roi,
                    &ocr_results[j].roi,
                );
                
                // If close enough, add to group
                if distance < 100.0 { // Configurable threshold
                    group.push(ocr_results[j]);
                    used[j] = true;
                }
            }
            
            groups.push(group);
        }
        
        groups
    }
    
    /// Calculate spatial distance between two bounding boxes
    fn calculate_spatial_distance(&self, bbox1: &BoundingBox, bbox2: &BoundingBox) -> f32 {
        let center1_x = bbox1.x + bbox1.width / 2.0;
        let center1_y = bbox1.y + bbox1.height / 2.0;
        let center2_x = bbox2.x + bbox2.width / 2.0;
        let center2_y = bbox2.y + bbox2.height / 2.0;
        
        let dx = center1_x - center2_x;
        let dy = center1_y - center2_y;
        
        (dx * dx + dy * dy).sqrt()
    }
    
    /// Calculate bounding box that encompasses a group of OCR results
    fn calculate_group_bounding_box(&self, group: &[&OCRResult]) -> BoundingBox {
        if group.is_empty() {
            return BoundingBox {
                x: 0.0,
                y: 0.0,
                width: 0.0,
                height: 0.0,
            };
        }
        
        let mut min_x = f32::MAX;
        let mut min_y = f32::MAX;
        let mut max_x = f32::MIN;
        let mut max_y = f32::MIN;
        
        for result in group {
            min_x = min_x.min(result.roi.x);
            min_y = min_y.min(result.roi.y);
            max_x = max_x.max(result.roi.x + result.roi.width);
            max_y = max_y.max(result.roi.y + result.roi.height);
        }
        
        BoundingBox {
            x: min_x,
            y: min_y,
            width: max_x - min_x,
            height: max_y - min_y,
        }
    }
    
    /// Classify dialog type based on content analysis
    fn classify_dialog_by_content(&self, text: &str) -> ErrorModalType {
        let text_lower = text.to_lowercase();
        
        // Check for specific dialog types
        if text_lower.contains("save") || text_lower.contains("open") || text_lower.contains("file") {
            return ErrorModalType::FileDialog;
        }
        
        if text_lower.contains("settings") || text_lower.contains("preferences") || text_lower.contains("options") {
            return ErrorModalType::SettingsDialog;
        }
        
        if text_lower.contains("progress") || text_lower.contains("loading") || text_lower.contains("%") {
            return ErrorModalType::ProgressDialog;
        }
        
        if text_lower.contains("confirm") || text_lower.contains("are you sure") {
            return ErrorModalType::ConfirmationDialog;
        }
        
        if text_lower.contains("error") || text_lower.contains("failed") || text_lower.contains("invalid") {
            return ErrorModalType::ApplicationError;
        }
        
        if text_lower.contains("warning") || text_lower.contains("caution") {
            return ErrorModalType::Warning;
        }
        
        if text_lower.contains("alert") || text_lower.contains("attention") {
            return ErrorModalType::AlertDialog;
        }
        
        ErrorModalType::InfoDialog
    }
    
    /// Determine severity based on content
    fn determine_severity_by_content(&self, text: &str) -> SeverityLevel {
        let text_lower = text.to_lowercase();
        
        if text_lower.contains("critical") || text_lower.contains("fatal") || text_lower.contains("crash") {
            return SeverityLevel::Critical;
        }
        
        if text_lower.contains("error") || text_lower.contains("failed") || text_lower.contains("denied") {
            return SeverityLevel::High;
        }
        
        if text_lower.contains("warning") || text_lower.contains("caution") || text_lower.contains("invalid") {
            return SeverityLevel::Medium;
        }
        
        if text_lower.contains("notice") || text_lower.contains("attention") {
            return SeverityLevel::Low;
        }
        
        SeverityLevel::Info
    }
    
    /// Extract title from text content
    fn extract_title(&self, text: &str) -> String {
        // Take first line or first sentence as title
        let lines: Vec<&str> = text.lines().collect();
        if !lines.is_empty() {
            let first_line = lines[0].trim();
            if !first_line.is_empty() {
                return first_line.to_string();
            }
        }
        
        // Fallback to first 50 characters
        if text.len() > 50 {
            format!("{}...", &text[..47])
        } else {
            text.to_string()
        }
    }
    
    /// Group related elements that might belong to the same dialog
    fn group_related_elements(&self, events: Vec<ErrorModalEvent>) -> Result<Vec<ErrorModalEvent>> {
        // For now, return events as-is
        // In a more sophisticated implementation, we would merge overlapping or nearby events
        Ok(events)
    }
    
    /// Compile error detection patterns
    fn compile_error_patterns() -> Result<Vec<CompiledPattern>> {
        let patterns = vec![
            // Critical system errors
            (r"(?i)(fatal|critical|crash|panic|abort)", "critical_error", 0.9, "Critical system errors"),
            (r"(?i)(segmentation fault|access violation|null pointer)", "critical_error", 0.95, "Memory access errors"),
            
            // Network errors
            (r"(?i)(connection (failed|refused|timeout)|network (error|unavailable))", "network_error", 0.8, "Network connectivity issues"),
            (r"(?i)(dns (error|failed)|host not found|server not responding)", "network_error", 0.85, "DNS and server errors"),
            
            // Authentication errors
            (r"(?i)(access denied|unauthorized|authentication (failed|required))", "auth_error", 0.8, "Authentication failures"),
            (r"(?i)(login (failed|invalid)|incorrect (password|credentials))", "auth_error", 0.85, "Login errors"),
            (r"(?i)(permission denied|insufficient privileges)", "auth_error", 0.8, "Permission errors"),
            
            // Validation errors
            (r"(?i)(invalid (input|format|value)|validation (failed|error))", "validation_error", 0.7, "Input validation errors"),
            (r"(?i)(required field|missing (value|input)|field cannot be empty)", "validation_error", 0.75, "Required field errors"),
            
            // General application errors
            (r"(?i)(error|failed|exception|problem)", "application_error", 0.6, "General application errors"),
            (r"(?i)(cannot|unable to|failed to)", "application_error", 0.5, "Operation failures"),
            
            // Warnings
            (r"(?i)(warning|caution|notice)", "warning", 0.7, "Warning messages"),
        ];
        
        let mut compiled = Vec::new();
        for (pattern, pattern_type, weight, description) in patterns {
            match Regex::new(pattern) {
                Ok(regex) => {
                    compiled.push(CompiledPattern {
                        regex,
                        pattern_type: pattern_type.to_string(),
                        confidence_weight: weight,
                        description: description.to_string(),
                    });
                }
                Err(e) => {
                    warn!("Failed to compile error pattern '{}': {}", pattern, e);
                }
            }
        }
        
        Ok(compiled)
    }
    
    /// Compile modal dialog detection patterns
    fn compile_modal_patterns() -> Result<Vec<CompiledPattern>> {
        let patterns = vec![
            // Confirmation dialogs
            (r"(?i)(confirm|are you sure|do you want to)", "confirmation_dialog", 0.8, "Confirmation dialogs"),
            (r"(?i)(yes|no|ok|cancel|continue|abort)", "confirmation_dialog", 0.6, "Dialog buttons"),
            
            // File dialogs
            (r"(?i)(open|save|choose|select) (file|folder|directory)", "file_dialog", 0.85, "File selection dialogs"),
            (r"(?i)(browse|upload|download)", "file_dialog", 0.7, "File operation dialogs"),
            
            // Settings dialogs
            (r"(?i)(settings|preferences|options|configuration)", "settings_dialog", 0.8, "Settings and preferences"),
            (r"(?i)(apply|reset|default)", "settings_dialog", 0.6, "Settings actions"),
            
            // Progress dialogs
            (r"(?i)(progress|loading|please wait|processing)", "progress_dialog", 0.8, "Progress indicators"),
            (r"(?i)(\d+%|completed|remaining)", "progress_dialog", 0.7, "Progress measurements"),
            
            // Information dialogs
            (r"(?i)(information|about|help)", "info_dialog", 0.7, "Information dialogs"),
            (r"(?i)(close|dismiss)", "info_dialog", 0.5, "Dialog close actions"),
        ];
        
        let mut compiled = Vec::new();
        for (pattern, pattern_type, weight, description) in patterns {
            match Regex::new(pattern) {
                Ok(regex) => {
                    compiled.push(CompiledPattern {
                        regex,
                        pattern_type: pattern_type.to_string(),
                        confidence_weight: weight,
                        description: description.to_string(),
                    });
                }
                Err(e) => {
                    warn!("Failed to compile modal pattern '{}': {}", pattern, e);
                }
            }
        }
        
        Ok(compiled)
    }
    
    /// Compile system alert detection patterns
    fn compile_system_alert_patterns() -> Result<Vec<CompiledPattern>> {
        let patterns = vec![
            // macOS system alerts
            (r"(?i)(system alert|system notification)", "system_alert", 0.9, "System alerts"),
            (r"(?i)(would like to access|permission required)", "system_alert", 0.85, "Permission requests"),
            (r"(?i)(security warning|security alert)", "system_alert", 0.9, "Security warnings"),
            
            // Application alerts
            (r"(?i)(application (error|warning)|app (crashed|stopped))", "app_alert", 0.8, "Application alerts"),
            (r"(?i)(update available|new version)", "app_alert", 0.7, "Update notifications"),
        ];
        
        let mut compiled = Vec::new();
        for (pattern, pattern_type, weight, description) in patterns {
            match Regex::new(pattern) {
                Ok(regex) => {
                    compiled.push(CompiledPattern {
                        regex,
                        pattern_type: pattern_type.to_string(),
                        confidence_weight: weight,
                        description: description.to_string(),
                    });
                }
                Err(e) => {
                    warn!("Failed to compile system alert pattern '{}': {}", pattern, e);
                }
            }
        }
        
        Ok(compiled)
    }
}

impl DialogLayoutAnalyzer {
    fn new(config: ErrorModalDetectionConfig) -> Self {
        Self { config }
    }
    
    /// Analyze layout to determine if it looks like a dialog
    fn analyze_layout(
        &self,
        roi: &BoundingBox,
        screen_width: f32,
        screen_height: f32,
    ) -> LayoutAnalysis {
        let dialog_width = roi.width;
        let dialog_height = roi.height;
        
        // Check size constraints
        let size_ok = dialog_width >= self.config.min_dialog_width
            && dialog_height >= self.config.min_dialog_height
            && dialog_width <= screen_width * self.config.max_dialog_width_ratio
            && dialog_height <= screen_height * self.config.max_dialog_height_ratio;
        
        // Check if dialog is centered
        let center_x = roi.x + roi.width / 2.0;
        let center_y = roi.y + roi.height / 2.0;
        let screen_center_x = screen_width / 2.0;
        let screen_center_y = screen_height / 2.0;
        
        let center_x_ratio = center_x / screen_width;
        let center_y_ratio = center_y / screen_height;
        
        let center_tolerance = 0.2; // 20% tolerance from center
        let is_centered = (center_x - screen_center_x).abs() <= screen_width * center_tolerance
            && (center_y - screen_center_y).abs() <= screen_height * center_tolerance;
        
        // Calculate layout confidence
        let mut confidence = 0.0;
        
        if size_ok {
            confidence += 0.4;
        }
        
        if is_centered {
            confidence += 0.3;
        }
        
        // Aspect ratio check (dialogs are usually wider than tall, but not too wide)
        let aspect_ratio = dialog_width / dialog_height;
        if aspect_ratio >= 0.8 && aspect_ratio <= 3.0 {
            confidence += 0.2;
        }
        
        // Position check (not at screen edges)
        let margin = 50.0;
        if roi.x > margin && roi.y > margin 
            && roi.x + roi.width < screen_width - margin
            && roi.y + roi.height < screen_height - margin {
            confidence += 0.1;
        }
        
        let is_dialog_layout = confidence >= 0.6;
        
        LayoutAnalysis {
            is_dialog_layout,
            dialog_width,
            dialog_height,
            center_x_ratio,
            center_y_ratio,
            is_centered,
            layout_confidence: confidence,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ocr_data::BoundingBox;
    
    #[test]
    fn test_error_pattern_matching() {
        let detector = ErrorModalDetector::new().unwrap();
        
        // Test error patterns
        assert!(detector.error_patterns.iter().any(|p| p.regex.is_match("Fatal error occurred")));
        assert!(detector.error_patterns.iter().any(|p| p.regex.is_match("Connection failed")));
        assert!(detector.error_patterns.iter().any(|p| p.regex.is_match("Access denied")));
        assert!(detector.error_patterns.iter().any(|p| p.regex.is_match("Invalid input format")));
    }
    
    #[test]
    fn test_modal_pattern_matching() {
        let detector = ErrorModalDetector::new().unwrap();
        
        // Test modal patterns
        assert!(detector.modal_patterns.iter().any(|p| p.regex.is_match("Are you sure you want to delete?")));
        assert!(detector.modal_patterns.iter().any(|p| p.regex.is_match("Save file as")));
        assert!(detector.modal_patterns.iter().any(|p| p.regex.is_match("Settings and preferences")));
        assert!(detector.modal_patterns.iter().any(|p| p.regex.is_match("Loading... 50%")));
    }
    
    #[test]
    fn test_layout_analysis() {
        let config = ErrorModalDetectionConfig::default();
        let analyzer = DialogLayoutAnalyzer::new(config);
        
        // Test centered dialog
        let centered_dialog = BoundingBox {
            x: 300.0,
            y: 200.0,
            width: 400.0,
            height: 200.0,
        };
        
        let analysis = analyzer.analyze_layout(&centered_dialog, 1000.0, 600.0);
        assert!(analysis.is_dialog_layout);
        assert!(analysis.is_centered);
        assert!(analysis.layout_confidence > 0.6);
    }
    
    #[test]
    fn test_dialog_classification() {
        let detector = ErrorModalDetector::new().unwrap();
        
        assert_eq!(
            detector.classify_dialog_by_content("Save file as document.txt"),
            ErrorModalType::FileDialog
        );
        
        assert_eq!(
            detector.classify_dialog_by_content("Are you sure you want to delete this item?"),
            ErrorModalType::ConfirmationDialog
        );
        
        assert_eq!(
            detector.classify_dialog_by_content("Error: Connection failed"),
            ErrorModalType::ApplicationError
        );
    }
    
    #[test]
    fn test_severity_determination() {
        let detector = ErrorModalDetector::new().unwrap();
        
        assert_eq!(
            detector.determine_severity_by_content("Critical system failure"),
            SeverityLevel::Critical
        );
        
        assert_eq!(
            detector.determine_severity_by_content("Error: File not found"),
            SeverityLevel::High
        );
        
        assert_eq!(
            detector.determine_severity_by_content("Warning: Disk space low"),
            SeverityLevel::Medium
        );
        
        assert_eq!(
            detector.determine_severity_by_content("Information: Task completed"),
            SeverityLevel::Info
        );
    }
}