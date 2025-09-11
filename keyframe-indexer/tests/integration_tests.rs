use keyframe_indexer::{IndexerService, IndexerConfig};
use keyframe_indexer::scene_detector::{SceneDetector, SceneChangeType};
use keyframe_indexer::keyframe_extractor::{KeyframeExtractor, Keyframe};
use keyframe_indexer::config::SceneDetectionConfig;
use tempfile::TempDir;
use std::fs;
use std::path::Path;
use tokio::time::{timeout, Duration};
use image::{ImageBuffer, Rgb, RgbImage, DynamicImage};
use uuid::Uuid;

#[tokio::test]
async fn test_end_to_end_processing() {
    // This test would require actual video files, so we'll simulate the workflow
    let temp_dir = TempDir::new().unwrap();
    let config = IndexerConfig {
        extraction_fps: 1.0,
        output_dir: temp_dir.path().join("output").to_string_lossy().to_string(),
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
}

#[tokio::test]
async fn test_config_validation() {
    // Test invalid extraction FPS
    let mut config = IndexerConfig::default();
    config.extraction_fps = -1.0;
    
    let result = config.validate();
    assert!(result.is_err());
    
    // Test invalid SSIM threshold
    config.extraction_fps = 1.0;
    config.scene_detection.ssim_threshold = 2.0;
    
    let result = config.validate();
    assert!(result.is_err());
}

#[tokio::test]
async fn test_directory_creation() {
    let temp_dir = TempDir::new().unwrap();
    let output_dir = temp_dir.path().join("nonexistent").join("output");
    
    let config = IndexerConfig {
        output_dir: output_dir.to_string_lossy().to_string(),
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    assert!(output_dir.exists());
}

#[tokio::test]
async fn test_concurrent_processing_limit() {
    let config = IndexerConfig {
        max_concurrent_processing: 0,
        ..Default::default()
    };
    
    let result = config.validate();
    assert!(result.is_err());
}

// Helper function to create a minimal test video file (placeholder)
fn create_test_video(path: &Path) -> std::io::Result<()> {
    // In a real implementation, this would create a valid video file
    // For testing purposes, we'll create a placeholder file
    fs::write(path, b"fake video content")?;
    Ok(())
}

#[tokio::test]
async fn test_video_file_detection() {
    let temp_dir = TempDir::new().unwrap();
    
    // Create test files
    let video_file = temp_dir.path().join("test.mp4");
    let text_file = temp_dir.path().join("test.txt");
    
    create_test_video(&video_file).unwrap();
    fs::write(&text_file, b"not a video").unwrap();
    
    let config = IndexerConfig::default();
    
    // Video extensions should include mp4
    assert!(config.video_extensions.contains(&"mp4".to_string()));
    
    // Check file extension matching
    assert!(video_file.extension().unwrap() == "mp4");
    assert!(text_file.extension().unwrap() == "txt");
}

#[tokio::test]
async fn test_error_recovery() {
    let temp_dir = TempDir::new().unwrap();
    let config = IndexerConfig {
        output_dir: temp_dir.path().to_string_lossy().to_string(),
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    
    // Test that service can be created even with various edge cases
    // In a real scenario, we'd test actual error recovery mechanisms
}

#[tokio::test]
async fn test_performance_requirements() {
    // Test that the service can handle the performance requirements
    // This is a placeholder for actual performance testing
    
    let config = IndexerConfig {
        extraction_fps: 2.0, // Maximum extraction rate
        max_concurrent_processing: 4,
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    
    // In a real test, we would:
    // 1. Process multiple video segments simultaneously
    // 2. Measure CPU usage and ensure it stays ≤8%
    // 3. Verify processing speed meets requirements
    // 4. Test memory usage remains stable
}

#[tokio::test]
async fn test_batch_processing() {
    let temp_dir = TempDir::new().unwrap();
    let config = IndexerConfig {
        output_dir: temp_dir.path().to_string_lossy().to_string(),
        max_concurrent_processing: 2,
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    
    // Test that service can handle multiple files
    // In practice, this would involve creating multiple test video files
    // and verifying they're all processed correctly
}

#[tokio::test]
async fn test_metadata_accuracy() {
    // Test that extracted metadata is accurate and complete
    // This would involve:
    // 1. Creating test videos with known properties
    // 2. Processing them through the indexer
    // 3. Verifying the output metadata matches expectations
    
    let config = IndexerConfig::default();
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    
    // Placeholder for actual metadata accuracy testing
}

#[tokio::test]
async fn test_timing_accuracy() {
    // Test that keyframe extraction timing is accurate
    // Requirements specify 1-2 FPS extraction rate
    
    let config = IndexerConfig {
        extraction_fps: 1.5,
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    
    // In a real test, we would:
    // 1. Create a video with known duration
    // 2. Extract keyframes
    // 3. Verify the timing between keyframes matches the configured FPS
    // 4. Ensure timestamps are accurate to nanosecond precision
}

#[tokio::test]
async fn test_file_watching_responsiveness() {
    let temp_dir = TempDir::new().unwrap();
    let watch_dir = temp_dir.path().join("watch");
    fs::create_dir_all(&watch_dir).unwrap();
    
    let config = IndexerConfig {
        output_dir: temp_dir.path().join("output").to_string_lossy().to_string(),
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    
    // Test file watcher creation and basic functionality
    // In a full test, we would:
    // 1. Start the file watcher
    // 2. Create a new video file in the watch directory
    // 3. Verify the file is detected and processed quickly
    // 4. Measure response time to ensure it meets requirements
}

#[tokio::test]
async fn test_corrupted_file_handling() {
    let temp_dir = TempDir::new().unwrap();
    let corrupted_file = temp_dir.path().join("corrupted.mp4");
    
    // Create a file with invalid video content
    fs::write(&corrupted_file, b"this is not a valid video file").unwrap();
    
    let config = IndexerConfig {
        output_dir: temp_dir.path().join("output").to_string_lossy().to_string(),
        ..Default::default()
    };
    
    let service = IndexerService::new(config);
    assert!(service.is_ok());
    
    // In a real test, we would:
    // 1. Attempt to process the corrupted file
    // 2. Verify that appropriate errors are returned
    // 3. Ensure the service continues to function normally
    // 4. Check that error logging is appropriate
}

// Helper functions for creating test images
fn create_solid_color_image(width: u32, height: u32, color: [u8; 3]) -> DynamicImage {
    let img: RgbImage = ImageBuffer::from_fn(width, height, |_, _| {
        Rgb(color)
    });
    DynamicImage::ImageRgb8(img)
}

fn create_gradient_image(width: u32, height: u32, horizontal: bool) -> DynamicImage {
    let img: RgbImage = ImageBuffer::from_fn(width, height, |x, y| {
        let intensity = if horizontal {
            (x * 255 / width) as u8
        } else {
            (y * 255 / height) as u8
        };
        Rgb([intensity, intensity, intensity])
    });
    DynamicImage::ImageRgb8(img)
}

fn create_checkerboard_image(width: u32, height: u32, square_size: u32) -> DynamicImage {
    let img: RgbImage = ImageBuffer::from_fn(width, height, |x, y| {
        let checker_x = (x / square_size) % 2;
        let checker_y = (y / square_size) % 2;
        let is_white = (checker_x + checker_y) % 2 == 0;
        if is_white {
            Rgb([255, 255, 255])
        } else {
            Rgb([0, 0, 0])
        }
    });
    DynamicImage::ImageRgb8(img)
}

fn create_noise_image(width: u32, height: u32, seed: u64) -> DynamicImage {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    
    let img: RgbImage = ImageBuffer::from_fn(width, height, |x, y| {
        let mut hasher = DefaultHasher::new();
        (seed, x, y).hash(&mut hasher);
        let hash = hasher.finish();
        let intensity = (hash % 256) as u8;
        Rgb([intensity, intensity, intensity])
    });
    DynamicImage::ImageRgb8(img)
}

fn save_test_image(image: &DynamicImage, path: &Path) -> Result<(), Box<dyn std::error::Error>> {
    image.save(path)?;
    Ok(())
}

#[tokio::test]
async fn test_scene_detection_accuracy_with_known_samples() {
    let temp_dir = TempDir::new().unwrap();
    let config = SceneDetectionConfig {
        ssim_threshold: 0.8,
        phash_distance_threshold: 10,
        entropy_threshold: 0.1,
    };
    let detector = SceneDetector::new(config).unwrap();
    
    // Test Case 1: Gradual fade transition
    let fade_frames = create_fade_sequence(&temp_dir, "fade").await;
    let fade_changes = detector.detect_scene_changes(&fade_frames).unwrap();
    
    // Should detect scene changes during the fade
    assert!(!fade_changes.is_empty(), "Should detect changes during fade transition");
    
    // Test Case 2: Abrupt cut
    let cut_frames = create_cut_sequence(&temp_dir, "cut").await;
    let cut_changes = detector.detect_scene_changes(&cut_frames).unwrap();
    
    // Should detect a clear cut
    assert!(!cut_changes.is_empty(), "Should detect abrupt cut");
    let cut_change = &cut_changes[0];
    assert!(matches!(cut_change.change_type, SceneChangeType::Cut | SceneChangeType::ContentChange));
    assert!(cut_change.confidence > 0.7, "Cut detection should have high confidence");
    
    // Test Case 3: Motion without scene change
    let motion_frames = create_motion_sequence(&temp_dir, "motion").await;
    let motion_changes = detector.detect_scene_changes(&motion_frames).unwrap();
    
    // May detect motion but should not be classified as major scene change
    for change in &motion_changes {
        if matches!(change.change_type, SceneChangeType::Motion) {
            assert!(change.confidence < 0.9, "Motion should have lower confidence than cuts");
        }
    }
    
    // Test Case 4: Static scene (no changes)
    let static_frames = create_static_sequence(&temp_dir, "static").await;
    let static_changes = detector.detect_scene_changes(&static_frames).unwrap();
    
    // Should detect minimal or no changes
    assert!(static_changes.len() <= 1, "Static scene should have minimal changes");
}

async fn create_fade_sequence(temp_dir: &TempDir, prefix: &str) -> Vec<Keyframe> {
    let mut keyframes = Vec::new();
    
    // Create a fade from black to white over 5 frames
    for i in 0..5 {
        let intensity = (i * 255 / 4) as u8;
        let img = create_solid_color_image(128, 128, [intensity, intensity, intensity]);
        let img_path = temp_dir.path().join(format!("{}_{}.png", prefix, i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 500_000_000, // 0.5 seconds apart
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: format!("{}_segment", prefix),
            width: 128,
            height: 128,
            format: "RGB24".to_string(),
        });
    }
    
    keyframes
}

async fn create_cut_sequence(temp_dir: &TempDir, prefix: &str) -> Vec<Keyframe> {
    let mut keyframes = Vec::new();
    
    // Create an abrupt cut: 3 black frames, then 3 white frames
    for i in 0..6 {
        let color = if i < 3 { [0, 0, 0] } else { [255, 255, 255] };
        let img = create_solid_color_image(128, 128, color);
        let img_path = temp_dir.path().join(format!("{}_{}.png", prefix, i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 500_000_000,
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: format!("{}_segment", prefix),
            width: 128,
            height: 128,
            format: "RGB24".to_string(),
        });
    }
    
    keyframes
}

async fn create_motion_sequence(temp_dir: &TempDir, prefix: &str) -> Vec<Keyframe> {
    let mut keyframes = Vec::new();
    
    // Create motion by shifting a checkerboard pattern
    for i in 0..5 {
        let offset = i * 4; // Shift the pattern
        let img: RgbImage = ImageBuffer::from_fn(128, 128, |x, y| {
            let shifted_x = (x + offset) % 128;
            let checker_x = (shifted_x / 8) % 2;
            let checker_y = (y / 8) % 2;
            let is_white = (checker_x + checker_y) % 2 == 0;
            if is_white {
                Rgb([255, 255, 255])
            } else {
                Rgb([0, 0, 0])
            }
        });
        
        let img = DynamicImage::ImageRgb8(img);
        let img_path = temp_dir.path().join(format!("{}_{}.png", prefix, i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 500_000_000,
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: format!("{}_segment", prefix),
            width: 128,
            height: 128,
            format: "RGB24".to_string(),
        });
    }
    
    keyframes
}

async fn create_static_sequence(temp_dir: &TempDir, prefix: &str) -> Vec<Keyframe> {
    let mut keyframes = Vec::new();
    
    // Create identical frames (static scene)
    let img = create_solid_color_image(128, 128, [128, 128, 128]);
    
    for i in 0..5 {
        let img_path = temp_dir.path().join(format!("{}_{}.png", prefix, i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 500_000_000,
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: format!("{}_segment", prefix),
            width: 128,
            height: 128,
            format: "RGB24".to_string(),
        });
    }
    
    keyframes
}

#[tokio::test]
async fn test_scene_detection_performance_requirements() {
    let temp_dir = TempDir::new().unwrap();
    let config = SceneDetectionConfig::default();
    let detector = SceneDetector::new(config).unwrap();
    
    // Create a large number of test frames to test performance
    let mut keyframes = Vec::new();
    for i in 0..100 {
        let intensity = (i * 255 / 100) as u8;
        let img = create_solid_color_image(64, 64, [intensity, intensity, intensity]);
        let img_path = temp_dir.path().join(format!("perf_frame_{}.png", i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 100_000_000, // 0.1 seconds apart
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: "performance_test".to_string(),
            width: 64,
            height: 64,
            format: "RGB24".to_string(),
        });
    }
    
    let start = std::time::Instant::now();
    let changes = detector.detect_scene_changes(&keyframes).unwrap();
    let duration = start.elapsed();
    
    // Performance requirement: should process 100 frames quickly
    // At 1-2 FPS extraction rate, this represents ~50-100 seconds of video
    assert!(duration.as_secs() < 5, "Scene detection took too long: {:?}", duration);
    
    // Should detect gradual changes
    assert!(!changes.is_empty(), "Should detect some scene changes in gradient");
    
    println!("Processed {} frames in {:?}, detected {} scene changes", 
             keyframes.len(), duration, changes.len());
}

#[tokio::test]
async fn test_scene_detection_edge_cases() {
    let temp_dir = TempDir::new().unwrap();
    let config = SceneDetectionConfig::default();
    let detector = SceneDetector::new(config).unwrap();
    
    // Test Case 1: Very similar frames (should not detect changes)
    let similar_frames = create_similar_frames(&temp_dir, "similar").await;
    let similar_changes = detector.detect_scene_changes(&similar_frames).unwrap();
    assert!(similar_changes.is_empty() || similar_changes.len() <= 1, 
            "Very similar frames should not trigger scene changes");
    
    // Test Case 2: High contrast changes (should definitely detect)
    let contrast_frames = create_high_contrast_frames(&temp_dir, "contrast").await;
    let contrast_changes = detector.detect_scene_changes(&contrast_frames).unwrap();
    assert!(!contrast_changes.is_empty(), "High contrast changes should be detected");
    
    // Test Case 3: Noisy frames (should handle gracefully)
    let noisy_frames = create_noisy_frames(&temp_dir, "noisy").await;
    let noisy_changes = detector.detect_scene_changes(&noisy_frames).unwrap();
    // Should complete without errors, changes may vary
    assert!(noisy_changes.len() <= noisy_frames.len(), "Should handle noisy frames gracefully");
}

async fn create_similar_frames(temp_dir: &TempDir, prefix: &str) -> Vec<Keyframe> {
    let mut keyframes = Vec::new();
    
    // Create very similar gray frames with tiny variations
    for i in 0..5 {
        let intensity = 128 + (i as i32 - 2); // 126, 127, 128, 129, 130
        let intensity = intensity.max(0).min(255) as u8;
        let img = create_solid_color_image(64, 64, [intensity, intensity, intensity]);
        let img_path = temp_dir.path().join(format!("{}_{}.png", prefix, i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 500_000_000,
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: format!("{}_segment", prefix),
            width: 64,
            height: 64,
            format: "RGB24".to_string(),
        });
    }
    
    keyframes
}

async fn create_high_contrast_frames(temp_dir: &TempDir, prefix: &str) -> Vec<Keyframe> {
    let mut keyframes = Vec::new();
    
    // Alternate between black and white frames
    for i in 0..4 {
        let color = if i % 2 == 0 { [0, 0, 0] } else { [255, 255, 255] };
        let img = create_solid_color_image(64, 64, color);
        let img_path = temp_dir.path().join(format!("{}_{}.png", prefix, i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 500_000_000,
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: format!("{}_segment", prefix),
            width: 64,
            height: 64,
            format: "RGB24".to_string(),
        });
    }
    
    keyframes
}

async fn create_noisy_frames(temp_dir: &TempDir, prefix: &str) -> Vec<Keyframe> {
    let mut keyframes = Vec::new();
    
    // Create frames with random noise
    for i in 0..5 {
        let img = create_noise_image(64, 64, i as u64);
        let img_path = temp_dir.path().join(format!("{}_{}.png", prefix, i));
        save_test_image(&img, &img_path).unwrap();
        
        keyframes.push(Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: i as i64 * 500_000_000,
            frame_path: img_path.to_string_lossy().to_string(),
            segment_id: format!("{}_segment", prefix),
            width: 64,
            height: 64,
            format: "RGB24".to_string(),
        });
    }
    
    keyframes
}