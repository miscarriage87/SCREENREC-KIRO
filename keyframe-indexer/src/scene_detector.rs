use crate::error::{IndexerError, Result};
use crate::keyframe_extractor::Keyframe;
use crate::config::SceneDetectionConfig;
use image::{DynamicImage, ImageBuffer, Rgb};
use imageproc::stats::histogram;
use std::path::Path;
use tracing::{debug, warn};

#[derive(Debug, Clone)]
pub struct SceneChange {
    pub frame_index: usize,
    pub timestamp_ns: i64,
    pub change_type: SceneChangeType,
    pub confidence: f32,
    pub ssim_score: Option<f32>,
    pub phash_distance: Option<u32>,
    pub entropy_delta: Option<f32>,
}

#[derive(Debug, Clone)]
pub enum SceneChangeType {
    Cut,           // Abrupt scene change
    Fade,          // Gradual transition
    Motion,        // Significant motion
    ContentChange, // UI or content modification
}

pub struct SceneDetector {
    config: SceneDetectionConfig,
}

impl SceneDetector {
    pub fn new(config: SceneDetectionConfig) -> Result<Self> {
        Ok(Self { config })
    }
    
    pub fn detect_scene_changes(&self, keyframes: &[Keyframe]) -> Result<Vec<SceneChange>> {
        if keyframes.len() < 2 {
            return Ok(Vec::new());
        }
        
        let mut scene_changes = Vec::new();
        let mut previous_image: Option<DynamicImage> = None;
        let mut previous_phash: Option<u64> = None;
        let mut previous_entropy: Option<f32> = None;
        
        for (index, keyframe) in keyframes.iter().enumerate() {
            let current_image = match self.load_image(&keyframe.frame_path) {
                Ok(img) => img,
                Err(e) => {
                    warn!("Failed to load keyframe image {}: {}", keyframe.frame_path, e);
                    continue;
                }
            };
            
            let current_phash = self.calculate_phash(&current_image)?;
            let current_entropy = self.calculate_entropy(&current_image)?;
            
            if let (Some(prev_img), Some(prev_phash), Some(prev_entropy)) = 
                (&previous_image, previous_phash, previous_entropy) {
                
                // Calculate SSIM
                let ssim_score = self.calculate_ssim(prev_img, &current_image)?;
                
                // Calculate pHash distance
                let phash_distance = self.hamming_distance(prev_phash, current_phash);
                
                // Calculate entropy delta
                let entropy_delta = (current_entropy - prev_entropy).abs();
                
                // Determine if this is a scene change
                if let Some(change_type) = self.classify_scene_change(
                    ssim_score,
                    phash_distance,
                    entropy_delta,
                ) {
                    let confidence = self.calculate_confidence(ssim_score, phash_distance, entropy_delta);
                    
                    scene_changes.push(SceneChange {
                        frame_index: index,
                        timestamp_ns: keyframe.timestamp_ns,
                        change_type,
                        confidence,
                        ssim_score: Some(ssim_score),
                        phash_distance: Some(phash_distance),
                        entropy_delta: Some(entropy_delta),
                    });
                    
                    debug!("Scene change detected at frame {}: SSIM={:.3}, pHash distance={}, entropy delta={:.3}",
                           index, ssim_score, phash_distance, entropy_delta);
                }
            }
            
            previous_image = Some(current_image);
            previous_phash = Some(current_phash);
            previous_entropy = Some(current_entropy);
        }
        
        debug!("Detected {} scene changes out of {} keyframes", scene_changes.len(), keyframes.len());
        Ok(scene_changes)
    }
    
    pub fn calculate_phash(&self, image: &DynamicImage) -> Result<u64> {
        // Resize to 8x8 for pHash calculation
        let small_image = image.resize_exact(8, 8, image::imageops::FilterType::Lanczos3);
        let gray_image = small_image.to_luma8();
        
        // Calculate average pixel value
        let mut sum = 0u32;
        for pixel in gray_image.pixels() {
            sum += pixel[0] as u32;
        }
        let average = sum / 64;
        
        // Generate hash based on pixels above/below average
        let mut hash = 0u64;
        for (i, pixel) in gray_image.pixels().enumerate() {
            if pixel[0] as u32 > average {
                hash |= 1 << i;
            }
        }
        
        Ok(hash)
    }
    
    pub fn calculate_ssim(&self, img1: &DynamicImage, img2: &DynamicImage) -> Result<f32> {
        // Convert to grayscale and resize to same dimensions
        let gray1 = img1.resize_exact(64, 64, image::imageops::FilterType::Lanczos3).to_luma8();
        let gray2 = img2.resize_exact(64, 64, image::imageops::FilterType::Lanczos3).to_luma8();
        
        // Calculate means
        let mean1 = self.calculate_mean(&gray1);
        let mean2 = self.calculate_mean(&gray2);
        
        // Calculate variances and covariance
        let mut var1 = 0.0;
        let mut var2 = 0.0;
        let mut covar = 0.0;
        
        for (p1, p2) in gray1.pixels().zip(gray2.pixels()) {
            let diff1 = p1[0] as f32 - mean1;
            let diff2 = p2[0] as f32 - mean2;
            
            var1 += diff1 * diff1;
            var2 += diff2 * diff2;
            covar += diff1 * diff2;
        }
        
        let n = (gray1.width() * gray1.height()) as f32;
        var1 /= n - 1.0;
        var2 /= n - 1.0;
        covar /= n - 1.0;
        
        // SSIM constants
        let c1 = (0.01 * 255.0_f32).powi(2);
        let c2 = (0.03 * 255.0_f32).powi(2);
        
        // Calculate SSIM
        let numerator = (2.0 * mean1 * mean2 + c1) * (2.0 * covar + c2);
        let denominator = (mean1 * mean1 + mean2 * mean2 + c1) * (var1 + var2 + c2);
        
        Ok(numerator / denominator)
    }
    
    fn calculate_mean(&self, image: &ImageBuffer<image::Luma<u8>, Vec<u8>>) -> f32 {
        let sum: u32 = image.pixels().map(|p| p[0] as u32).sum();
        sum as f32 / (image.width() * image.height()) as f32
    }
    
    fn calculate_entropy(&self, image: &DynamicImage) -> Result<f32> {
        let gray_image = image.to_luma8();
        let hist = histogram(&gray_image);
        
        let total_pixels = (gray_image.width() * gray_image.height()) as f32;
        let mut entropy = 0.0;
        
        for channel in hist.channels.iter() {
            for &count in channel.iter() {
                if count > 0 {
                    let probability = count as f32 / total_pixels;
                    entropy -= probability * probability.log2();
                }
            }
        }
        
        Ok(entropy)
    }
    
    fn hamming_distance(&self, hash1: u64, hash2: u64) -> u32 {
        (hash1 ^ hash2).count_ones()
    }
    
    fn classify_scene_change(
        &self,
        ssim_score: f32,
        phash_distance: u32,
        entropy_delta: f32,
    ) -> Option<SceneChangeType> {
        // Scene change detection based on thresholds
        if ssim_score < self.config.ssim_threshold {
            if phash_distance > self.config.phash_distance_threshold * 2 {
                Some(SceneChangeType::Cut)
            } else if entropy_delta > self.config.entropy_threshold * 2.0 {
                Some(SceneChangeType::ContentChange)
            } else {
                Some(SceneChangeType::Fade)
            }
        } else if phash_distance > self.config.phash_distance_threshold {
            Some(SceneChangeType::Motion)
        } else if entropy_delta > self.config.entropy_threshold {
            Some(SceneChangeType::ContentChange)
        } else {
            None
        }
    }
    
    fn calculate_confidence(&self, ssim_score: f32, phash_distance: u32, entropy_delta: f32) -> f32 {
        // Combine multiple metrics to calculate confidence
        let ssim_confidence = 1.0 - ssim_score;
        let phash_confidence = (phash_distance as f32 / 64.0).min(1.0);
        let entropy_confidence = (entropy_delta / 8.0).min(1.0);
        
        // Weighted average
        (ssim_confidence * 0.5 + phash_confidence * 0.3 + entropy_confidence * 0.2).min(1.0)
    }
    
    fn load_image(&self, path: &str) -> Result<DynamicImage> {
        image::open(Path::new(path)).map_err(IndexerError::Image)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use std::fs;
    use image::{ImageBuffer, Rgb, RgbImage};
    use uuid;
    
    fn create_test_image(width: u32, height: u32, color: [u8; 3]) -> DynamicImage {
        let img: RgbImage = ImageBuffer::from_fn(width, height, |_, _| {
            Rgb(color)
        });
        DynamicImage::ImageRgb8(img)
    }
    
    fn create_gradient_image(width: u32, height: u32) -> DynamicImage {
        let img: RgbImage = ImageBuffer::from_fn(width, height, |x, y| {
            let intensity = ((x + y) * 255 / (width + height)) as u8;
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
    
    fn save_test_image(image: &DynamicImage, path: &std::path::Path) -> Result<()> {
        image.save(path).map_err(IndexerError::Image)?;
        Ok(())
    }
    
    #[test]
    fn test_scene_detector_creation() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config);
        assert!(detector.is_ok());
    }
    
    #[test]
    fn test_phash_calculation() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // Test with solid color images
        let black_img = create_test_image(64, 64, [0, 0, 0]);
        let white_img = create_test_image(64, 64, [255, 255, 255]);
        
        let black_hash = detector.calculate_phash(&black_img).unwrap();
        let white_hash = detector.calculate_phash(&white_img).unwrap();
        
        // Black and white images should have very different hashes
        let distance = detector.hamming_distance(black_hash, white_hash);
        assert!(distance > 30, "Expected high hamming distance between black and white images, got {}", distance);
        
        // Same image should have identical hash
        let black_hash2 = detector.calculate_phash(&black_img).unwrap();
        assert_eq!(black_hash, black_hash2);
    }
    
    #[test]
    fn test_phash_similarity() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // Create similar images (slightly different shades of gray)
        let gray1 = create_test_image(64, 64, [100, 100, 100]);
        let gray2 = create_test_image(64, 64, [110, 110, 110]);
        
        let hash1 = detector.calculate_phash(&gray1).unwrap();
        let hash2 = detector.calculate_phash(&gray2).unwrap();
        
        let distance = detector.hamming_distance(hash1, hash2);
        // Similar images should have low hamming distance
        assert!(distance < 10, "Expected low hamming distance for similar images, got {}", distance);
    }
    
    #[test]
    fn test_hamming_distance() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        let hash1 = 0b11110000u64;
        let hash2 = 0b00001111u64;
        let distance = detector.hamming_distance(hash1, hash2);
        assert_eq!(distance, 8);
        
        // Test identical hashes
        let distance_same = detector.hamming_distance(hash1, hash1);
        assert_eq!(distance_same, 0);
        
        // Test completely different hashes
        let hash3 = 0xFFFFFFFFFFFFFFFFu64;
        let hash4 = 0x0000000000000000u64;
        let distance_max = detector.hamming_distance(hash3, hash4);
        assert_eq!(distance_max, 64);
    }
    
    #[test]
    fn test_ssim_calculation() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // Test identical images
        let img1 = create_test_image(64, 64, [128, 128, 128]);
        let img2 = create_test_image(64, 64, [128, 128, 128]);
        let ssim = detector.calculate_ssim(&img1, &img2).unwrap();
        assert!(ssim > 0.99, "SSIM for identical images should be close to 1.0, got {}", ssim);
        
        // Test completely different images
        let black_img = create_test_image(64, 64, [0, 0, 0]);
        let white_img = create_test_image(64, 64, [255, 255, 255]);
        let ssim_diff = detector.calculate_ssim(&black_img, &white_img).unwrap();
        assert!(ssim_diff < 0.5, "SSIM for very different images should be low, got {}", ssim_diff);
        
        // Test similar images
        let gray1 = create_test_image(64, 64, [100, 100, 100]);
        let gray2 = create_test_image(64, 64, [110, 110, 110]);
        let ssim_similar = detector.calculate_ssim(&gray1, &gray2).unwrap();
        assert!(ssim_similar > 0.8, "SSIM for similar images should be high, got {}", ssim_similar);
    }
    
    #[test]
    fn test_entropy_calculation() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // Solid color image should have low entropy
        let solid_img = create_test_image(64, 64, [128, 128, 128]);
        let entropy_solid = detector.calculate_entropy(&solid_img).unwrap();
        assert!(entropy_solid < 1.0, "Solid color image should have low entropy, got {}", entropy_solid);
        
        // Checkerboard pattern should have higher entropy
        let checker_img = create_checkerboard_image(64, 64, 4);
        let entropy_checker = detector.calculate_entropy(&checker_img).unwrap();
        assert!(entropy_checker > entropy_solid, "Checkerboard should have higher entropy than solid color");
        
        // Gradient should have medium entropy
        let gradient_img = create_gradient_image(64, 64);
        let entropy_gradient = detector.calculate_entropy(&gradient_img).unwrap();
        assert!(entropy_gradient > entropy_solid, "Gradient should have higher entropy than solid color");
        assert!(entropy_gradient >= 0.0, "Entropy should be non-negative");
    }
    
    #[test]
    fn test_scene_change_detection_with_synthetic_data() {
        let temp_dir = TempDir::new().unwrap();
        let config = SceneDetectionConfig {
            ssim_threshold: 0.8,
            phash_distance_threshold: 10,
            entropy_threshold: 0.1,
        };
        let detector = SceneDetector::new(config).unwrap();
        
        // Create test images and save them
        let img1_path = temp_dir.path().join("frame1.png");
        let img2_path = temp_dir.path().join("frame2.png");
        let img3_path = temp_dir.path().join("frame3.png");
        
        let img1 = create_test_image(64, 64, [100, 100, 100]);
        let img2 = create_test_image(64, 64, [105, 105, 105]); // Similar to img1
        let img3 = create_test_image(64, 64, [200, 200, 200]); // Very different
        
        save_test_image(&img1, &img1_path).unwrap();
        save_test_image(&img2, &img2_path).unwrap();
        save_test_image(&img3, &img3_path).unwrap();
        
        let keyframes = vec![
            Keyframe {
                id: uuid::Uuid::new_v4(),
                timestamp_ns: 0,
                frame_path: img1_path.to_string_lossy().to_string(),
                segment_id: "test_segment".to_string(),
                width: 64,
                height: 64,
                format: "RGB24".to_string(),
            },
            Keyframe {
                id: uuid::Uuid::new_v4(),
                timestamp_ns: 1_000_000_000, // 1 second later
                frame_path: img2_path.to_string_lossy().to_string(),
                segment_id: "test_segment".to_string(),
                width: 64,
                height: 64,
                format: "RGB24".to_string(),
            },
            Keyframe {
                id: uuid::Uuid::new_v4(),
                timestamp_ns: 2_000_000_000, // 2 seconds later
                frame_path: img3_path.to_string_lossy().to_string(),
                segment_id: "test_segment".to_string(),
                width: 64,
                height: 64,
                format: "RGB24".to_string(),
            },
        ];
        
        let scene_changes = detector.detect_scene_changes(&keyframes).unwrap();
        
        // Should detect one scene change between img2 and img3
        assert_eq!(scene_changes.len(), 1, "Expected 1 scene change, got {}", scene_changes.len());
        assert_eq!(scene_changes[0].frame_index, 2);
        assert!(scene_changes[0].confidence > 0.5, "Scene change confidence should be high");
    }
    
    #[test]
    fn test_scene_change_classification() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // Test cut detection (low SSIM, high pHash distance)
        let change_type = detector.classify_scene_change(0.3, 25, 0.05);
        assert!(matches!(change_type, Some(SceneChangeType::Cut)));
        
        // Test fade detection (low SSIM, medium pHash distance, high entropy delta)
        let change_type = detector.classify_scene_change(0.5, 8, 0.3);
        assert!(matches!(change_type, Some(SceneChangeType::ContentChange)));
        
        // Test motion detection (high SSIM, high pHash distance)
        let change_type = detector.classify_scene_change(0.9, 15, 0.05);
        assert!(matches!(change_type, Some(SceneChangeType::Motion)));
        
        // Test no change (high SSIM, low pHash distance, low entropy delta)
        let change_type = detector.classify_scene_change(0.95, 3, 0.02);
        assert!(change_type.is_none());
    }
    
    #[test]
    fn test_confidence_calculation() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // High confidence scenario (clear scene change)
        let confidence = detector.calculate_confidence(0.2, 30, 0.5);
        assert!(confidence > 0.7, "Expected high confidence for clear scene change, got {}", confidence);
        
        // Low confidence scenario (minimal change)
        let confidence = detector.calculate_confidence(0.95, 2, 0.01);
        assert!(confidence < 0.3, "Expected low confidence for minimal change, got {}", confidence);
        
        // Confidence should be between 0 and 1
        let confidence = detector.calculate_confidence(0.0, 64, 10.0);
        assert!(confidence >= 0.0 && confidence <= 1.0, "Confidence should be between 0 and 1, got {}", confidence);
    }
    
    #[test]
    fn test_empty_keyframes() {
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        let keyframes = Vec::new();
        let changes = detector.detect_scene_changes(&keyframes);
        assert!(changes.is_ok());
        assert!(changes.unwrap().is_empty());
    }
    
    #[test]
    fn test_single_keyframe() {
        let temp_dir = TempDir::new().unwrap();
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        let img_path = temp_dir.path().join("single.png");
        let img = create_test_image(64, 64, [128, 128, 128]);
        save_test_image(&img, &img_path).unwrap();
        
        let keyframes = vec![
            Keyframe {
                id: uuid::Uuid::new_v4(),
                timestamp_ns: 0,
                frame_path: img_path.to_string_lossy().to_string(),
                segment_id: "test_segment".to_string(),
                width: 64,
                height: 64,
                format: "RGB24".to_string(),
            },
        ];
        
        let changes = detector.detect_scene_changes(&keyframes);
        assert!(changes.is_ok());
        assert!(changes.unwrap().is_empty());
    }
    
    #[test]
    fn test_performance_with_multiple_frames() {
        let temp_dir = TempDir::new().unwrap();
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // Create multiple test frames
        let mut keyframes = Vec::new();
        for i in 0..10 {
            let img_path = temp_dir.path().join(format!("frame_{}.png", i));
            let intensity = (i * 25) as u8; // Gradually changing intensity
            let img = create_test_image(64, 64, [intensity, intensity, intensity]);
            save_test_image(&img, &img_path).unwrap();
            
            keyframes.push(Keyframe {
                id: uuid::Uuid::new_v4(),
                timestamp_ns: i as i64 * 1_000_000_000,
                frame_path: img_path.to_string_lossy().to_string(),
                segment_id: "test_segment".to_string(),
                width: 64,
                height: 64,
                format: "RGB24".to_string(),
            });
        }
        
        let start = std::time::Instant::now();
        let changes = detector.detect_scene_changes(&keyframes).unwrap();
        let duration = start.elapsed();
        
        // Should complete quickly (under 1 second for 10 frames)
        assert!(duration.as_secs() < 1, "Scene detection took too long: {:?}", duration);
        
        // Should detect some changes due to gradually changing intensity
        assert!(!changes.is_empty(), "Expected to detect some scene changes");
    }
    
    #[test]
    fn test_error_handling_invalid_image() {
        let temp_dir = TempDir::new().unwrap();
        let config = SceneDetectionConfig::default();
        let detector = SceneDetector::new(config).unwrap();
        
        // Create an invalid image file
        let invalid_path = temp_dir.path().join("invalid.png");
        fs::write(&invalid_path, b"not an image").unwrap();
        
        let keyframes = vec![
            Keyframe {
                id: uuid::Uuid::new_v4(),
                timestamp_ns: 0,
                frame_path: invalid_path.to_string_lossy().to_string(),
                segment_id: "test_segment".to_string(),
                width: 64,
                height: 64,
                format: "RGB24".to_string(),
            },
        ];
        
        // Should handle the error gracefully and return empty results
        let changes = detector.detect_scene_changes(&keyframes);
        assert!(changes.is_ok());
        assert!(changes.unwrap().is_empty());
    }
}