use keyframe_indexer::{
    NavigationIntegrationService, NavigationIntegrationConfig,
    NavigationDetectionConfig, CursorTrackingConfig, CorrelationConfig
};
use chrono::Utc;
use std::env;
use std::path::Path;
use tokio;
use tracing::{info, error, Level};
use tracing_subscriber;

/// Test binary for navigation and interaction event detection
/// Usage: cargo run --bin test_navigation_detection [output_dir]
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();
    
    info!("Starting Navigation Detection Test");
    
    // Get output directory from command line or use default
    let args: Vec<String> = env::args().collect();
    let output_dir = if args.len() > 1 {
        args[1].clone()
    } else {
        "./test_output/navigation_events".to_string()
    };
    
    // Create output directory
    std::fs::create_dir_all(&output_dir)?;
    info!("Using output directory: {}", output_dir);
    
    // Configure navigation integration service
    let config = create_test_configuration();
    let mut service = NavigationIntegrationService::with_config(&output_dir, config)?;
    
    info!("Navigation Integration Service initialized");
    
    // Run comprehensive navigation detection test
    run_navigation_detection_test(&mut service).await?;
    
    // Run cursor tracking test
    run_cursor_tracking_test(&mut service).await?;
    
    // Run event correlation test
    run_event_correlation_test(&mut service).await?;
    
    // Display final statistics
    display_final_statistics(&service).await?;
    
    // Cleanup
    service.flush().await?;
    service.finalize().await?;
    
    info!("Navigation Detection Test completed successfully");
    Ok(())
}

/// Create test configuration for navigation detection
fn create_test_configuration() -> NavigationIntegrationConfig {
    let mut config = NavigationIntegrationConfig::default();
    
    // Configure navigation detection
    config.navigation_config = NavigationDetectionConfig {
        enable_window_detection: true,
        enable_tab_detection: true,
        enable_focus_detection: true,
        min_detection_interval_ms: 100,
        min_confidence: 0.7,
    };
    
    // Configure cursor tracking
    config.cursor_config = CursorTrackingConfig {
        enable_position_tracking: true,
        enable_click_detection: true,
        enable_trail_analysis: true,
        min_movement_distance: 5.0,
        max_trail_gap_ms: 1000,
        min_confidence: 0.8,
        sampling_interval_ms: 100,
    };
    
    // Configure event correlation
    config.correlation_config = CorrelationConfig {
        max_correlation_window_ms: 2000,
        min_correlation_confidence: 0.6,
        enable_spatial_correlation: true,
        enable_temporal_correlation: true,
        enable_causal_correlation: true,
        spatial_correlation_radius: 50.0,
    };
    
    // Enable comprehensive logging for testing
    config.enable_comprehensive_logging = true;
    config.event_batch_size = 10;
    config.processing_interval_ms = 200;
    
    config
}

/// Run navigation detection test
async fn run_navigation_detection_test(service: &mut NavigationIntegrationService) -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Running Navigation Detection Test ===");
    
    // Simulate a series of navigation events
    let navigation_frames = vec![
        ("nav_frame_001", "Initial window state"),
        ("nav_frame_002", "Window change detection"),
        ("nav_frame_003", "Tab switch detection"),
        ("nav_frame_004", "Application focus change"),
        ("nav_frame_005", "Multi-window navigation"),
    ];
    
    for (i, (frame_id, description)) in navigation_frames.iter().enumerate() {
        info!("Processing {}: {}", frame_id, description);
        
        let timestamp = Utc::now() + chrono::Duration::milliseconds(i as i64 * 500);
        
        match service.process_frame(frame_id, timestamp).await {
            Ok(result) => {
                info!("  Detected {} events, {} correlations", 
                      result.detected_events.len(), 
                      result.correlations.len());
                
                // Log high-confidence events
                for event in &result.detected_events {
                    if event.confidence > 0.8 {
                        info!("  High-confidence event: {:?} -> {} (confidence: {:.2})",
                              event.event_type,
                              event.value_to.as_deref().unwrap_or("None"),
                              event.confidence);
                    }
                }
            }
            Err(e) => {
                error!("Failed to process frame {}: {}", frame_id, e);
            }
        }
        
        // Add delay between frames
        tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;
    }
    
    info!("Navigation detection test completed");
    Ok(())
}

/// Run cursor tracking test
async fn run_cursor_tracking_test(service: &mut NavigationIntegrationService) -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Running Cursor Tracking Test ===");
    
    // Simulate cursor movement and click scenarios
    let cursor_frames = vec![
        ("cursor_frame_001", "Initial cursor position"),
        ("cursor_frame_002", "Cursor movement detection"),
        ("cursor_frame_003", "Click event simulation"),
        ("cursor_frame_004", "Movement trail analysis"),
        ("cursor_frame_005", "Multi-click sequence"),
    ];
    
    for (i, (frame_id, description)) in cursor_frames.iter().enumerate() {
        info!("Processing {}: {}", frame_id, description);
        
        let timestamp = Utc::now() + chrono::Duration::milliseconds(i as i64 * 300);
        
        match service.process_frame(frame_id, timestamp).await {
            Ok(result) => {
                info!("  Cursor events: {}, Total events: {}", 
                      result.metrics.cursor_events, 
                      result.detected_events.len());
                
                // Display cursor position information
                let cursor_positions = service.get_recent_cursor_positions();
                if !cursor_positions.is_empty() {
                    let latest_pos = &cursor_positions[cursor_positions.len() - 1];
                    info!("  Latest cursor position: ({:.1}, {:.1})", 
                          latest_pos.x, latest_pos.y);
                }
            }
            Err(e) => {
                error!("Failed to process cursor frame {}: {}", frame_id, e);
            }
        }
        
        // Add delay between frames
        tokio::time::sleep(tokio::time::Duration::from_millis(150)).await;
    }
    
    info!("Cursor tracking test completed");
    Ok(())
}

/// Run event correlation test
async fn run_event_correlation_test(service: &mut NavigationIntegrationService) -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Running Event Correlation Test ===");
    
    // Simulate correlated event sequences
    let correlation_scenarios = vec![
        ("corr_click_001", "User click action"),
        ("corr_change_002", "Screen change response"),
        ("corr_move_003", "Cursor movement"),
        ("corr_focus_004", "Focus change"),
        ("corr_result_005", "Final state"),
    ];
    
    let mut all_correlations = Vec::new();
    
    for (i, (frame_id, description)) in correlation_scenarios.iter().enumerate() {
        info!("Processing {}: {}", frame_id, description);
        
        let timestamp = Utc::now() + chrono::Duration::milliseconds(i as i64 * 400);
        
        match service.process_frame(frame_id, timestamp).await {
            Ok(result) => {
                info!("  Events: {}, Correlations: {}", 
                      result.detected_events.len(), 
                      result.correlations.len());
                
                // Log correlations
                for correlation in &result.correlations {
                    info!("  Correlation: {:?} (confidence: {:.2}, events: {})",
                          correlation.correlation_type,
                          correlation.confidence,
                          correlation.correlated_events.len());
                }
                
                all_correlations.extend(result.correlations);
            }
            Err(e) => {
                error!("Failed to process correlation frame {}: {}", frame_id, e);
            }
        }
        
        // Add delay between frames
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    }
    
    info!("Event correlation test completed. Total correlations found: {}", all_correlations.len());
    Ok(())
}

/// Display final statistics and results
async fn display_final_statistics(service: &NavigationIntegrationService) -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Final Statistics ===");
    
    match service.get_navigation_statistics().await {
        Ok(stats) => {
            info!("Total Events: {}", stats.total_events);
            info!("Navigation Events: {}", stats.navigation_events);
            info!("Cursor Events: {}", stats.cursor_events);
            info!("Correlation Events: {}", stats.correlation_events);
            info!("Error Count: {}", stats.error_count);
            info!("Average Processing Time: {} ms", stats.average_processing_time_ms);
            
            if let Some(last_update) = stats.last_update {
                info!("Last Update: {}", last_update.format("%Y-%m-%d %H:%M:%S UTC"));
            }
            
            // Display correlation patterns
            if !stats.correlation_patterns.is_empty() {
                info!("Correlation Patterns:");
                for (pattern, count) in &stats.correlation_patterns {
                    info!("  {}: {} occurrences", pattern, count);
                }
            }
            
            // Display storage statistics
            info!("Storage Statistics:");
            info!("  Total Events in Storage: {}", stats.event_storage_stats.total_events);
            info!("  Average Confidence: {:.2}", stats.event_storage_stats.average_confidence);
            info!("  Storage Size: {} bytes", stats.event_storage_stats.total_size_bytes);
        }
        Err(e) => {
            error!("Failed to get statistics: {}", e);
        }
    }
    
    // Display current system state
    if let Some(window_state) = service.get_current_window_state() {
        info!("Current Window: {} - {}", window_state.app_name, window_state.window_title);
    }
    
    let focus_history = service.get_focus_history();
    if !focus_history.is_empty() {
        info!("Recent Focus Changes: {}", focus_history.len());
        for (i, focus_event) in focus_history.iter().rev().take(3).enumerate() {
            info!("  {}: {} -> {}", i + 1, 
                  focus_event.from_app.as_deref().unwrap_or("None"), 
                  focus_event.to_app);
        }
    }
    
    Ok(())
}

/// Test event querying functionality
async fn test_event_querying(service: &NavigationIntegrationService) -> Result<(), Box<dyn std::error::Error>> {
    info!("=== Testing Event Querying ===");
    
    let start_time = Utc::now() - chrono::Duration::minutes(5);
    let end_time = Utc::now();
    
    // Query navigation events
    match service.query_navigation_events_by_time_range(start_time, end_time).await {
        Ok(events) => {
            info!("Found {} events in time range", events.len());
            
            // Display sample events
            for (i, event) in events.iter().take(5).enumerate() {
                info!("  Event {}: {:?} at {} (confidence: {:.2})",
                      i + 1,
                      event.event_type,
                      event.timestamp.format("%H:%M:%S"),
                      event.confidence);
            }
        }
        Err(e) => {
            error!("Failed to query events: {}", e);
        }
    }
    
    Ok(())
}