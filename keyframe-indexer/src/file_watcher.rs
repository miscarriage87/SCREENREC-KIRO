use crate::error::{IndexerError, Result};
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::{Path, PathBuf};
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};

pub struct FileWatcher {
    watch_dir: PathBuf,
    sender: mpsc::Sender<PathBuf>,
    video_extensions: Vec<String>,
}

impl FileWatcher {
    pub fn new(watch_dir: &str, sender: mpsc::Sender<PathBuf>) -> Result<Self> {
        let watch_path = PathBuf::from(watch_dir);
        
        if !watch_path.exists() {
            return Err(IndexerError::Config(
                format!("Watch directory does not exist: {}", watch_dir)
            ));
        }
        
        if !watch_path.is_dir() {
            return Err(IndexerError::Config(
                format!("Watch path is not a directory: {}", watch_dir)
            ));
        }
        
        let video_extensions = vec![
            "mp4".to_string(),
            "mov".to_string(),
            "avi".to_string(),
            "mkv".to_string(),
            "m4v".to_string(),
            "webm".to_string(),
        ];
        
        Ok(Self {
            watch_dir: watch_path,
            sender,
            video_extensions,
        })
    }
    
    pub async fn start(&mut self) -> Result<()> {
        info!("Starting file watcher for directory: {}", self.watch_dir.display());
        
        let (tx, mut rx) = std::sync::mpsc::channel();
        let sender_clone = self.sender.clone();
        let video_extensions = self.video_extensions.clone();
        
        // Create watcher
        let mut watcher = RecommendedWatcher::new(
            move |res: notify::Result<Event>| {
                if let Err(e) = tx.send(res) {
                    error!("Failed to send file event: {}", e);
                }
            },
            Config::default(),
        )?;
        
        // Start watching
        watcher.watch(&self.watch_dir, RecursiveMode::Recursive)?;
        
        // Process events in a separate task
        tokio::spawn(async move {
            while let Ok(event_result) = rx.recv() {
                match event_result {
                    Ok(event) => {
                        if let Err(e) = Self::handle_file_event(
                            event,
                            &sender_clone,
                            &video_extensions,
                        ).await {
                            error!("Error handling file event: {}", e);
                        }
                    }
                    Err(e) => {
                        error!("File watcher error: {}", e);
                    }
                }
            }
        });
        
        // Keep the watcher alive
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
        }
    }
    
    async fn handle_file_event(
        event: Event,
        sender: &mpsc::Sender<PathBuf>,
        video_extensions: &[String],
    ) -> Result<()> {
        match event.kind {
            EventKind::Create(_) | EventKind::Modify(_) => {
                for path in event.paths {
                    if Self::is_video_file(&path, video_extensions) {
                        debug!("Detected video file: {}", path.display());
                        
                        // Wait a bit to ensure file is completely written
                        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
                        
                        // Verify file is complete and readable
                        if Self::is_file_complete(&path).await? {
                            info!("Processing new video file: {}", path.display());
                            if let Err(e) = sender.send(path).await {
                                error!("Failed to send video path to processor: {}", e);
                            }
                        } else {
                            warn!("Video file appears incomplete, skipping: {}", path.display());
                        }
                    }
                }
            }
            _ => {
                // Ignore other event types
            }
        }
        
        Ok(())
    }
    
    fn is_video_file(path: &Path, video_extensions: &[String]) -> bool {
        if let Some(extension) = path.extension() {
            if let Some(ext_str) = extension.to_str() {
                return video_extensions.iter().any(|ve| ve.eq_ignore_ascii_case(ext_str));
            }
        }
        false
    }
    
    async fn is_file_complete(path: &Path) -> Result<bool> {
        // Check if file exists and is readable
        if !path.exists() {
            return Ok(false);
        }
        
        // Get initial file size
        let initial_size = match std::fs::metadata(path) {
            Ok(metadata) => metadata.len(),
            Err(_) => return Ok(false),
        };
        
        // Wait a bit and check again
        tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        
        let final_size = match std::fs::metadata(path) {
            Ok(metadata) => metadata.len(),
            Err(_) => return Ok(false),
        };
        
        // File is considered complete if size hasn't changed and is > 0
        Ok(final_size > 0 && final_size == initial_size)
    }
    
    pub fn add_video_extension(&mut self, extension: String) {
        if !self.video_extensions.contains(&extension) {
            self.video_extensions.push(extension);
        }
    }
    
    pub fn set_video_extensions(&mut self, extensions: Vec<String>) {
        self.video_extensions = extensions;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use tokio::sync::mpsc;
    use std::fs;
    
    #[tokio::test]
    async fn test_file_watcher_creation() {
        let temp_dir = TempDir::new().unwrap();
        let (tx, _rx) = mpsc::channel(10);
        
        let watcher = FileWatcher::new(temp_dir.path().to_str().unwrap(), tx);
        assert!(watcher.is_ok());
    }
    
    #[tokio::test]
    async fn test_nonexistent_directory() {
        let (tx, _rx) = mpsc::channel(10);
        let watcher = FileWatcher::new("/nonexistent/directory", tx);
        assert!(watcher.is_err());
    }
    
    #[test]
    fn test_is_video_file() {
        let video_extensions = vec!["mp4".to_string(), "mov".to_string()];
        
        assert!(FileWatcher::is_video_file(Path::new("test.mp4"), &video_extensions));
        assert!(FileWatcher::is_video_file(Path::new("test.MP4"), &video_extensions));
        assert!(FileWatcher::is_video_file(Path::new("test.mov"), &video_extensions));
        assert!(!FileWatcher::is_video_file(Path::new("test.txt"), &video_extensions));
        assert!(!FileWatcher::is_video_file(Path::new("test"), &video_extensions));
    }
    
    #[tokio::test]
    async fn test_file_completeness_check() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test.mp4");
        
        // Non-existent file
        assert!(!FileWatcher::is_file_complete(&test_file).await.unwrap());
        
        // Create empty file
        fs::write(&test_file, b"").unwrap();
        assert!(!FileWatcher::is_file_complete(&test_file).await.unwrap());
        
        // Create file with content
        fs::write(&test_file, b"test content").unwrap();
        assert!(FileWatcher::is_file_complete(&test_file).await.unwrap());
    }
    
    #[test]
    fn test_video_extension_management() {
        let (tx, _rx) = mpsc::channel(10);
        let temp_dir = TempDir::new().unwrap();
        let mut watcher = FileWatcher::new(temp_dir.path().to_str().unwrap(), tx).unwrap();
        
        // Add new extension
        watcher.add_video_extension("flv".to_string());
        assert!(watcher.video_extensions.contains(&"flv".to_string()));
        
        // Don't add duplicate
        let initial_len = watcher.video_extensions.len();
        watcher.add_video_extension("mp4".to_string());
        assert_eq!(watcher.video_extensions.len(), initial_len);
        
        // Set new extensions
        let new_extensions = vec!["webm".to_string(), "ogv".to_string()];
        watcher.set_video_extensions(new_extensions.clone());
        assert_eq!(watcher.video_extensions, new_extensions);
    }
}