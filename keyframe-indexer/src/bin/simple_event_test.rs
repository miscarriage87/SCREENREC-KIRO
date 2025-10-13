use keyframe_indexer::{EventParquetWriter, EventType, DetectedEvent};
use chrono::Utc;
use std::collections::HashMap;
use tracing::{info, error, Level};
use tracing_subscriber;

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

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();
    
    info!("Starting simple event storage test...");
    
    let temp_dir = std::env::temp_dir().join(format!("simple_event_test_{}", uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&temp_dir)?;
    let event_dir = temp_dir.join("events");
    std::fs::create_dir_all(&event_dir)?;
    
    let mut writer = EventParquetWriter::new(event_dir.to_str().unwrap())?;
    
    // Create a simple test event
    let test_event = create_test_event(
        EventType::FieldChange,
        "username_field",
        Some("".to_string()),
        Some("john.doe".to_string()),
        0.95,
        vec!["frame_001".to_string(), "frame_002".to_string()],
    );
    
    info!("Created test event: {:?}", test_event.event_type);
    info!("Event ID: {}", test_event.id);
    info!("Target: {}", test_event.target);
    info!("Evidence frames: {:?}", test_event.evidence_frames);
    
    // Write the event
    writer.write_event(&test_event).await?;
    writer.flush_batch().await?;
    
    info!("Event written successfully");
    
    // Try to query it back
    info!("Attempting to query events by type...");
    let field_changes = writer.query_by_type(&EventType::FieldChange).await?;
    info!("Found {} field change events", field_changes.len());
    
    if field_changes.is_empty() {
        error!("No events found! This indicates a problem with the query implementation.");
        
        // Let's check if files were created
        let parquet_files = writer.get_parquet_files()?;
        info!("Parquet files found: {}", parquet_files.len());
        for file in &parquet_files {
            info!("  - {}", file.display());
        }
        
        // Try to get statistics
        let stats = writer.get_statistics().await?;
        info!("Statistics: total_events={}, size={} bytes", stats.total_events, stats.total_size_bytes);
    } else {
        info!("✓ Successfully queried events!");
        for event in &field_changes {
            info!("  - Event: {:?} -> {:?}", event.value_from, event.value_to);
        }
    }
    
    writer.finalize().await?;
    
    // Clean up
    std::fs::remove_dir_all(&temp_dir).ok();
    
    info!("Simple event storage test completed");
    
    Ok(())
}