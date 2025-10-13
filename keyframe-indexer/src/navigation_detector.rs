use crate::error::{IndexerError, Result};
use crate::event_detector::{DetectedEvent, EventType};
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use std::process::Command;
use tracing::{debug, info, warn, error};

/// Navigation event detector for window and tab changes according to requirements 4.2 and 4.3
pub struct NavigationDetector {
    /// Configuration for navigation detection
    config: NavigationDetectionConfig,
    /// Previous window state for change detection
    previous_window_state: Option<WindowState>,
    /// Previous tab state for change detection
    previous_tab_state: Option<TabState>,
    /// Application focus history
    focus_history: Vec<FocusEvent>,
    /// Maximum history size to maintain
    max_history_size: usize,
}

/// Configuration for navigation detection behavior
#[derive(Debug, Clone)]
pub struct NavigationDetectionConfig {
    /// Enable window change detection
    pub enable_window_detection: bool,
    /// Enable tab change detection
    pub enable_tab_detection: bool,
    /// Enable application focus detection
    pub enable_focus_detection: bool,
    /// Minimum time between detections to avoid noise (milliseconds)
    pub min_detection_interval_ms: u64,
    /// Confidence threshold for navigation events
    pub min_confidence: f32,
}

impl Default for NavigationDetectionConfig {
    fn default() -> Self {
        Self {
            enable_window_detection: true,
            enable_tab_detection: true,
            enable_focus_detection: true,
            min_detection_interval_ms: 100,
            min_confidence: 0.8,
        }
    }
}

/// Represents the current window state
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WindowState {
    pub app_name: String,
    pub window_title: String,
    pub window_id: Option<i32>,
    pub bundle_id: Option<String>,
    pub process_id: i32,
    pub timestamp: DateTime<Utc>,
}

/// Represents the current tab state (for browsers and tab-based apps)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TabState {
    pub app_name: String,
    pub tab_title: String,
    pub url: Option<String>,
    pub tab_index: Option<i32>,
    pub timestamp: DateTime<Utc>,
}

/// Represents an application focus change event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FocusEvent {
    pub from_app: Option<String>,
    pub to_app: String,
    pub from_bundle_id: Option<String>,
    pub to_bundle_id: String,
    pub timestamp: DateTime<Utc>,
    pub confidence: f32,
}

impl NavigationDetector {
    /// Create a new navigation detector with default configuration
    pub fn new() -> Self {
        Self::with_config(NavigationDetectionConfig::default())
    }
    
    /// Create a new navigation detector with custom configuration
    pub fn with_config(config: NavigationDetectionConfig) -> Self {
        Self {
            config,
            previous_window_state: None,
            previous_tab_state: None,
            focus_history: Vec::new(),
            max_history_size: 100,
        }
    }
    
    /// Detect navigation events by analyzing current system state
    pub async fn detect_navigation_events(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        debug!("Detecting navigation events for frame {}", frame_id);
        
        let mut events = Vec::new();
        
        // Detect window changes
        if self.config.enable_window_detection {
            if let Ok(window_events) = self.detect_window_changes(frame_id, timestamp).await {
                events.extend(window_events);
            }
        }
        
        // Detect tab changes
        if self.config.enable_tab_detection {
            if let Ok(tab_events) = self.detect_tab_changes(frame_id, timestamp).await {
                events.extend(tab_events);
            }
        }
        
        // Detect application focus changes
        if self.config.enable_focus_detection {
            if let Ok(focus_events) = self.detect_focus_changes(frame_id, timestamp).await {
                events.extend(focus_events);
            }
        }
        
        info!("Detected {} navigation events for frame {}", events.len(), frame_id);
        Ok(events)
    }
    
    /// Detect window changes using macOS system APIs
    async fn detect_window_changes(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        let current_window_state = self.get_current_window_state().await?;
        let mut events = Vec::new();
        
        // Check if window state has changed
        if let Some(previous_state) = &self.previous_window_state {
            if current_window_state != *previous_state {
                // Check minimum interval to avoid noise
                let time_diff = timestamp.signed_duration_since(previous_state.timestamp);
                if time_diff.num_milliseconds() >= self.config.min_detection_interval_ms as i64 {
                    
                    // Determine the type of window change
                    let (event_type, change_description) = if current_window_state.app_name != previous_state.app_name {
                        (EventType::Navigation, "application_switch")
                    } else if current_window_state.window_title != previous_state.window_title {
                        (EventType::Navigation, "window_change")
                    } else {
                        (EventType::Navigation, "window_focus_change")
                    };
                    
                    let event = DetectedEvent {
                        id: uuid::Uuid::new_v4().to_string(),
                        timestamp,
                        event_type,
                        target: format!("window_{}_{}", current_window_state.app_name, current_window_state.process_id),
                        value_from: Some(format!("{}:{}", previous_state.app_name, previous_state.window_title)),
                        value_to: Some(format!("{}:{}", current_window_state.app_name, current_window_state.window_title)),
                        confidence: self.config.min_confidence,
                        evidence_frames: vec![frame_id.to_string()],
                        metadata: self.create_window_metadata(&current_window_state, previous_state, change_description),
                    };
                    
                    events.push(event);
                    debug!("Detected window change: {} -> {}", 
                           previous_state.window_title, 
                           current_window_state.window_title);
                }
            }
        }
        
        // Update previous state
        self.previous_window_state = Some(current_window_state);
        
        Ok(events)
    }
    
    /// Detect tab changes in browsers and tab-based applications
    async fn detect_tab_changes(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        let current_tab_state = self.get_current_tab_state().await?;
        let mut events = Vec::new();
        
        if let Some(current_tab) = current_tab_state {
            // Check if tab state has changed
            if let Some(previous_tab) = &self.previous_tab_state {
                if current_tab != *previous_tab {
                    // Check minimum interval
                    let time_diff = timestamp.signed_duration_since(previous_tab.timestamp);
                    if time_diff.num_milliseconds() >= self.config.min_detection_interval_ms as i64 {
                        
                        let event = DetectedEvent {
                            id: uuid::Uuid::new_v4().to_string(),
                            timestamp,
                            event_type: EventType::Navigation,
                            target: format!("tab_{}_{}", current_tab.app_name, current_tab.tab_index.unwrap_or(0)),
                            value_from: Some(previous_tab.tab_title.clone()),
                            value_to: Some(current_tab.tab_title.clone()),
                            confidence: self.config.min_confidence * 0.9, // Slightly lower confidence for tab detection
                            evidence_frames: vec![frame_id.to_string()],
                            metadata: self.create_tab_metadata(&current_tab, previous_tab),
                        };
                        
                        events.push(event);
                        debug!("Detected tab change: {} -> {}", 
                               previous_tab.tab_title, 
                               current_tab.tab_title);
                    }
                }
            }
            
            // Update previous tab state
            self.previous_tab_state = Some(current_tab);
        }
        
        Ok(events)
    }
    
    /// Detect application focus changes
    async fn detect_focus_changes(&mut self, frame_id: &str, timestamp: DateTime<Utc>) -> Result<Vec<DetectedEvent>> {
        let current_focus = self.get_current_focus_state().await?;
        let mut events = Vec::new();
        
        // Check if this is a new focus event
        let is_new_focus = if let Some(last_focus) = self.focus_history.last() {
            last_focus.to_app != current_focus.to_app || 
            last_focus.to_bundle_id != current_focus.to_bundle_id
        } else {
            true
        };
        
        if is_new_focus {
            // Check minimum interval
            let should_record = if let Some(last_focus) = self.focus_history.last() {
                let time_diff = timestamp.signed_duration_since(last_focus.timestamp);
                time_diff.num_milliseconds() >= self.config.min_detection_interval_ms as i64
            } else {
                true
            };
            
            if should_record {
                let event = DetectedEvent {
                    id: uuid::Uuid::new_v4().to_string(),
                    timestamp,
                    event_type: EventType::Navigation,
                    target: format!("focus_{}", current_focus.to_bundle_id),
                    value_from: current_focus.from_app.clone(),
                    value_to: Some(current_focus.to_app.clone()),
                    confidence: current_focus.confidence,
                    evidence_frames: vec![frame_id.to_string()],
                    metadata: self.create_focus_metadata(&current_focus),
                };
                
                events.push(event);
                
                // Add to focus history
                self.focus_history.push(current_focus);
                
                // Maintain history size
                if self.focus_history.len() > self.max_history_size {
                    self.focus_history.remove(0);
                }
                
                debug!("Detected focus change to: {}", self.focus_history.last().unwrap().to_app);
            }
        }
        
        Ok(events)
    }
    
    /// Get current window state using macOS APIs
    async fn get_current_window_state(&self) -> Result<WindowState> {
        let script = r#"
            tell application "System Events"
                set frontApp to first application process whose frontmost is true
                set appName to name of frontApp
                set bundleId to bundle identifier of frontApp
                set processId to unix id of frontApp
                try
                    set winTitle to name of first window of frontApp
                    set winId to id of first window of frontApp
                on error
                    set winTitle to ""
                    set winId to 0
                end try
                return appName & "|" & winTitle & "|" & bundleId & "|" & processId & "|" & winId
            end tell
        "#;
        
        let output = Command::new("osascript")
            .arg("-e")
            .arg(script)
            .output()
            .map_err(|e| IndexerError::Navigation(format!("Failed to get window state: {}", e)))?;
        
        if !output.status.success() {
            return Err(IndexerError::Navigation(
                format!("AppleScript failed: {}", String::from_utf8_lossy(&output.stderr))
            ));
        }
        
        let result = String::from_utf8_lossy(&output.stdout);
        let parts: Vec<&str> = result.trim().split('|').collect();
        
        if parts.len() < 5 {
            return Err(IndexerError::Navigation("Invalid AppleScript response".to_string()));
        }
        
        Ok(WindowState {
            app_name: parts[0].to_string(),
            window_title: parts[1].to_string(),
            bundle_id: if parts[2].is_empty() { None } else { Some(parts[2].to_string()) },
            process_id: parts[3].parse().unwrap_or(0),
            window_id: if parts[4] == "0" { None } else { parts[4].parse().ok() },
            timestamp: Utc::now(),
        })
    }
    
    /// Get current tab state for browsers and tab-based applications
    async fn get_current_tab_state(&self) -> Result<Option<TabState>> {
        // Try to get tab information from supported browsers
        if let Ok(safari_tab) = self.get_safari_tab_state().await {
            return Ok(Some(safari_tab));
        }
        
        if let Ok(chrome_tab) = self.get_chrome_tab_state().await {
            return Ok(Some(chrome_tab));
        }
        
        // Add support for other browsers as needed
        Ok(None)
    }
    
    /// Get Safari tab state using AppleScript
    async fn get_safari_tab_state(&self) -> Result<TabState> {
        let script = r#"
            tell application "Safari"
                if (count of windows) > 0 then
                    set currentTab to current tab of front window
                    set tabTitle to name of currentTab
                    set tabURL to URL of currentTab
                    set tabIndex to index of currentTab
                    return tabTitle & "|" & tabURL & "|" & tabIndex
                else
                    return "||0"
                end if
            end tell
        "#;
        
        let output = Command::new("osascript")
            .arg("-e")
            .arg(script)
            .output()
            .map_err(|e| IndexerError::Navigation(format!("Failed to get Safari tab: {}", e)))?;
        
        if !output.status.success() {
            return Err(IndexerError::Navigation("Safari not available".to_string()));
        }
        
        let result = String::from_utf8_lossy(&output.stdout);
        let parts: Vec<&str> = result.trim().split('|').collect();
        
        if parts.len() < 3 {
            return Err(IndexerError::Navigation("Invalid Safari response".to_string()));
        }
        
        Ok(TabState {
            app_name: "Safari".to_string(),
            tab_title: parts[0].to_string(),
            url: if parts[1].is_empty() { None } else { Some(parts[1].to_string()) },
            tab_index: parts[2].parse().ok(),
            timestamp: Utc::now(),
        })
    }
    
    /// Get Chrome tab state using AppleScript
    async fn get_chrome_tab_state(&self) -> Result<TabState> {
        let script = r#"
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    set currentTab to active tab of front window
                    set tabTitle to title of currentTab
                    set tabURL to URL of currentTab
                    return tabTitle & "|" & tabURL & "|1"
                else
                    return "||0"
                end if
            end tell
        "#;
        
        let output = Command::new("osascript")
            .arg("-e")
            .arg(script)
            .output()
            .map_err(|e| IndexerError::Navigation(format!("Failed to get Chrome tab: {}", e)))?;
        
        if !output.status.success() {
            return Err(IndexerError::Navigation("Chrome not available".to_string()));
        }
        
        let result = String::from_utf8_lossy(&output.stdout);
        let parts: Vec<&str> = result.trim().split('|').collect();
        
        if parts.len() < 3 {
            return Err(IndexerError::Navigation("Invalid Chrome response".to_string()));
        }
        
        Ok(TabState {
            app_name: "Google Chrome".to_string(),
            tab_title: parts[0].to_string(),
            url: if parts[1].is_empty() { None } else { Some(parts[1].to_string()) },
            tab_index: parts[2].parse().ok(),
            timestamp: Utc::now(),
        })
    }
    
    /// Get current application focus state
    async fn get_current_focus_state(&self) -> Result<FocusEvent> {
        let current_window = self.get_current_window_state().await?;
        
        // Determine previous app from history
        let from_app = self.focus_history.last().map(|f| f.to_app.clone());
        let from_bundle_id = self.focus_history.last().map(|f| f.to_bundle_id.clone());
        
        Ok(FocusEvent {
            from_app,
            to_app: current_window.app_name,
            from_bundle_id,
            to_bundle_id: current_window.bundle_id.unwrap_or_else(|| "unknown".to_string()),
            timestamp: Utc::now(),
            confidence: self.config.min_confidence,
        })
    }
    
    /// Create metadata for window events
    fn create_window_metadata(&self, current: &WindowState, previous: &WindowState, change_type: &str) -> HashMap<String, String> {
        let mut metadata = HashMap::new();
        metadata.insert("change_type".to_string(), change_type.to_string());
        metadata.insert("current_app".to_string(), current.app_name.clone());
        metadata.insert("current_window".to_string(), current.window_title.clone());
        metadata.insert("current_bundle_id".to_string(), current.bundle_id.clone().unwrap_or_default());
        metadata.insert("current_process_id".to_string(), current.process_id.to_string());
        metadata.insert("previous_app".to_string(), previous.app_name.clone());
        metadata.insert("previous_window".to_string(), previous.window_title.clone());
        metadata.insert("previous_bundle_id".to_string(), previous.bundle_id.clone().unwrap_or_default());
        metadata.insert("previous_process_id".to_string(), previous.process_id.to_string());
        
        if let Some(window_id) = current.window_id {
            metadata.insert("window_id".to_string(), window_id.to_string());
        }
        
        metadata
    }
    
    /// Create metadata for tab events
    fn create_tab_metadata(&self, current: &TabState, previous: &TabState) -> HashMap<String, String> {
        let mut metadata = HashMap::new();
        metadata.insert("change_type".to_string(), "tab_change".to_string());
        metadata.insert("app_name".to_string(), current.app_name.clone());
        metadata.insert("current_tab".to_string(), current.tab_title.clone());
        metadata.insert("previous_tab".to_string(), previous.tab_title.clone());
        
        if let Some(url) = &current.url {
            metadata.insert("current_url".to_string(), url.clone());
        }
        if let Some(url) = &previous.url {
            metadata.insert("previous_url".to_string(), url.clone());
        }
        if let Some(index) = current.tab_index {
            metadata.insert("tab_index".to_string(), index.to_string());
        }
        
        metadata
    }
    
    /// Create metadata for focus events
    fn create_focus_metadata(&self, focus_event: &FocusEvent) -> HashMap<String, String> {
        let mut metadata = HashMap::new();
        metadata.insert("change_type".to_string(), "focus_change".to_string());
        metadata.insert("to_app".to_string(), focus_event.to_app.clone());
        metadata.insert("to_bundle_id".to_string(), focus_event.to_bundle_id.clone());
        
        if let Some(from_app) = &focus_event.from_app {
            metadata.insert("from_app".to_string(), from_app.clone());
        }
        if let Some(from_bundle_id) = &focus_event.from_bundle_id {
            metadata.insert("from_bundle_id".to_string(), from_bundle_id.clone());
        }
        
        metadata
    }
    
    /// Get recent focus history
    pub fn get_focus_history(&self) -> &[FocusEvent] {
        &self.focus_history
    }
    
    /// Get current window state (if available)
    pub fn get_current_window(&self) -> Option<&WindowState> {
        self.previous_window_state.as_ref()
    }
    
    /// Get current tab state (if available)
    pub fn get_current_tab(&self) -> Option<&TabState> {
        self.previous_tab_state.as_ref()
    }
    
    /// Clear all cached state
    pub fn clear_state(&mut self) {
        self.previous_window_state = None;
        self.previous_tab_state = None;
        self.focus_history.clear();
    }
    
    /// Update configuration
    pub fn update_config(&mut self, config: NavigationDetectionConfig) {
        self.config = config;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_navigation_detector_creation() {
        let detector = NavigationDetector::new();
        assert!(detector.previous_window_state.is_none());
        assert!(detector.previous_tab_state.is_none());
        assert!(detector.focus_history.is_empty());
    }
    
    #[test]
    fn test_window_state_equality() {
        let state1 = WindowState {
            app_name: "Safari".to_string(),
            window_title: "Test Page".to_string(),
            window_id: Some(123),
            bundle_id: Some("com.apple.Safari".to_string()),
            process_id: 456,
            timestamp: Utc::now(),
        };
        
        let mut state2 = state1.clone();
        assert_eq!(state1, state2);
        
        state2.window_title = "Different Page".to_string();
        assert_ne!(state1, state2);
    }
    
    #[test]
    fn test_tab_state_equality() {
        let tab1 = TabState {
            app_name: "Safari".to_string(),
            tab_title: "Test Page".to_string(),
            url: Some("https://example.com".to_string()),
            tab_index: Some(1),
            timestamp: Utc::now(),
        };
        
        let mut tab2 = tab1.clone();
        assert_eq!(tab1, tab2);
        
        tab2.url = Some("https://different.com".to_string());
        assert_ne!(tab1, tab2);
    }
    
    #[test]
    fn test_configuration_update() {
        let mut detector = NavigationDetector::new();
        
        let new_config = NavigationDetectionConfig {
            enable_window_detection: false,
            enable_tab_detection: true,
            enable_focus_detection: false,
            min_detection_interval_ms: 500,
            min_confidence: 0.9,
        };
        
        detector.update_config(new_config.clone());
        assert!(!detector.config.enable_window_detection);
        assert_eq!(detector.config.min_detection_interval_ms, 500);
        assert_eq!(detector.config.min_confidence, 0.9);
    }
    
    #[test]
    fn test_focus_history_management() {
        let mut detector = NavigationDetector::new();
        detector.max_history_size = 3;
        
        // Add focus events
        for i in 0..5 {
            let focus_event = FocusEvent {
                from_app: None,
                to_app: format!("App{}", i),
                from_bundle_id: None,
                to_bundle_id: format!("com.app{}", i),
                timestamp: Utc::now(),
                confidence: 0.8,
            };
            detector.focus_history.push(focus_event);
            
            // Maintain history size
            if detector.focus_history.len() > detector.max_history_size {
                detector.focus_history.remove(0);
            }
        }
        
        // Should only keep the last 3 events
        assert_eq!(detector.focus_history.len(), 3);
        assert_eq!(detector.focus_history[0].to_app, "App2");
        assert_eq!(detector.focus_history[2].to_app, "App4");
    }
    
    #[test]
    fn test_metadata_creation() {
        let detector = NavigationDetector::new();
        
        let current = WindowState {
            app_name: "Safari".to_string(),
            window_title: "New Page".to_string(),
            window_id: Some(123),
            bundle_id: Some("com.apple.Safari".to_string()),
            process_id: 456,
            timestamp: Utc::now(),
        };
        
        let previous = WindowState {
            app_name: "Safari".to_string(),
            window_title: "Old Page".to_string(),
            window_id: Some(122),
            bundle_id: Some("com.apple.Safari".to_string()),
            process_id: 456,
            timestamp: Utc::now(),
        };
        
        let metadata = detector.create_window_metadata(&current, &previous, "window_change");
        
        assert_eq!(metadata.get("change_type"), Some(&"window_change".to_string()));
        assert_eq!(metadata.get("current_window"), Some(&"New Page".to_string()));
        assert_eq!(metadata.get("previous_window"), Some(&"Old Page".to_string()));
        assert_eq!(metadata.get("window_id"), Some(&"123".to_string()));
    }
}