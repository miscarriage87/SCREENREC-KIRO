use keyframe_indexer::{
    ErrorModalDetector, ErrorModalType, SeverityLevel,
    OCRResult, BoundingBox
};
use chrono::Utc;
use tracing::{info, warn, error};
use tracing_subscriber;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();
    
    info!("Starting Error and Modal Detection Tests");
    
    // Test 1: Basic error detection
    test_basic_error_detection().await?;
    
    // Test 2: Modal dialog detection
    test_modal_dialog_detection().await?;
    
    // Test 3: Layout-based detection
    test_layout_based_detection().await?;
    
    // Test 4: Confidence scoring
    test_confidence_scoring().await?;
    
    // Test 5: Pattern matching accuracy
    test_pattern_matching_accuracy().await?;
    
    // Test 6: Real-world scenarios
    test_real_world_scenarios().await?;
    
    info!("All Error and Modal Detection Tests completed successfully!");
    Ok(())
}

async fn test_basic_error_detection() -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Test 1: Basic Error Detection ===");
    
    let detector = ErrorModalDetector::new()?;
    let timestamp = Utc::now();
    
    let test_cases = vec![
        (
            "Fatal system error",
            "Fatal error: System crash detected",
            ErrorModalType::SystemError,
            SeverityLevel::Critical,
        ),
        (
            "Network connection error",
            "Connection failed: Unable to reach server",
            ErrorModalType::NetworkError,
            SeverityLevel::High,
        ),
        (
            "Authentication error",
            "Access denied: Insufficient privileges",
            ErrorModalType::AuthError,
            SeverityLevel::High,
        ),
        (
            "Validation error",
            "Invalid input format: Please enter a valid email",
            ErrorModalType::ValidationError,
            SeverityLevel::Medium,
        ),
        (
            "Warning message",
            "Warning: Disk space is running low",
            ErrorModalType::Warning,
            SeverityLevel::Medium,
        ),
    ];
    
    for (test_name, text, expected_type, expected_severity) in test_cases {
        info!("Testing: {}", test_name);
        
        let ocr_result = OCRResult {
            text: text.to_string(),
            roi: BoundingBox { x: 100.0, y: 100.0, width: 400.0, height: 50.0 },
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
        )?;
        
        if events.is_empty() {
            warn!("No events detected for: {}", test_name);
            continue;
        }
        
        let event = &events[0];
        info!("  Detected: {:?} with severity {:?} (confidence: {:.2})", 
              event.event_type, event.severity, event.confidence);
        
        if event.event_type != expected_type {
            warn!("  Expected type {:?}, got {:?}", expected_type, event.event_type);
        }
        
        if event.severity != expected_severity {
            warn!("  Expected severity {:?}, got {:?}", expected_severity, event.severity);
        }
        
        if event.confidence < 0.6 {
            warn!("  Low confidence: {:.2}", event.confidence);
        }
        
        // Print pattern matches
        if !event.pattern_matches.is_empty() {
            info!("  Pattern matches:");
            for pattern_match in &event.pattern_matches {
                info!("    - {}: {} (weight: {:.2})", 
                      pattern_match.pattern_type, 
                      pattern_match.description,
                      pattern_match.confidence_weight);
            }
        }
    }
    
    info!("Basic error detection test completed\n");
    Ok(())
}

async fn test_modal_dialog_detection() -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Test 2: Modal Dialog Detection ===");
    
    let detector = ErrorModalDetector::new()?;
    let timestamp = Utc::now();
    
    let test_cases = vec![
        (
            "Confirmation dialog",
            "Are you sure you want to delete this file?",
            ErrorModalType::ConfirmationDialog,
        ),
        (
            "File save dialog",
            "Save file as: document.txt",
            ErrorModalType::FileDialog,
        ),
        (
            "Settings dialog",
            "Settings and Preferences",
            ErrorModalType::SettingsDialog,
        ),
        (
            "Progress dialog",
            "Loading... 45% completed",
            ErrorModalType::ProgressDialog,
        ),
        (
            "Information dialog",
            "Information: Task completed successfully",
            ErrorModalType::InfoDialog,
        ),
    ];
    
    for (test_name, text, expected_type) in test_cases {
        info!("Testing: {}", test_name);
        
        let ocr_result = OCRResult {
            text: text.to_string(),
            roi: BoundingBox { x: 300.0, y: 200.0, width: 400.0, height: 100.0 },
            confidence: 0.85,
            language: "en".to_string(),
            processor: "vision".to_string(),
        };
        
        let events = detector.detect_errors_and_modals(
            "test_frame",
            &[ocr_result],
            timestamp,
            1000.0,
            600.0,
        )?;
        
        if events.is_empty() {
            warn!("No events detected for: {}", test_name);
            continue;
        }
        
        let event = &events[0];
        info!("  Detected: {:?} (confidence: {:.2})", event.event_type, event.confidence);
        
        if event.event_type != expected_type {
            warn!("  Expected type {:?}, got {:?}", expected_type, event.event_type);
        }
        
        // Check layout analysis if available
        if let Some(layout) = &event.layout_analysis {
            info!("  Layout analysis: dialog={}, centered={}, confidence={:.2}",
                  layout.is_dialog_layout, layout.is_centered, layout.layout_confidence);
        }
    }
    
    info!("Modal dialog detection test completed\n");
    Ok(())
}

async fn test_layout_based_detection() -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Test 3: Layout-Based Detection ===");
    
    let detector = ErrorModalDetector::new()?;
    let timestamp = Utc::now();
    
    // Test centered dialog layout
    info!("Testing centered dialog layout");
    let centered_dialog_ocr = vec![
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
    ];
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &centered_dialog_ocr,
        timestamp,
        1000.0,
        600.0,
    )?;
    
    info!("  Detected {} events from centered dialog", events.len());
    for (i, event) in events.iter().enumerate() {
        info!("  Event {}: {:?} (confidence: {:.2})", i + 1, event.event_type, event.confidence);
        if let Some(layout) = &event.layout_analysis {
            info!("    Layout: dialog={}, centered={}, size={}x{}, confidence={:.2}",
                  layout.is_dialog_layout, layout.is_centered,
                  layout.dialog_width, layout.dialog_height, layout.layout_confidence);
        }
    }
    
    // Test full-screen content (should not be detected as dialog)
    info!("Testing full-screen content (should not be dialog)");
    let fullscreen_ocr = vec![
        OCRResult {
            text: "Main Application Window".to_string(),
            roi: BoundingBox { x: 0.0, y: 0.0, width: 1000.0, height: 600.0 },
            confidence: 0.9,
            language: "en".to_string(),
            processor: "vision".to_string(),
        },
    ];
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &fullscreen_ocr,
        timestamp,
        1000.0,
        600.0,
    )?;
    
    info!("  Detected {} events from full-screen content", events.len());
    for event in &events {
        if let Some(layout) = &event.layout_analysis {
            if layout.is_dialog_layout {
                warn!("  Full-screen content incorrectly detected as dialog!");
            }
        }
    }
    
    info!("Layout-based detection test completed\n");
    Ok(())
}

async fn test_confidence_scoring() -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Test 4: Confidence Scoring ===");
    
    let detector = ErrorModalDetector::new()?;
    let timestamp = Utc::now();
    
    // Test high confidence case
    info!("Testing high confidence case");
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
    )?;
    
    if !events.is_empty() {
        info!("  High confidence detection: {:.2}", events[0].confidence);
        if events[0].confidence < 0.8 {
            warn!("  Expected high confidence, got {:.2}", events[0].confidence);
        }
    }
    
    // Test low confidence case
    info!("Testing low confidence case");
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
    )?;
    
    if events.is_empty() {
        info!("  Low confidence case correctly filtered out");
    } else {
        info!("  Low confidence detection: {:.2}", events[0].confidence);
        if events[0].confidence >= 0.7 {
            warn!("  Expected low confidence, got {:.2}", events[0].confidence);
        }
    }
    
    info!("Confidence scoring test completed\n");
    Ok(())
}

async fn test_pattern_matching_accuracy() -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Test 5: Pattern Matching Accuracy ===");
    
    let detector = ErrorModalDetector::new()?;
    let timestamp = Utc::now();
    
    let test_patterns = vec![
        ("Fatal error occurred", true, "Should match critical error pattern"),
        ("Connection failed to server", true, "Should match network error pattern"),
        ("Access denied by system", true, "Should match auth error pattern"),
        ("Invalid email format", true, "Should match validation error pattern"),
        ("Are you sure you want to delete?", true, "Should match confirmation dialog pattern"),
        ("Save file as document.txt", true, "Should match file dialog pattern"),
        ("Regular text content", false, "Should not match any error pattern"),
        ("Welcome to the application", false, "Should not match any error pattern"),
        ("Loading page content", false, "Should not match error patterns"),
        ("User profile settings", false, "Should not match error patterns"),
    ];
    
    let mut correct_matches = 0;
    let total_tests = test_patterns.len();
    
    for (text, should_match, description) in test_patterns {
        let ocr_result = OCRResult {
            frame_id: "test_frame".to_string(),
            text: text.to_string(),
            roi: BoundingBox { x: 100.0, y: 100.0, width: 300.0, height: 50.0 },
            confidence: 0.9,
            language: "en".to_string(),
            processor: "vision".to_string(),
            processed_at: Utc::now(),
        };
        
        let events = detector.detect_errors_and_modals(
            "test_frame",
            &[ocr_result],
            timestamp,
            1000.0,
            600.0,
        )?;
        
        let detected = !events.is_empty() && events[0].confidence >= 0.6;
        
        if detected == should_match {
            correct_matches += 1;
            info!("  ✓ '{}' - {}", text, description);
        } else {
            warn!("  ✗ '{}' - {} (detected: {}, expected: {})", 
                  text, description, detected, should_match);
            if detected {
                info!("    Detected as: {:?} (confidence: {:.2})", 
                      events[0].event_type, events[0].confidence);
            }
        }
    }
    
    let accuracy = (correct_matches as f32 / total_tests as f32) * 100.0;
    info!("Pattern matching accuracy: {:.1}% ({}/{} correct)", 
          accuracy, correct_matches, total_tests);
    
    if accuracy < 80.0 {
        warn!("Pattern matching accuracy is below 80%!");
    }
    
    info!("Pattern matching accuracy test completed\n");
    Ok(())
}

async fn test_real_world_scenarios() -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Test 6: Real-World Scenarios ===");
    
    let detector = ErrorModalDetector::new()?;
    let timestamp = Utc::now();
    
    // Scenario 1: macOS application crash dialog
    info!("Testing macOS application crash dialog");
    let macos_crash_ocr = vec![
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
    ];
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &macos_crash_ocr,
        timestamp,
        1000.0,
        600.0,
    )?;
    
    info!("  Detected {} events from macOS crash dialog", events.len());
    for event in &events {
        info!("    {:?} - {} (confidence: {:.2})", 
              event.event_type, event.title, event.confidence);
    }
    
    // Scenario 2: Web browser error page
    info!("Testing web browser error page");
    let browser_error_ocr = vec![
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
    ];
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &browser_error_ocr,
        timestamp,
        1000.0,
        600.0,
    )?;
    
    info!("  Detected {} events from browser error page", events.len());
    for event in &events {
        info!("    {:?} - {} (confidence: {:.2})", 
              event.event_type, event.title, event.confidence);
    }
    
    // Scenario 3: Form validation errors
    info!("Testing form validation errors");
    let form_validation_ocr = vec![
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
    ];
    
    let events = detector.detect_errors_and_modals(
        "test_frame",
        &form_validation_ocr,
        timestamp,
        1000.0,
        600.0,
    )?;
    
    info!("  Detected {} events from form validation", events.len());
    for event in &events {
        info!("    {:?} - {} (confidence: {:.2})", 
              event.event_type, event.title, event.confidence);
    }
    
    info!("Real-world scenarios test completed\n");
    Ok(())
}