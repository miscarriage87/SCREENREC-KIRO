use serde::{Deserialize, Serialize};
use std::path::Path;
use crate::error::{IndexerError, Result};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexerConfig {
    pub extraction_fps: f32,
    pub output_dir: String,
    pub scene_detection: SceneDetectionConfig,
    pub video_extensions: Vec<String>,
    pub max_concurrent_processing: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SceneDetectionConfig {
    pub ssim_threshold: f32,
    pub phash_distance_threshold: u32,
    pub entropy_threshold: f32,
}

impl Default for IndexerConfig {
    fn default() -> Self {
        Self {
            extraction_fps: 1.5, // 1-2 FPS as specified in requirements
            output_dir: "./output".to_string(),
            scene_detection: SceneDetectionConfig::default(),
            video_extensions: vec![
                "mp4".to_string(),
                "mov".to_string(),
                "avi".to_string(),
                "mkv".to_string(),
            ],
            max_concurrent_processing: 4,
        }
    }
}

impl Default for SceneDetectionConfig {
    fn default() -> Self {
        Self {
            ssim_threshold: 0.8,
            phash_distance_threshold: 10,
            entropy_threshold: 0.1,
        }
    }
}

impl IndexerConfig {
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let content = std::fs::read_to_string(path)
            .map_err(|e| IndexerError::Config(format!("Failed to read config file: {}", e)))?;
        
        let config: IndexerConfig = serde_json::from_str(&content)
            .map_err(|e| IndexerError::Config(format!("Failed to parse config: {}", e)))?;
        
        config.validate()?;
        Ok(config)
    }
    
    pub fn to_file<P: AsRef<Path>>(&self, path: P) -> Result<()> {
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(path, content)
            .map_err(|e| IndexerError::Config(format!("Failed to write config file: {}", e)))?;
        Ok(())
    }
    
    fn validate(&self) -> Result<()> {
        if self.extraction_fps <= 0.0 || self.extraction_fps > 30.0 {
            return Err(IndexerError::Config(
                "extraction_fps must be between 0 and 30".to_string()
            ));
        }
        
        if self.scene_detection.ssim_threshold < 0.0 || self.scene_detection.ssim_threshold > 1.0 {
            return Err(IndexerError::Config(
                "ssim_threshold must be between 0 and 1".to_string()
            ));
        }
        
        if self.max_concurrent_processing == 0 {
            return Err(IndexerError::Config(
                "max_concurrent_processing must be greater than 0".to_string()
            ));
        }
        
        Ok(())
    }
}