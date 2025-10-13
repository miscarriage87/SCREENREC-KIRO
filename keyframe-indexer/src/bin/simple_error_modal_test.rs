use keyframe_indexer::{
    ErrorModalDetector, ErrorModalType, SeverityLevel,
    OCRResult, BoundingBox
};
use chrono::Utc;
use tracing::{info, warn};
use tracing_subscriber;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();
    
    info!("Starting Simple Error and Modal Detection Test");
    
    let detector = ErrorModalDetector::new()?;
    let timestamp = Utc::now();
    
    // Test 1: Basic error detection
    info!("=== Test 1: Basic Error Detection ===");
    
    let error_ocr = OCRResult {
        frame_id: "test_frame".to_string(),
        text: "Fatal error: System crash detected".to_string(),
        roi: BoundingBox { x: 100.0, y: 100.0, width: 400.0, height: 50.0 },
        confidence: 0.9,
        language: "en".to_string(),
        processor: "vision".to_string(),
        processed_at: Utc::now(),
    };
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &[error_ocr],
        timestamp,
        1920.0,
        1080.0,
    )?;
    
    info!("Detected {} events", events.len());
    for event in &events {
        info!("  Event: {:?} - {} (confidence: {:.2})", 
              event.event_type, event.title, event.confidence);
    }
    
    // Test 2: Modal dialog detection
    info!("=== Test 2: Modal Dialog Detection ===");
    
    let modal_ocr = OCRResult {
        frame_id: "test_frame".to_string(),
        text: "Are you sure you want to delete this file?".to_string(),
        roi: BoundingBox { x: 300.0, y: 200.0, width: 400.0, height: 100.0 },
        confidence: 0.85,
        language: "en".to_string(),
        processor: "vision".to_string(),
        processed_at: Utc::now(),
    };
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &[modal_ocr],
        timestamp,
        1920.0,
        1080.0,
    )?;
    
    info!("Detected {} events", events.len());
    for event in &events {
        info!("  Event: {:?} - {} (confidence: {:.2})", 
              event.event_type, event.title, event.confidence);
    }
    
    // Test 3: Network error detection
    info!("=== Test 3: Network Error Detection ===");
    
    let network_error_ocr = OCRResult {
        frame_id: "test_frame".to_string(),
        text: "Connection failed: Unable to reach server".to_string(),
        roi: BoundingBox { x: 200.0, y: 150.0, width: 300.0, height: 60.0 },
        confidence: 0.85,
        language: "en".to_string(),
        processor: "vision".to_string(),
        processed_at: Utc::now(),
    };
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &[network_error_ocr],
        timestamp,
        1920.0,
        1080.0,
    )?;
    
    info!("Detected {} events", events.len());
    for event in &events {
        info!("  Event: {:?} - {} (confidence: {:.2})", 
              event.event_type, event.title, event.confidence);
        info!("  Severity: {:?}", event.severity);
        if !event.pattern_matches.is_empty() {
            info!("  Pattern matches:");
            for pattern in &event.pattern_matches {
                info!("    - {}: {}", pattern.pattern_type, pattern.description);
            }
        }
    }
    
    // Test 4: Layout-based detection
    info!("=== Test 4: Layout-Based Detection ===");
    
    let dialog_ocr = vec![
        OCRResult {
            frame_id: "test_frame".to_string(),
            text: "Confirm Action".to_string(),
            roi: BoundingBox { x: 400.0, y: 250.0, width: 200.0, height: 30.0 },
            confidence: 0.9,
            language: "en".to_string(),
            processor: "vision".to_string(),
            processed_at: Utc::now(),
        },
        OCRResult {
            frame_id: "test_frame".to_string(),
            text: "Are you sure you want to proceed?".to_string(),
            roi: BoundingBox { x: 350.0, y: 300.0, width: 300.0, height: 40.0 },
            confidence: 0.85,
            language: "en".to_string(),
            processor: "vision".to_string(),
            processed_at: Utc::now(),
        },
        OCRResult {
            frame_id: "test_frame".to_string(),
            text: "OK    Cancel".to_string(),
            roi: BoundingBox { x: 450.0, y: 360.0, width: 100.0, height: 30.0 },
            confidence: 0.88,
            language: "en".to_string(),
            processor: "vision".to_string(),
            processed_at: Utc::now(),
        },
    ];
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &dialog_ocr,
        timestamp,
        1000.0,
        600.0,
    )?;
    
    info!("Detected {} events from dialog layout", events.len());
    for event in &events {
        info!("  Event: {:?} - {} (confidence: {:.2})", 
              event.event_type, event.title, event.confidence);
        if let Some(layout) = &event.layout_analysis {
            info!("    Layout: dialog={}, centered={}, size={}x{}", 
                  layout.is_dialog_layout, layout.is_centered,
                  layout.dialog_width, layout.dialog_height);
        }
    }
    
    // Test 5: No detection for regular text
    info!("=== Test 5: Regular Text (Should Not Detect) ===");
    
    let regular_ocr = OCRResult {
        frame_id: "test_frame".to_string(),
        text: "Welcome to the application. Please enter your username.".to_string(),
        roi: BoundingBox { x: 100.0, y: 100.0, width: 300.0, height: 50.0 },
        confidence: 0.9,
        language: "en".to_string(),
        processor: "vision".to_string(),
        processed_at: Utc::now(),
    };
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &[regular_ocr],
        timestamp,
        1920.0,
        1080.0,
    )?;
    
    if events.is_empty() {
        info!("✓ Correctly did not detect any errors/modals in regular text");
    } else {
        warn!("✗ Incorrectly detected {} events in regular text", events.len());
        for event in &events {
            warn!("  False positive: {:?} - {}", event.event_type, event.title);
        }
    }
    
    info!("Simple Error and Modal Detection Test completed!");
    Ok(())
}