use crate::error_modal_detector::{
    ErrorModalDetector, ErrorModalDetectionConfig, ErrorModalEvent, ErrorModalType, SeverityLevel
};
use crate::ocr_data::{OCRResult, BoundingBox};
use chrono::{DateTime, Utc};

/// Helper function to create OCRResult with default values
fn create_ocr_result(text: &str, roi: BoundingBox, confidence: f32) -> OCRResult {
    OCRResult {
        frame_id: "test_frame".to_string(),
        text: text.to_string(),
        roi,
        confidence,
        language: "en".to_string(),
        processor: "vision".to_string(),
        processed_at: Utc::now(),
    }
}

/// Test data for error and modal detection
pub struct ErrorModalTestData;

impl ErrorModalTestData {
    /// Create test OCR results for various error conditions
    pub fn create_error_test_cases() -> Vec<(String, OCRResult, ErrorModalType, SeverityLevel)> {
        vec![
            // Critical system errors
            (
                "Fatal system crash".to_string(),
                create_ocr_result(
                    "Fatal error: System crash detected",
                    BoundingBox { x: 100.0, y: 100.0, width: 400.0, height: 50.0 },
                    0.9
                ),
                ErrorModalType::SystemError,
                SeverityLevel::Critical,
            ),
            (
                "Segmentation fault".to_string(),
                OCRResult {
                    text: "Segmentation fault in process 1234".to_string(),
                    roi: BoundingBox { x: 150.0, y: 200.0, width: 350.0, height: 40.0 },
                    confidence: 0.95,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::SystemError,
                SeverityLevel::Critical,
            ),
            
            // Network errors
            (
                "Connection failed".to_string(),
                OCRResult {
                    text: "Connection failed: Unable to reach server".to_string(),
                    roi: BoundingBox { x: 200.0, y: 150.0, width: 300.0, height: 60.0 },
                    confidence: 0.85,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::NetworkError,
                SeverityLevel::High,
            ),
            (
                "DNS error".to_string(),
                OCRResult {
                    text: "DNS error: Host not found".to_string(),
                    roi: BoundingBox { x: 180.0, y: 180.0, width: 280.0, height: 45.0 },
                    confidence: 0.8,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::NetworkError,
                SeverityLevel::High,
            ),
            
            // Authentication errors
            (
                "Access denied".to_string(),
                OCRResult {
                    text: "Access denied: Insufficient privileges".to_string(),
                    roi: BoundingBox { x: 120.0, y: 120.0, width: 320.0, height: 50.0 },
                    confidence: 0.88,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::AuthError,
                SeverityLevel::High,
            ),
            (
                "Login failed".to_string(),
                OCRResult {
                    text: "Login failed: Incorrect password".to_string(),
                    roi: BoundingBox { x: 160.0, y: 160.0, width: 300.0, height: 55.0 },
                    confidence: 0.9,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::AuthError,
                SeverityLevel::High,
            ),
            
            // Validation errors
            (
                "Invalid input".to_string(),
                OCRResult {
                    text: "Invalid input format: Please enter a valid email".to_string(),
                    roi: BoundingBox { x: 140.0, y: 300.0, width: 360.0, height: 40.0 },
                    confidence: 0.75,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::ValidationError,
                SeverityLevel::Medium,
            ),
            (
                "Required field".to_string(),
                OCRResult {
                    text: "Required field: This field cannot be empty".to_string(),
                    roi: BoundingBox { x: 130.0, y: 350.0, width: 340.0, height: 35.0 },
                    confidence: 0.82,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::ValidationError,
                SeverityLevel::Medium,
            ),
            
            // Warnings
            (
                "Warning message".to_string(),
                OCRResult {
                    text: "Warning: Disk space is running low".to_string(),
                    roi: BoundingBox { x: 170.0, y: 250.0, width: 290.0, height: 45.0 },
                    confidence: 0.78,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::Warning,
                SeverityLevel::Medium,
            ),
        ]
    }
    
    /// Create test OCR results for various modal dialog conditions
    pub fn create_modal_test_cases() -> Vec<(String, OCRResult, ErrorModalType, SeverityLevel)> {
        vec![
            // Confirmation dialogs
            (
                "Confirmation dialog".to_string(),
                OCRResult {
                    text: "Are you sure you want to delete this file?".to_string(),
                    roi: BoundingBox { x: 300.0, y: 200.0, width: 400.0, height: 100.0 },
                    confidence: 0.9,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::ConfirmationDialog,
                SeverityLevel::Info,
            ),
            (
                "Dialog buttons".to_string(),
                OCRResult {
                    text: "Yes    No    Cancel".to_string(),
                    roi: BoundingBox { x: 350.0, y: 280.0, width: 200.0, height: 40.0 },
                    confidence: 0.85,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::ConfirmationDialog,
                SeverityLevel::Info,
            ),
            
            // File dialogs
            (
                "Save file dialog".to_string(),
                OCRResult {
                    text: "Save file as: document.txt".to_string(),
                    roi: BoundingBox { x: 250.0, y: 150.0, width: 500.0, height: 300.0 },
                    confidence: 0.88,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::FileDialog,
                SeverityLevel::Info,
            ),
            (
                "Open file dialog".to_string(),
                OCRResult {
                    text: "Choose file to open".to_string(),
                    roi: BoundingBox { x: 200.0, y: 100.0, width: 600.0, height: 400.0 },
                    confidence: 0.92,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::FileDialog,
                SeverityLevel::Info,
            ),
            
            // Settings dialogs
            (
                "Settings dialog".to_string(),
                OCRResult {
                    text: "Settings and Preferences".to_string(),
                    roi: BoundingBox { x: 300.0, y: 100.0, width: 400.0, height: 500.0 },
                    confidence: 0.9,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::SettingsDialog,
                SeverityLevel::Info,
            ),
            
            // Progress dialogs
            (
                "Progress dialog".to_string(),
                OCRResult {
                    text: "Loading... 45% completed".to_string(),
                    roi: BoundingBox { x: 350.0, y: 250.0, width: 300.0, height: 80.0 },
                    confidence: 0.87,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::ProgressDialog,
                SeverityLevel::Info,
            ),
            
            // Information dialogs
            (
                "Info dialog".to_string(),
                OCRResult {
                    text: "Information: Task completed successfully".to_string(),
                    roi: BoundingBox { x: 280.0, y: 200.0, width: 440.0, height: 120.0 },
                    confidence: 0.83,
                    language: "en".to_string(),
                    processor: "vision".to_string(),
                },
                ErrorModalType::InfoDialog,
                SeverityLevel::Info,
            ),
        ]
    }
    
    /// Create test cases for layout-based dialog detection
    pub fn create_layout_test_cases() -> Vec<(String, Vec<OCRResult>, bool, f32)> {
        vec![
            // Centered dialog layout
            (
                "Centered dialog".to_string(),
                vec![
                    OCRResult {
                        text: "Confirm Action".to_string(),
                        roi: BoundingBox { x: 400.0, y: 250.0, width: 200.0, height: 30.0 },
                        confidence: 0.9,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "Are you sure you want to proceed?".to_string(),
                        roi: BoundingBox { x: 350.0, y: 300.0, width: 300.0, height: 40.0 },
                        confidence: 0.85,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "OK    Cancel".to_string(),
                        roi: BoundingBox { x: 450.0, y: 360.0, width: 100.0, height: 30.0 },
                        confidence: 0.88,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                ],
                true,  // Should be detected as dialog
                0.8,   // Expected confidence
            ),
            
            // Large file dialog
            (
                "File dialog".to_string(),
                vec![
                    OCRResult {
                        text: "Open File".to_string(),
                        roi: BoundingBox { x: 200.0, y: 100.0, width: 100.0, height: 25.0 },
                        confidence: 0.9,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "Documents folder".to_string(),
                        roi: BoundingBox { x: 220.0, y: 150.0, width: 560.0, height: 300.0 },
                        confidence: 0.8,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "Open    Cancel".to_string(),
                        roi: BoundingBox { x: 650.0, y: 480.0, width: 120.0, height: 30.0 },
                        confidence: 0.85,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                ],
                true,  // Should be detected as dialog
                0.7,   // Expected confidence
            ),
            
            // Full-screen content (should not be detected as dialog)
            (
                "Full screen content".to_string(),
                vec![
                    OCRResult {
                        text: "Main Application Window".to_string(),
                        roi: BoundingBox { x: 0.0, y: 0.0, width: 1000.0, height: 600.0 },
                        confidence: 0.9,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                ],
                false, // Should NOT be detected as dialog
                0.3,   // Expected low confidence
            ),
            
            // Small tooltip (should not be detected as dialog)
            (
                "Small tooltip".to_string(),
                vec![
                    OCRResult {
                        text: "Tooltip".to_string(),
                        roi: BoundingBox { x: 400.0, y: 300.0, width: 80.0, height: 20.0 },
                        confidence: 0.8,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                ],
                false, // Should NOT be detected as dialog
                0.4,   // Expected low confidence
            ),
        ]
    }
    
    /// Create test screenshots data (simulated)
    pub fn create_screenshot_test_cases() -> Vec<(String, Vec<OCRResult>, Vec<ErrorModalType>)> {
        vec![
            // macOS system error dialog
            (
                "macOS system error".to_string(),
                vec![
                    OCRResult {
                        text: "The application \"TestApp\" quit unexpectedly.".to_string(),
                        roi: BoundingBox { x: 300.0, y: 200.0, width: 400.0, height: 40.0 },
                        confidence: 0.9,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "Click Reopen to open the application again.".to_string(),
                        roi: BoundingBox { x: 300.0, y: 250.0, width: 400.0, height: 30.0 },
                        confidence: 0.85,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "Ignore    Report...    Reopen".to_string(),
                        roi: BoundingBox { x: 400.0, y: 320.0, width: 200.0, height: 30.0 },
                        confidence: 0.88,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                ],
                vec![ErrorModalType::SystemError, ErrorModalType::ConfirmationDialog],
            ),
            
            // Web browser error page
            (
                "Browser error page".to_string(),
                vec![
                    OCRResult {
                        text: "This site can't be reached".to_string(),
                        roi: BoundingBox { x: 100.0, y: 150.0, width: 300.0, height: 40.0 },
                        confidence: 0.9,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "ERR_CONNECTION_REFUSED".to_string(),
                        roi: BoundingBox { x: 100.0, y: 200.0, width: 250.0, height: 30.0 },
                        confidence: 0.95,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "Try: Checking the connection".to_string(),
                        roi: BoundingBox { x: 100.0, y: 250.0, width: 280.0, height: 25.0 },
                        confidence: 0.8,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                ],
                vec![ErrorModalType::NetworkError],
            ),
            
            // Form validation errors
            (
                "Form validation".to_string(),
                vec![
                    OCRResult {
                        text: "Please correct the following errors:".to_string(),
                        roi: BoundingBox { x: 200.0, y: 100.0, width: 300.0, height: 25.0 },
                        confidence: 0.85,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "• Email address is required".to_string(),
                        roi: BoundingBox { x: 220.0, y: 130.0, width: 250.0, height: 20.0 },
                        confidence: 0.8,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                    OCRResult {
                        text: "• Password must be at least 8 characters".to_string(),
                        roi: BoundingBox { x: 220.0, y: 155.0, width: 320.0, height: 20.0 },
                        confidence: 0.82,
                        language: "en".to_string(),
                        processor: "vision".to_string(),
                    },
                ],
                vec![ErrorModalType::ValidationError],
            ),
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error_modal_detector::{ErrorModalDetector, ErrorModalDetectionConfig};
    
    #[test]
    fn test_error_detection_patterns() {
        let detector = ErrorModalDetector::new().unwrap();
        let test_cases = ErrorModalTestData::create_error_test_cases();
        let timestamp = Utc::now();
        
        for (test_name, ocr_result, expected_type, expected_severity) in test_cases {
            println!("Testing: {}", test_name);
            
            let events = detector.detect_errors_and_modals(
                "test_frame",
                &[ocr_result],
                timestamp,
                1000.0,
                600.0,
            ).unwrap();
            
            assert!(!events.is_empty(), "Should detect error for: {}", test_name);
            
            let event = &events[0];
            assert_eq!(event.event_type, expected_type, "Wrong event type for: {}", test_name);
            assert_eq!(event.severity, expected_severity, "Wrong severity for: {}", test_name);
            assert!(event.confidence >= 0.6, "Confidence too low for: {}", test_name);
        }
    }
    
    #[test]
    fn test_modal_detection_patterns() {
        let detector = ErrorModalDetector::new().unwrap();
        let test_cases = ErrorModalTestData::create_modal_test_cases();
        let timestamp = Utc::now();
        
        for (test_name, ocr_result, expected_type, expected_severity) in test_cases {
            println!("Testing: {}", test_name);
            
            let events = detector.detect_errors_and_modals(
                "test_frame",
                &[ocr_result],
                timestamp,
                1000.0,
                600.0,
            ).unwrap();
            
            assert!(!events.is_empty(), "Should detect modal for: {}", test_name);
            
            let event = &events[0];
            assert_eq!(event.event_type, expected_type, "Wrong event type for: {}", test_name);
            assert_eq!(event.severity, expected_severity, "Wrong severity for: {}", test_name);
            assert!(event.confidence >= 0.6, "Confidence too low for: {}", test_name);
        }
    }
    
    #[test]
    fn test_layout_based_detection() {
        let detector = ErrorModalDetector::new().unwrap();
        let test_cases = ErrorModalTestData::create_layout_test_cases();
        let timestamp = Utc::now();
        
        for (test_name, ocr_results, should_detect, expected_confidence) in test_cases {
            println!("Testing layout: {}", test_name);
            
            let events = detector.detect_errors_and_modals(
                "test_frame",
                &ocr_results,
                timestamp,
                1000.0,
                600.0,
            ).unwrap();
            
            if should_detect {
                assert!(!events.is_empty(), "Should detect dialog layout for: {}", test_name);
                
                // Check if any event has layout analysis
                let has_layout_analysis = events.iter().any(|e| e.layout_analysis.is_some());
                if has_layout_analysis {
                    let event_with_layout = events.iter()
                        .find(|e| e.layout_analysis.is_some())
                        .unwrap();
                    
                    let layout = event_with_layout.layout_analysis.as_ref().unwrap();
                    assert!(layout.is_dialog_layout, "Should be detected as dialog layout: {}", test_name);
                    assert!(layout.layout_confidence >= expected_confidence * 0.8, 
                           "Layout confidence too low for: {}", test_name);
                }
            } else {
                // For cases that shouldn't be detected, either no events or low confidence
                if !events.is_empty() {
                    let max_confidence = events.iter()
                        .map(|e| e.confidence)
                        .fold(0.0, f32::max);
                    assert!(max_confidence < 0.7, 
                           "Confidence too high for non-dialog: {} (got {})", test_name, max_confidence);
                }
            }
        }
    }
    
    #[test]
    fn test_confidence_scoring() {
        let detector = ErrorModalDetector::new().unwrap();
        let timestamp = Utc::now();
        
        // High confidence case
        let high_confidence_ocr = OCRResult {
            text: "Fatal error: System crash detected".to_string(),
            roi: BoundingBox { x: 100.0, y: 100.0, width: 400.0, height: 50.0 },
            confidence: 0.95,
            language: "en".to_string(),
            processor: "vision".to_string(),
        };
        
        let events = detector.detect_errors_and_modals(
            "test_frame",
            &[high_confidence_ocr],
            timestamp,
            1000.0,
            600.0,
        ).unwrap();
        
        assert!(!events.is_empty());
        assert!(events[0].confidence >= 0.8, "High confidence case should have high confidence score");
        
        // Low confidence case
        let low_confidence_ocr = OCRResult {
            text: "maybe error".to_string(),
            roi: BoundingBox { x: 100.0, y: 100.0, width: 100.0, height: 20.0 },
            confidence: 0.5,
            language: "en".to_string(),
            processor: "vision".to_string(),
        };
        
        let events = detector.detect_errors_and_modals(
            "test_frame",
            &[low_confidence_ocr],
            timestamp,
            1000.0,
            600.0,
        ).unwrap();
        
        // Should either not detect or have low confidence
        if !events.is_empty() {
            assert!(events[0].confidence < 0.7, "Low confidence case should have low confidence score");
        }
    }
    
    #[test]
    fn test_pattern_matching_accuracy() {
        let detector = ErrorModalDetector::new().unwrap();
        
        // Test specific pattern matches
        let test_patterns = vec![
            ("Fatal error occurred", true, "Should match critical error pattern"),
            ("Connection failed to server", true, "Should match network error pattern"),
            ("Access denied by system", true, "Should match auth error pattern"),
            ("Invalid email format", true, "Should match validation error pattern"),
            ("Are you sure you want to delete?", true, "Should match confirmation dialog pattern"),
            ("Save file as document.txt", true, "Should match file dialog pattern"),
            ("Regular text content", false, "Should not match any error pattern"),
            ("Welcome to the application", false, "Should not match any error pattern"),
        ];
        
        let timestamp = Utc::now();
        
        for (text, should_match, description) in test_patterns {
            let ocr_result = OCRResult {
                text: text.to_string(),
                roi: BoundingBox { x: 100.0, y: 100.0, width: 300.0, height: 50.0 },
                confidence: 0.9,
                language: "en".to_string(),
                processor: "vision".to_string(),
            };
            
            let events = detector.detect_errors_and_modals(
                "test_frame",
                &[ocr_result],
                timestamp,
                1000.0,
                600.0,
            ).unwrap();
            
            if should_match {
                assert!(!events.is_empty(), "{}: '{}'", description, text);
            } else {
                assert!(events.is_empty() || events[0].confidence < 0.6, 
                       "{}: '{}' (got {} events)", description, text, events.len());
            }
        }
    }
    
    #[test]
    fn test_severity_classification() {
        let detector = ErrorModalDetector::new().unwrap();
        let timestamp = Utc::now();
        
        let severity_test_cases = vec![
            ("Critical system failure", SeverityLevel::Critical),
            ("Fatal error in application", SeverityLevel::Critical),
            ("Error: File not found", SeverityLevel::High),
            ("Network connection failed", SeverityLevel::High),
            ("Warning: Low disk space", SeverityLevel::Medium),
            ("Invalid input format", SeverityLevel::Medium),
            ("Notice: Update available", SeverityLevel::Low),
            ("Information: Task completed", SeverityLevel::Info),
        ];
        
        for (text, expected_severity) in severity_test_cases {
            let ocr_result = OCRResult {
                text: text.to_string(),
                roi: BoundingBox { x: 100.0, y: 100.0, width: 300.0, height: 50.0 },
                confidence: 0.9,
                language: "en".to_string(),
                processor: "vision".to_string(),
            };
            
            let events = detector.detect_errors_and_modals(
                "test_frame",
                &[ocr_result],
                timestamp,
                1000.0,
                600.0,
            ).unwrap();
            
            if !events.is_empty() {
                assert_eq!(events[0].severity, expected_severity, 
                          "Wrong severity for: '{}'", text);
            }
        }
    }
    
    #[test]
    fn test_configuration_thresholds() {
        let mut config = ErrorModalDetectionConfig::default();
        config.min_error_confidence = 0.8;
        config.min_modal_confidence = 0.7;
        config.min_ocr_confidence = 0.8;
        
        let detector = ErrorModalDetector::with_config(config).unwrap();
        let timestamp = Utc::now();
        
        // Test with OCR result below threshold
        let low_ocr_confidence = OCRResult {
            text: "Fatal error occurred".to_string(),
            roi: BoundingBox { x: 100.0, y: 100.0, width: 300.0, height: 50.0 },
            confidence: 0.6, // Below threshold
            language: "en".to_string(),
            processor: "vision".to_string(),
        };
        
        let events = detector.detect_errors_and_modals(
            "test_frame",
            &[low_ocr_confidence],
            timestamp,
            1000.0,
            600.0,
        ).unwrap();
        
        // Should not detect due to low OCR confidence
        assert!(events.is_empty(), "Should not detect with low OCR confidence");
        
        // Test with high OCR confidence
        let high_ocr_confidence = OCRResult {
            text: "Fatal error occurred".to_string(),
            roi: BoundingBox { x: 100.0, y: 100.0, width: 300.0, height: 50.0 },
            confidence: 0.9, // Above threshold
            language: "en".to_string(),
            processor: "vision".to_string(),
        };
        
        let events = detector.detect_errors_and_modals(
            "test_frame",
            &[high_ocr_confidence],
            timestamp,
            1000.0,
            600.0,
        ).unwrap();
        
        // Should detect with high OCR confidence
        assert!(!events.is_empty(), "Should detect with high OCR confidence");
    }
}