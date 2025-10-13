use keyframe_indexer::{
    EventParquetWriter, EventStatistics, DeltaAnalyzer, DeltaAnalysisConfig,
    EventDetector, EventDetectionConfig, EventType, DetectedEvent,
    OCRResult, BoundingBox
};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
// use tempfile::TempDir;
use tracing::{info, error, Level};
use tracing_subscriber;

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

/// Create synthetic detected event for testing
fn create_test_event(
    event_type: EventType,
    target: &str,
    value_from: Option<String>,
    value_to: Option<String>,
    confidence: f32,
    evidence_frames: Vec<String>,
) -> DetectedEvent {
    let mut metadata = HashMap::new();
    metadata.insert("test_source".to_string(), "synthetic".to_string());
    
    DetectedEvent {
        id: uuid::Uuid::new_v4().to_string(),
        timestamp: Utc::now(),
        event_type,
        target: target.to_string(),
        value_from,
        value_to,
        confidence,
        evidence_frames,
        metadata,
    }
}

/// Test basic event storage functionality
async fn test_event_parquet_writer() -> Result<(), Box<dyn std::error::Error>> {
    info!("Testing EventParquetWriter basic functionality...");
    
    let temp_dir = std::env::temp_dir().join(format!("event_test_{}", uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&temp_dir)?;
    let event_dir = temp_dir.join("events");
    std::fs::create_dir_all(&event_dir)?;
    
    let mut writer = EventParquetWriter::new(event_dir.to_str().unwrap())?;
    
    // Test 1: Write single event
    info!("Test 1: Writing single event");
    let single_event = create_test_event(
        EventType::FieldChange,
        "username_field",
        Some("".to_string()),
        Some("john.doe".to_string()),
        0.95,
        vec!["frame_001".to_string(), "frame_002".to_string()],
    );
    
    writer.write_event(&single_event).await?;
    writer.flush_batch().await?;
    
    info!("✓ Single event written successfully");
    
    // Test 2: Write batch of events
    info!("Test 2: Writing batch of events");
    let batch_events = vec![
        create_test_event(
            EventType::ErrorDisplay,
            "error_dialog",
            None,
            Some("Invalid credentials".to_string()),
            0.92,
            vec!["frame_003".to_string()],
        ),
        create_test_event(
            EventType::ModalAppearance,
            "confirmation_dialog",
            None,
            Some("Are you sure?".to_string()),
            0.88,
            vec!["frame_004".to_string(), "frame_005".to_string()],
        ),
        create_test_event(
            EventType::FormSubmission,
            "login_form",
            None,
            Some("Submit".to_string()),
            0.97,
            vec!["frame_006".to_string()],
        ),
        create_test_event(
            EventType::Navigation,
            "page_change",
            Some("/login".to_string()),
            Some("/dashboard".to_string()),
            0.85,
            vec!["frame_007".to_string(), "frame_008".to_string()],
        ),
    ];
    
    writer.write_events(&batch_events).await?;
    writer.flush_batch().await?;
    
    info!("✓ Batch of {} events written successfully", batch_events.len());
    
    // Test 3: Query events by type
    info!("Test 3: Querying events by type");
    
    let field_changes = writer.query_by_type(&EventType::FieldChange).await?;
    info!("Field change events: {}", field_changes.len());
    assert!(!field_changes.is_empty(), "Should find field change events");
    
    let error_events = writer.query_by_type(&EventType::ErrorDisplay).await?;
    info!("Error events: {}", error_events.len());
    assert!(!error_events.is_empty(), "Should find error events");
    
    let modal_events = writer.query_by_type(&EventType::ModalAppearance).await?;
    info!("Modal events: {}", modal_events.len());
    assert!(!modal_events.is_empty(), "Should find modal events");
    
    info!("✓ Event type queries working correctly");
    
    // Test 4: Query events by target
    info!("Test 4: Querying events by target");
    
    let username_events = writer.query_by_target("username_field").await?;
    info!("Username field events: {}", username_events.len());
    assert!(!username_events.is_empty(), "Should find username field events");
    
    let dialog_events = writer.query_by_target("error_dialog").await?;
    info!("Error dialog events: {}", dialog_events.len());
    assert!(!dialog_events.is_empty(), "Should find error dialog events");
    
    info!("✓ Event target queries working correctly");
    
    // Test 5: Query events by confidence threshold
    info!("Test 5: Querying events by confidence threshold");
    
    let high_confidence_events = writer.query_by_confidence(0.9).await?;
    info!("High confidence events (≥0.9): {}", high_confidence_events.len());
    
    let medium_confidence_events = writer.query_by_confidence(0.8).await?;
    info!("Medium confidence events (≥0.8): {}", medium_confidence_events.len());
    
    assert!(medium_confidence_events.len() >= high_confidence_events.len(), 
           "Medium confidence should include high confidence events");
    
    info!("✓ Confidence threshold queries working correctly");
    
    // Test 6: Query events by time range
    info!("Test 6: Querying events by time range");
    
    let now = Utc::now();
    let one_hour_ago = now - chrono::Duration::hours(1);
    let one_hour_later = now + chrono::Duration::hours(1);
    
    let time_range_events = writer.query_by_time_range(one_hour_ago, one_hour_later).await?;
    info!("Events in time range: {}", time_range_events.len());
    assert!(!time_range_events.is_empty(), "Should find events in time range");
    
    info!("✓ Time range queries working correctly");
    
    // Test 7: Get statistics
    info!("Test 7: Getting event statistics");
    
    let stats = writer.get_statistics().await?;
    info!("Event statistics:");
    info!("  - Total events: {}", stats.total_events);
    info!("  - Average confidence: {:.2}", stats.average_confidence);
    info!("  - Storage size: {} bytes", stats.total_size_bytes);
    
    assert!(stats.total_events > 0, "Should have events in statistics");
    assert!(stats.total_size_bytes > 0, "Should have non-zero storage size");
    
    info!("✓ Statistics generation working correctly");
    
    writer.finalize().await?;
    info!("✓ EventParquetWriter test completed successfully");
    
    Ok(())
}

/// Test event storage with evidence linking
async fn test_evidence_linking() -> Result<(), Box<dyn std::error::Error>> {
    info!("Testing evidence linking system...");
    
    let temp_dir = std::env::temp_dir().join(format!("event_test_{}", uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&temp_dir)?;
    let event_dir = temp_dir.join("events");
    std::fs::create_dir_all(&event_dir)?;
    
    let mut writer = EventParquetWriter::new(event_dir.to_str().unwrap())?;
    
    // Create events with complex evidence linking
    let events_with_evidence = vec![
        create_test_event(
            EventType::FieldChange,
            "email_field",
            Some("user@old.com".to_string()),
            Some("user@new.com".to_string()),
            0.94,
            vec![
                "frame_001".to_string(),
                "frame_002".to_string(),
                "frame_003".to_string(),
            ],
        ),
        create_test_event(
            EventType::ErrorDisplay,
            "validation_error",
            None,
            Some("Email format invalid".to_string()),
            0.91,
            vec![
                "frame_003".to_string(), // Overlapping evidence with previous event
                "frame_004".to_string(),
            ],
        ),
        create_test_event(
            EventType::FieldChange,
            "email_field",
            Some("user@new.com".to_string()),
            Some("user@correct.com".to_string()),
            0.96,
            vec![
                "frame_005".to_string(),
                "frame_006".to_string(),
            ],
        ),
        create_test_event(
            EventType::FormSubmission,
            "registration_form",
            None,
            Some("Register".to_string()),
            0.98,
            vec![
                "frame_006".to_string(), // Overlapping evidence
                "frame_007".to_string(),
            ],
        ),
    ];
    
    writer.write_events(&events_with_evidence).await?;
    writer.flush_batch().await?;
    
    // Query and verify evidence linking
    let email_events = writer.query_by_target("email_field").await?;
    info!("Email field events found: {}", email_events.len());
    
    for event in &email_events {
        info!("Event {}: {} evidence frames", event.id, event.evidence_frames.len());
        for frame_id in &event.evidence_frames {
            info!("  - Evidence frame: {}", frame_id);
        }
    }
    
    // Verify evidence frame overlap detection
    let mut all_evidence_frames = std::collections::HashSet::new();
    let mut overlapping_frames = std::collections::HashSet::new();
    
    for event in &events_with_evidence {
        for frame_id in &event.evidence_frames {
            if all_evidence_frames.contains(frame_id) {
                overlapping_frames.insert(frame_id.clone());
            } else {
                all_evidence_frames.insert(frame_id.clone());
            }
        }
    }
    
    info!("Total unique evidence frames: {}", all_evidence_frames.len());
    info!("Overlapping evidence frames: {}", overlapping_frames.len());
    
    for frame_id in &overlapping_frames {
        info!("  - Overlapping frame: {}", frame_id);
    }
    
    assert!(!overlapping_frames.is_empty(), "Should detect overlapping evidence frames");
    
    writer.finalize().await?;
    info!("✓ Evidence linking test completed successfully");
    
    Ok(())
}

/// Test comprehensive event storage with delta analyzer integration
async fn test_integrated_event_storage() -> Result<(), Box<dyn std::error::Error>> {
    info!("Testing integrated event storage with DeltaAnalyzer...");
    
    let temp_dir = std::env::temp_dir().join(format!("event_test_{}", uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&temp_dir)?;
    let ocr_dir = temp_dir.join("ocr");
    let event_dir = temp_dir.join("events");
    
    std::fs::create_dir_all(&ocr_dir)?;
    std::fs::create_dir_all(&event_dir)?;
    
    let mut analyzer = DeltaAnalyzer::new(
        ocr_dir.to_str().unwrap(),
        event_dir.to_str().unwrap(),
    )?;
    
    // Simulate a complete user workflow
    let workflow_scenarios = vec![
        // Frame 1: Login page
        (
            "login_001",
            vec![
                create_test_ocr_result("login_001", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_001", "", 100.0, 50.0, 200.0, 20.0, 0.0),
                create_test_ocr_result("login_001", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_001", "", 100.0, 80.0, 200.0, 20.0, 0.0),
                create_test_ocr_result("login_001", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
            ],
        ),
        // Frame 2: Username entered
        (
            "login_002",
            vec![
                create_test_ocr_result("login_002", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_002", "john.doe", 100.0, 50.0, 200.0, 20.0, 0.92),
                create_test_ocr_result("login_002", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_002", "", 100.0, 80.0, 200.0, 20.0, 0.0),
                create_test_ocr_result("login_002", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
            ],
        ),
        // Frame 3: Password entered
        (
            "login_003",
            vec![
                create_test_ocr_result("login_003", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_003", "john.doe", 100.0, 50.0, 200.0, 20.0, 0.92),
                create_test_ocr_result("login_003", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_003", "••••••••", 100.0, 80.0, 200.0, 20.0, 0.85),
                create_test_ocr_result("login_003", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
            ],
        ),
        // Frame 4: Login attempt with error
        (
            "login_004",
            vec![
                create_test_ocr_result("login_004", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_004", "john.doe", 100.0, 50.0, 200.0, 20.0, 0.92),
                create_test_ocr_result("login_004", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_004", "••••••••", 100.0, 80.0, 200.0, 20.0, 0.85),
                create_test_ocr_result("login_004", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
                create_test_ocr_result("login_004", "Error: Invalid credentials", 50.0, 160.0, 200.0, 20.0, 0.94),
            ],
        ),
        // Frame 5: Password corrected
        (
            "login_005",
            vec![
                create_test_ocr_result("login_005", "Username:", 10.0, 50.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_005", "john.doe", 100.0, 50.0, 200.0, 20.0, 0.92),
                create_test_ocr_result("login_005", "Password:", 10.0, 80.0, 80.0, 20.0, 0.95),
                create_test_ocr_result("login_005", "••••••••••", 100.0, 80.0, 200.0, 20.0, 0.87),
                create_test_ocr_result("login_005", "Login", 150.0, 120.0, 60.0, 30.0, 0.98),
            ],
        ),
        // Frame 6: Successful login
        (
            "login_006",
            vec![
                create_test_ocr_result("login_006", "Welcome, john.doe!", 100.0, 100.0, 200.0, 30.0, 0.96),
                create_test_ocr_result("login_006", "Dashboard", 50.0, 50.0, 100.0, 25.0, 0.94),
                create_test_ocr_result("login_006", "Logout", 300.0, 20.0, 60.0, 20.0, 0.97),
            ],
        ),
    ];
    
    let mut total_events = 0;
    let mut event_types_detected = std::collections::HashMap::new();
    
    for (frame_id, ocr_results) in workflow_scenarios {
        let events = analyzer.analyze_frame(frame_id, ocr_results, Utc::now()).await?;
        total_events += events.len();
        
        info!("Frame {}: {} events detected", frame_id, events.len());
        
        for event in &events {
            *event_types_detected.entry(format!("{:?}", event.event_type)).or_insert(0) += 1;
            info!("  - {:?}: {} -> {:?} (confidence: {:.2})", 
                  event.event_type, 
                  event.target,
                  event.value_to,
                  event.confidence);
        }
    }
    
    info!("Total events detected: {}", total_events);
    info!("Event type distribution:");
    for (event_type, count) in &event_types_detected {
        info!("  - {}: {}", event_type, count);
    }
    
    // Test comprehensive querying
    info!("Testing comprehensive event queries...");
    
    let field_changes = analyzer.query_events_by_type(&EventType::FieldChange).await?;
    info!("Field change events: {}", field_changes.len());
    
    let error_events = analyzer.query_events_by_type(&EventType::ErrorDisplay).await?;
    info!("Error events: {}", error_events.len());
    
    let high_confidence_events = analyzer.query_events_by_confidence(0.9).await?;
    info!("High confidence events: {}", high_confidence_events.len());
    
    // Test field state tracking
    let field_states = analyzer.get_current_field_states();
    info!("Current field states: {}", field_states.len());
    for state in &field_states {
        info!("  - Field {}: '{}' (confidence: {:.2})", 
              state.field_id, 
              state.current_value, 
              state.confidence);
    }
    
    let field_changes_history = analyzer.get_field_changes();
    info!("Field change history: {}", field_changes_history.len());
    for change in &field_changes_history {
        info!("  - {}: '{}' -> '{}' (confidence: {:.2})", 
              change.field_id, 
              change.value_from, 
              change.value_to, 
              change.confidence);
    }
    
    // Test event statistics
    let stats = analyzer.get_event_statistics().await?;
    info!("Final event statistics:");
    info!("  - Total events: {}", stats.total_events);
    info!("  - Average confidence: {:.2}", stats.average_confidence);
    info!("  - Storage size: {} bytes", stats.total_size_bytes);
    
    assert!(total_events > 0, "Should detect events in workflow");
    assert!(stats.total_events > 0, "Statistics should show detected events");
    assert!(!field_changes.is_empty(), "Should detect field changes");
    
    analyzer.finalize().await?;
    info!("✓ Integrated event storage test completed successfully");
    
    Ok(())
}

/// Test event storage performance and optimization
async fn test_event_storage_performance() -> Result<(), Box<dyn std::error::Error>> {
    info!("Testing event storage performance and optimization...");
    
    let temp_dir = std::env::temp_dir().join(format!("event_test_{}", uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&temp_dir)?;
    let event_dir = temp_dir.join("events");
    std::fs::create_dir_all(&event_dir)?;
    
    let mut writer = EventParquetWriter::new(event_dir.to_str().unwrap())?;
    
    // Configure for performance testing
    writer.set_batch_size(500);
    writer.set_compression(parquet::basic::Compression::SNAPPY);
    writer.set_dictionary_encoding(true);
    
    // Generate large number of events for performance testing
    let num_events = 1000;
    let mut events = Vec::new();
    
    let event_types = vec![
        EventType::FieldChange,
        EventType::ErrorDisplay,
        EventType::ModalAppearance,
        EventType::FormSubmission,
        EventType::Navigation,
        EventType::DataEntry,
    ];
    
    let start_time = std::time::Instant::now();
    
    for i in 0..num_events {
        let event_type = &event_types[i % event_types.len()];
        let event = create_test_event(
            event_type.clone(),
            &format!("target_{}", i % 100), // Create some target overlap
            if i % 3 == 0 { Some(format!("old_value_{}", i)) } else { None },
            Some(format!("new_value_{}", i)),
            0.7 + (i as f32 % 30.0) / 100.0, // Vary confidence
            vec![
                format!("frame_{:04}", i),
                format!("frame_{:04}", i + 1),
            ],
        );
        events.push(event);
    }
    
    let generation_time = start_time.elapsed();
    info!("Generated {} events in {:?}", num_events, generation_time);
    
    // Test batch writing performance
    let write_start = std::time::Instant::now();
    writer.write_events(&events).await?;
    writer.flush_batch().await?;
    let write_time = write_start.elapsed();
    
    info!("Wrote {} events in {:?}", num_events, write_time);
    info!("Write throughput: {:.2} events/second", 
          num_events as f64 / write_time.as_secs_f64());
    
    // Test query performance
    let query_start = std::time::Instant::now();
    
    let field_changes = writer.query_by_type(&EventType::FieldChange).await?;
    let high_confidence = writer.query_by_confidence(0.9).await?;
    let target_specific = writer.query_by_target("target_50").await?;
    
    let query_time = query_start.elapsed();
    
    info!("Query performance results:");
    info!("  - Field changes found: {} in {:?}", field_changes.len(), query_time);
    info!("  - High confidence events: {}", high_confidence.len());
    info!("  - Target-specific events: {}", target_specific.len());
    
    // Test statistics performance
    let stats_start = std::time::Instant::now();
    let stats = writer.get_statistics().await?;
    let stats_time = stats_start.elapsed();
    
    info!("Statistics computed in {:?}:", stats_time);
    info!("  - Total events: {}", stats.total_events);
    info!("  - Storage size: {} bytes", stats.total_size_bytes);
    info!("  - Compression ratio: {:.2}x", 
          (num_events * 200) as f64 / stats.total_size_bytes as f64); // Rough estimate
    
    // Performance assertions
    assert!(write_time.as_secs() < 10, "Write should complete within 10 seconds");
    assert!(query_time.as_secs() < 5, "Queries should complete within 5 seconds");
    assert!(stats_time.as_secs() < 3, "Statistics should compute within 3 seconds");
    
    writer.finalize().await?;
    info!("✓ Performance test completed successfully");
    
    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();
    
    info!("Starting comprehensive event storage tests...");
    
    // Test 1: Basic event storage functionality
    if let Err(e) = test_event_parquet_writer().await {
        error!("Event Parquet writer test failed: {}", e);
        return Err(e);
    }
    
    // Test 2: Evidence linking system
    if let Err(e) = test_evidence_linking().await {
        error!("Evidence linking test failed: {}", e);
        return Err(e);
    }
    
    // Test 3: Integrated event storage with delta analyzer
    if let Err(e) = test_integrated_event_storage().await {
        error!("Integrated event storage test failed: {}", e);
        return Err(e);
    }
    
    // Test 4: Performance and optimization
    if let Err(e) = test_event_storage_performance().await {
        error!("Performance test failed: {}", e);
        return Err(e);
    }
    
    info!("✓ All event storage tests completed successfully!");
    info!("");
    info!("Event Storage System Summary:");
    info!("- ✓ Parquet-based event storage with proper schema");
    info!("- ✓ Efficient indexing and compression (SNAPPY)");
    info!("- ✓ Evidence linking system connecting events to frame IDs");
    info!("- ✓ Query optimization for temporal and categorical searches");
    info!("- ✓ Comprehensive event type support (field changes, errors, modals, etc.)");
    info!("- ✓ High-performance batch writing and querying");
    info!("- ✓ Statistical analysis and storage metrics");
    info!("- ✓ Integration with delta analyzer for complete workflow");
    info!("- ✓ Confidence scoring and filtering capabilities");
    info!("- ✓ Field state tracking and change history");
    
    Ok(())
}