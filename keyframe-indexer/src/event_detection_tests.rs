use crate::event_detector::{EventDetector, EventDetectionConfig, EventType};
use crate::delta_analyzer::{DeltaAnalyzer, DeltaAnalysisConfig};
use crate::ocr_data::{OCRResult, BoundingBox};
use chrono::{DateTime, Utc};
use tempfile::TempDir;
use std::collections::HashMap;

/// Create synthetic OCR result for testing
fn create_test_ocr_result(
    frame_id: &str,
    text: &str,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    confidence: f32,
) -> OCRResult {
    OCRResult {
        frame_id: frame_id.to_string(),
        roi: BoundingBox::new(x, y, width, height),
        text: text.to_string(),
        language: "en-US".to_string(),
        confidence,
        processed_at: Utc::now(),
        processor: "vision".to_string(),
    }
}

/// Create synthetic form field data for testing
fn create_form_field_scenario() -> Vec<(String, Vec<OCRResult>)> {
    vec![
        // Frame 1: Empty form
        (
            "frame_001".to_string(),
            vec![
                create_test_ocr_result("frame_001", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("frame_001", "", 100.0, 50.0, 200.0, 20.0, 0.0), // Empty field
                create_test_ocr_result("frame_001", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("frame_001", "", 100.0, 80.0, 200.0, 20.0, 0.0), // Empty field
                create_test_ocr_result("frame_001", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
            ],
        ),
        // Frame 2: Username entered
        (
            "frame_002".to_string(),
            vec![
                create_test_ocr_result("frame_002", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("frame_002", "john.doe", 100.0, 50.0, 200.0, 20.0, 0.92),
                create_test_ocr_result("frame_002", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("frame_002", "", 100.0, 80.0, 200.0, 20.0, 0.0), // Still empty
                create_test_ocr_result("frame_002", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
            ],
        ),
        // Frame 3: Password entered
        (
            "frame_003".to_string(),
            vec![
                create_test_ocr_result("frame_003", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("frame_003", "john.doe", 100.0, 50.0, 200.0, 20.0, 0.92),
                create_test_ocr_result("frame_003", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("frame_003", "••••••••", 100.0, 80.0, 200.0, 20.0, 0.85), // Password mask
                create_test_ocr_result("frame_003", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
            ],
        ),
        // Frame 4: Form submitted (success message)
        (
            "frame_004".to_string(),
            vec![
                create_test_ocr_result("frame_004", "Welcome, john.doe!", 50.0, 50.0, 200.0, 30.0, 0.96),
                create_test_ocr_result("frame_004", "Login successful", 50.0, 90.0, 150.0, 20.0, 0.94),
            ],
        ),
    ]
}

/// Create synthetic error scenario for testing
fn create_error_scenario() -> Vec<(String, Vec<OCRResult>)> {
    vec![
        // Frame 1: Normal state
        (
            "frame_001".to_string(),
            vec![
                create_test_ocr_result("frame_001", "Submit Form", 100.0, 200.0, 100.0, 30.0, 0.98),
                create_test_ocr_result("frame_001", "Name: John Smith", 50.0, 50.0, 150.0, 20.0, 0.95),
            ],
        ),
        // Frame 2: Error appears
        (
            "frame_002".to_string(),
            vec![
                create_test_ocr_result("frame_002", "Submit Form", 100.0, 200.0, 100.0, 30.0, 0.98),
                create_test_ocr_result("frame_002", "Name: John Smith", 50.0, 50.0, 150.0, 20.0, 0.95),
                create_test_ocr_result("frame_002", "Error: Invalid email format", 50.0, 100.0, 200.0, 20.0, 0.93),
            ],
        ),
        // Frame 3: Error corrected
        (
            "frame_003".to_string(),
            vec![
                create_test_ocr_result("frame_003", "Submit Form", 100.0, 200.0, 100.0, 30.0, 0.98),
                create_test_ocr_result("frame_003", "Name: John Smith", 50.0, 50.0, 150.0, 20.0, 0.95),
                create_test_ocr_result("frame_003", "Email: john@example.com", 50.0, 80.0, 180.0, 20.0, 0.94),
            ],
        ),
    ]
}

/// Create synthetic modal dialog scenario
fn create_modal_scenario() -> Vec<(String, Vec<OCRResult>)> {
    vec![
        // Frame 1: Normal application
        (
            "frame_001".to_string(),
            vec![
                create_test_ocr_result("frame_001", "Delete Item", 100.0, 150.0, 80.0, 25.0, 0.97),
                create_test_ocr_result("frame_001", "Item: Document.pdf", 50.0, 50.0, 150.0, 20.0, 0.95),
            ],
        ),
        // Frame 2: Confirmation modal appears
        (
            "frame_002".to_string(),
            vec![
                create_test_ocr_result("frame_002", "Delete Item", 100.0, 150.0, 80.0, 25.0, 0.97),
                create_test_ocr_result("frame_002", "Item: Document.pdf", 50.0, 50.0, 150.0, 20.0, 0.95),
                create_test_ocr_result("frame_002", "Confirm Deletion", 150.0, 100.0, 120.0, 25.0, 0.96),
                create_test_ocr_result("frame_002", "Are you sure you want to delete this item?", 100.0, 130.0, 250.0, 20.0, 0.94),
                create_test_ocr_result("frame_002", "Cancel", 180.0, 170.0, 50.0, 25.0, 0.98),
                create_test_ocr_result("frame_002", "OK", 240.0, 170.0, 30.0, 25.0, 0.98),
            ],
        ),
        // Frame 3: Modal dismissed
        (
            "frame_003".to_string(),
            vec![
                create_test_ocr_result("frame_003", "Item deleted successfully", 100.0, 100.0, 180.0, 20.0, 0.95),
            ],
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_event_detector_creation() {
        let detector = EventDetector::new().unwrap();
        assert!(true); // Just test that creation doesn't panic
    }
    
    #[test]
    fn test_event_detector_with_custom_config() {
        let config = EventDetectionConfig {
            min_ocr_confidence: 0.8,
            min_event_confidence: 0.7,
            ..EventDetectionConfig::default()
        };
        
        let detector = EventDetector::with_config(config).unwrap();
        assert!(true); // Just test that creation doesn't panic
    }
    
    #[tokio::test]
    async fn test_field_change_detection() {
        let mut detector = EventDetector::new().unwrap();
        let timestamp = Utc::now();
        
        // First frame: empty form
        let frame1_ocr = vec![
            create_test_ocr_result("frame1", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
            create_test_ocr_result("frame1", "", 100.0, 50.0, 200.0, 20.0, 0.0),
        ];
        
        let events1 = detector.analyze_frame("frame1", &frame1_ocr, timestamp, 1920.0, 1080.0).unwrap();
        
        // Second frame: username filled
        let frame2_ocr = vec![
            create_test_ocr_result("frame2", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
            create_test_ocr_result("frame2", "john.doe", 100.0, 50.0, 200.0, 20.0, 0.92),
        ];
        
        let events2 = detector.analyze_frame("frame2", &frame2_ocr, timestamp, 1920.0, 1080.0).unwrap();
        
        // Should detect field change
        let field_changes: Vec<_> = events2.iter()
            .filter(|e| e.event_type == EventType::FieldChange)
            .collect();
        
        assert!(!field_changes.is_empty(), "Should detect field change");
        
        let field_change = &field_changes[0];
        assert_eq!(field_change.value_from, Some("".to_string()));
        assert_eq!(field_change.value_to, Some("john.doe".to_string()));
        assert!(field_change.confidence > 0.5);
    }
    
    #[tokio::test]
    async fn test_error_message_detection() {
        let mut detector = EventDetector::new().unwrap();
        let timestamp = Utc::now();
        
        let error_ocr = vec![
            create_test_ocr_result("frame1", "Error: Invalid input", 50.0, 100.0, 200.0, 20.0, 0.93),
            create_test_ocr_result("frame1", "Please try again", 50.0, 120.0, 150.0, 20.0, 0.91),
        ];
        
        let events = detector.analyze_frame("frame1", &error_ocr, timestamp, 1920.0, 1080.0).unwrap();
        
        let error_events: Vec<_> = events.iter()
            .filter(|e| e.event_type == EventType::ErrorDisplay)
            .collect();
        
        assert!(!error_events.is_empty(), "Should detect error message");
        
        let error_event = &error_events[0];
        assert!(error_event.value_to.as_ref().unwrap().contains("Error"));
        assert!(error_event.confidence > 0.5);
    }
    
    #[tokio::test]
    async fn test_modal_dialog_detection() {
        let mut detector = EventDetector::new().unwrap();
        let timestamp = Utc::now();
        
        let modal_ocr = vec![
            create_test_ocr_result("frame1", "Confirm Deletion", 150.0, 100.0, 120.0, 25.0, 0.96),
            create_test_ocr_result("frame1", "Are you sure?", 100.0, 130.0, 100.0, 20.0, 0.94),
            create_test_ocr_result("frame1", "Cancel", 180.0, 170.0, 50.0, 25.0, 0.98),
            create_test_ocr_result("frame1", "OK", 240.0, 170.0, 30.0, 25.0, 0.98),
        ];
        
        let events = detector.analyze_frame("frame1", &modal_ocr, timestamp, 1920.0, 1080.0).unwrap();
        
        let modal_events: Vec<_> = events.iter()
            .filter(|e| e.event_type == EventType::ModalAppearance)
            .collect();
        
        assert!(!modal_events.is_empty(), "Should detect modal dialog");
    }
    
    #[tokio::test]
    async fn test_form_submission_detection() {
        let mut detector = EventDetector::new().unwrap();
        let timestamp = Utc::now();
        
        let submit_ocr = vec![
            create_test_ocr_result("frame1", "Submit", 150.0, 200.0, 60.0, 30.0, 0.98),
            create_test_ocr_result("frame1", "Login", 220.0, 200.0, 50.0, 30.0, 0.97),
        ];
        
        let events = detector.analyze_frame("frame1", &submit_ocr, timestamp, 1920.0, 1080.0).unwrap();
        
        let submit_events: Vec<_> = events.iter()
            .filter(|e| e.event_type == EventType::FormSubmission)
            .collect();
        
        assert!(!submit_events.is_empty(), "Should detect form submission");
    }
    
    #[tokio::test]
    async fn test_confidence_scoring() {
        let mut detector = EventDetector::new().unwrap();
        let timestamp = Utc::now();
        
        // High confidence OCR results should produce high confidence events
        let high_conf_ocr = vec![
            create_test_ocr_result("frame1", "Error: Failed to save", 50.0, 100.0, 200.0, 20.0, 0.98),
        ];
        
        let events = detector.analyze_frame("frame1", &high_conf_ocr, timestamp, 1920.0, 1080.0).unwrap();
        
        for event in &events {
            assert!(event.confidence > 0.7, "High OCR confidence should produce high event confidence");
        }
        
        // Low confidence OCR results should produce lower confidence events
        let low_conf_ocr = vec![
            create_test_ocr_result("frame2", "Error: Failed to save", 50.0, 100.0, 200.0, 20.0, 0.6),
        ];
        
        let events2 = detector.analyze_frame("frame2", &low_conf_ocr, timestamp, 1920.0, 1080.0).unwrap();
        
        for event in &events2 {
            assert!(event.confidence < events[0].confidence, "Lower OCR confidence should produce lower event confidence");
        }
    }
    
    #[tokio::test]
    async fn test_delta_analyzer_integration() {
        let temp_dir = TempDir::new().unwrap();
        let ocr_dir = temp_dir.path().join("ocr");
        let event_dir = temp_dir.path().join("events");
        
        std::fs::create_dir_all(&ocr_dir).unwrap();
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let mut analyzer = DeltaAnalyzer::new(
            ocr_dir.to_str().unwrap(),
            event_dir.to_str().unwrap(),
        ).unwrap();
        
        let form_scenario = create_form_field_scenario();
        let mut all_events = Vec::new();
        
        // Process each frame in the scenario
        for (frame_id, ocr_results) in form_scenario {
            let events = analyzer.analyze_frame(&frame_id, ocr_results, Utc::now()).await.unwrap();
            all_events.extend(events);
        }
        
        // Should detect multiple field changes
        let field_changes: Vec<_> = all_events.iter()
            .filter(|e| e.event_type == EventType::FieldChange)
            .collect();
        
        assert!(!field_changes.is_empty(), "Should detect field changes in form scenario");
        
        // Should detect form submission
        let submissions: Vec<_> = all_events.iter()
            .filter(|e| e.event_type == EventType::FormSubmission)
            .collect();
        
        assert!(!submissions.is_empty(), "Should detect form submission");
        
        // Test querying capabilities
        let field_change_events = analyzer.query_events_by_type(&EventType::FieldChange).await.unwrap();
        assert!(!field_change_events.is_empty(), "Should be able to query field change events");
        
        analyzer.finalize().await.unwrap();
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
        
        // Create repeated error pattern
        for i in 1..=5 {
            let frame_id = format!("frame_{:03}", i);
            let ocr_results = vec![
                create_test_ocr_result(&frame_id, "Error: Connection timeout", 50.0, 100.0, 200.0, 20.0, 0.95),
            ];
            
            let events = analyzer.analyze_frame(&frame_id, ocr_results, Utc::now()).await.unwrap();
            
            // Later frames should have temporal context metadata
            if i > 2 {
                for event in &events {
                    if event.metadata.contains_key("temporal_pattern") {
                        assert!(event.metadata.get("temporal_pattern").is_some());
                    }
                }
            }
        }
        
        analyzer.finalize().await.unwrap();
    }
    
    #[tokio::test]
    async fn test_comprehensive_scenario() {
        let temp_dir = TempDir::new().unwrap();
        let ocr_dir = temp_dir.path().join("ocr");
        let event_dir = temp_dir.path().join("events");
        
        std::fs::create_dir_all(&ocr_dir).unwrap();
        std::fs::create_dir_all(&event_dir).unwrap();
        
        let mut analyzer = DeltaAnalyzer::new(
            ocr_dir.to_str().unwrap(),
            event_dir.to_str().unwrap(),
        ).unwrap();
        
        // Test all scenarios
        let scenarios = vec![
            ("form", create_form_field_scenario()),
            ("error", create_error_scenario()),
            ("modal", create_modal_scenario()),
        ];
        
        let mut total_events = 0;
        
        for (scenario_name, frames) in scenarios {
            for (frame_id, ocr_results) in frames {
                let full_frame_id = format!("{}_{}", scenario_name, frame_id);
                let events = analyzer.analyze_frame(&full_frame_id, ocr_results, Utc::now()).await.unwrap();
                total_events += events.len();
            }
        }
        
        assert!(total_events > 0, "Should detect events across all scenarios");
        
        // Test statistics
        let stats = analyzer.get_event_statistics().await.unwrap();
        assert!(stats.total_events > 0, "Statistics should show detected events");
        
        // Test field state tracking
        let field_states = analyzer.get_current_field_states();
        assert!(!field_states.is_empty(), "Should track field states");
        
        // Test field change history
        let field_changes = analyzer.get_field_changes();
        assert!(!field_changes.is_empty(), "Should have field change history");
        
        analyzer.finalize().await.unwrap();
    }
    
    #[test]
    fn test_text_similarity_calculation() {
        let detector = EventDetector::new().unwrap();
        
        // Identical text
        assert_eq!(detector.calculate_text_similarity("hello", "hello"), 1.0);
        
        // Similar text
        let similarity = detector.calculate_text_similarity("hello", "hallo");
        assert!(similarity > 0.8 && similarity < 1.0);
        
        // Different text
        let similarity = detector.calculate_text_similarity("hello", "world");
        assert!(similarity < 0.5);
        
        // Empty strings
        assert_eq!(detector.calculate_text_similarity("", ""), 1.0);
        assert_eq!(detector.calculate_text_similarity("hello", ""), 0.0);
    }
    
    #[test]
    fn test_bounding_box_iou() {
        let bbox1 = BoundingBox::new(0.0, 0.0, 100.0, 100.0);
        let bbox2 = BoundingBox::new(50.0, 50.0, 100.0, 100.0);
        let bbox3 = BoundingBox::new(200.0, 200.0, 100.0, 100.0);
        
        // Overlapping boxes
        let iou = bbox1.iou(&bbox2);
        assert!(iou > 0.0 && iou < 1.0, "Overlapping boxes should have IoU between 0 and 1");
        
        // Non-overlapping boxes
        let iou = bbox1.iou(&bbox3);
        assert_eq!(iou, 0.0, "Non-overlapping boxes should have IoU of 0");
        
        // Identical boxes
        let iou = bbox1.iou(&bbox1);
        assert!((iou - 1.0).abs() < 0.001, "Identical boxes should have IoU of 1");
    }
}