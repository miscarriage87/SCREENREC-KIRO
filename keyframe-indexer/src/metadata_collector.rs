use crate::error::{IndexerError, Result};
use crate::keyframe_extractor::Keyframe;
use serde::{Deserialize, Serialize};
use std::process::Command;
use tracing::{debug, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameMetadata {
    pub ts_ns: i64,
    pub monitor_id: i32,
    pub segment_id: String,
    pub path: String,
    pub phash16: i64,
    pub entropy: f32,
    pub app_name: String,
    pub win_title: String,
    pub width: u32,
    pub height: u32,
}

pub struct MetadataCollector {
    // Cache for active application info to avoid repeated system calls
    app_cache: Option<(String, String, std::time::Instant)>,
    cache_duration: std::time::Duration,
}

impl MetadataCollector {
    pub fn new() -> Result<Self> {
        Ok(Self {
            app_cache: None,
            cache_duration: std::time::Duration::from_secs(1), // Cache for 1 second
        })
    }
    
    pub async fn collect_metadata(&mut self, keyframe: &Keyframe) -> Result<FrameMetadata> {
        debug!("Collecting metadata for keyframe: {}", keyframe.id);
        
        // Get active application and window information
        let (app_name, win_title) = self.get_active_app_info().await?;
        
        // Calculate perceptual hash (simplified 16-bit version)
        let phash16 = self.calculate_simple_phash(&keyframe.frame_path).await?;
        
        // Calculate image entropy
        let entropy = self.calculate_image_entropy(&keyframe.frame_path).await?;
        
        // Extract monitor ID from segment ID or default to 0
        let monitor_id = self.extract_monitor_id(&keyframe.segment_id);
        
        Ok(FrameMetadata {
            ts_ns: keyframe.timestamp_ns,
            monitor_id,
            segment_id: keyframe.segment_id.clone(),
            path: keyframe.frame_path.clone(),
            phash16,
            entropy,
            app_name,
            win_title,
            width: keyframe.width,
            height: keyframe.height,
        })
    }
    
    async fn get_active_app_info(&mut self) -> Result<(String, String)> {
        // Check cache first
        if let Some((app_name, win_title, timestamp)) = &self.app_cache {
            if timestamp.elapsed() < self.cache_duration {
                return Ok((app_name.clone(), win_title.clone()));
            }
        }
        
        // Get fresh application info using macOS APIs
        let (app_name, win_title) = self.query_active_app_macos().await
            .unwrap_or_else(|_| ("Unknown".to_string(), "Unknown".to_string()));
        
        // Update cache
        self.app_cache = Some((app_name.clone(), win_title.clone(), std::time::Instant::now()));
        
        Ok((app_name, win_title))
    }
    
    async fn query_active_app_macos(&self) -> Result<(String, String)> {
        // Use AppleScript to get active application and window title
        let script = r#"
            tell application "System Events"
                set frontApp to first application process whose frontmost is true
                set appName to name of frontApp
                try
                    set winTitle to name of first window of frontApp
                on error
                    set winTitle to ""
                end try
                return appName & "|" & winTitle
            end tell
        "#;
        
        let output = Command::new("osascript")
            .arg("-e")
            .arg(script)
            .output()
            .map_err(|e| IndexerError::Metadata(format!("Failed to execute AppleScript: {}", e)))?;
        
        if !output.status.success() {
            warn!("AppleScript failed: {}", String::from_utf8_lossy(&output.stderr));
            return Ok(("Unknown".to_string(), "Unknown".to_string()));
        }
        
        let result = String::from_utf8_lossy(&output.stdout);
        let parts: Vec<&str> = result.trim().split('|').collect();
        
        let app_name = parts.get(0).unwrap_or(&"Unknown").to_string();
        let win_title = parts.get(1).unwrap_or(&"Unknown").to_string();
        
        debug!("Active app: {} - {}", app_name, win_title);
        Ok((app_name, win_title))
    }
    
    async fn calculate_simple_phash(&self, image_path: &str) -> Result<i64> {
        // Load and process image for pHash calculation
        let img = image::open(image_path)
            .map_err(|e| IndexerError::Metadata(format!("Failed to load image: {}", e)))?;
        
        // Resize to 8x8 for simple hash
        let small_img = img.resize_exact(8, 8, image::imageops::FilterType::Lanczos3);
        let gray_img = small_img.to_luma8();
        
        // Calculate average pixel value
        let mut sum = 0u32;
        for pixel in gray_img.pixels() {
            sum += pixel[0] as u32;
        }
        let average = sum / 64;
        
        // Generate 16-bit hash (using only first 16 pixels for simplicity)
        let mut hash = 0i64;
        for (i, pixel) in gray_img.pixels().take(16).enumerate() {
            if pixel[0] as u32 > average {
                hash |= 1 << i;
            }
        }
        
        Ok(hash)
    }
    
    async fn calculate_image_entropy(&self, image_path: &str) -> Result<f32> {
        let img = image::open(image_path)
            .map_err(|e| IndexerError::Metadata(format!("Failed to load image: {}", e)))?;
        
        let gray_img = img.to_luma8();
        
        // Calculate histogram
        let mut histogram = [0u32; 256];
        for pixel in gray_img.pixels() {
            histogram[pixel[0] as usize] += 1;
        }
        
        // Calculate entropy
        let total_pixels = (gray_img.width() * gray_img.height()) as f32;
        let mut entropy = 0.0f32;
        
        for &count in &histogram {
            if count > 0 {
                let probability = count as f32 / total_pixels;
                entropy -= probability * probability.log2();
            }
        }
        
        Ok(entropy)
    }
    
    fn extract_monitor_id(&self, segment_id: &str) -> i32 {
        // Try to extract monitor ID from segment ID
        // Format might be: "segment_monitor1_timestamp" or similar
        if let Some(monitor_part) = segment_id.split('_').find(|part| part.starts_with("monitor")) {
            if let Some(id_str) = monitor_part.strip_prefix("monitor") {
                if let Ok(id) = id_str.parse::<i32>() {
                    return id;
                }
            }
        }
        
        // Default to monitor 0 if not found
        0
    }
    
    pub fn clear_cache(&mut self) {
        self.app_cache = None;
    }
    
    pub fn set_cache_duration(&mut self, duration: std::time::Duration) {
        self.cache_duration = duration;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use std::fs;
    use uuid::Uuid;
    
    #[tokio::test]
    async fn test_metadata_collector_creation() {
        let collector = MetadataCollector::new();
        assert!(collector.is_ok());
    }
    
    #[test]
    fn test_monitor_id_extraction() {
        let collector = MetadataCollector::new().unwrap();
        
        assert_eq!(collector.extract_monitor_id("segment_monitor1_123456"), 1);
        assert_eq!(collector.extract_monitor_id("segment_monitor2_789012"), 2);
        assert_eq!(collector.extract_monitor_id("segment_123456"), 0);
        assert_eq!(collector.extract_monitor_id("invalid_format"), 0);
    }
    
    #[tokio::test]
    async fn test_simple_phash_calculation() {
        let temp_dir = TempDir::new().unwrap();
        let image_path = temp_dir.path().join("test.png");
        
        // Create a simple test image
        let img = image::RgbImage::new(64, 64);
        img.save(&image_path).unwrap();
        
        let collector = MetadataCollector::new().unwrap();
        let phash = collector.calculate_simple_phash(image_path.to_str().unwrap()).await;
        
        assert!(phash.is_ok());
    }
    
    #[tokio::test]
    async fn test_entropy_calculation() {
        let temp_dir = TempDir::new().unwrap();
        let image_path = temp_dir.path().join("test.png");
        
        // Create a test image with some variation
        let mut img = image::RgbImage::new(64, 64);
        for (x, y, pixel) in img.enumerate_pixels_mut() {
            *pixel = image::Rgb([(x + y) as u8, 128, 200]);
        }
        img.save(&image_path).unwrap();
        
        let collector = MetadataCollector::new().unwrap();
        let entropy = collector.calculate_image_entropy(image_path.to_str().unwrap()).await;
        
        assert!(entropy.is_ok());
        assert!(entropy.unwrap() > 0.0);
    }
    
    #[tokio::test]
    async fn test_metadata_collection() {
        let temp_dir = TempDir::new().unwrap();
        let image_path = temp_dir.path().join("test.png");
        
        // Create a test image
        let img = image::RgbImage::new(64, 64);
        img.save(&image_path).unwrap();
        
        let keyframe = Keyframe {
            id: Uuid::new_v4(),
            timestamp_ns: 1000000000,
            segment_id: "test_segment_monitor1_123456".to_string(),
            frame_path: image_path.to_string_lossy().to_string(),
            width: 64,
            height: 64,
            format: "RGB".to_string(),
        };
        
        let mut collector = MetadataCollector::new().unwrap();
        let metadata = collector.collect_metadata(&keyframe).await;
        
        assert!(metadata.is_ok());
        let metadata = metadata.unwrap();
        assert_eq!(metadata.ts_ns, 1000000000);
        assert_eq!(metadata.monitor_id, 1);
        assert_eq!(metadata.width, 64);
        assert_eq!(metadata.height, 64);
    }
    
    #[test]
    fn test_cache_management() {
        let mut collector = MetadataCollector::new().unwrap();
        
        // Test cache duration setting
        let new_duration = std::time::Duration::from_secs(5);
        collector.set_cache_duration(new_duration);
        assert_eq!(collector.cache_duration, new_duration);
        
        // Test cache clearing
        collector.clear_cache();
        assert!(collector.app_cache.is_none());
    }
}