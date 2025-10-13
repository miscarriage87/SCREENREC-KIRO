use thiserror::Error;

pub type Result<T> = std::result::Result<T, IndexerError>;

#[derive(Error, Debug)]
pub enum IndexerError {
    #[cfg(feature = "ffmpeg")]
    #[error("FFmpeg error: {0}")]
    FFmpeg(#[from] ffmpeg_next::Error),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("Image processing error: {0}")]
    Image(#[from] image::ImageError),
    
    #[error("Arrow error: {0}")]
    Arrow(#[from] arrow::error::ArrowError),
    
    #[error("Parquet error: {0}")]
    Parquet(#[from] parquet::errors::ParquetError),
    
    #[error("DataFusion error: {0}")]
    DataFusion(#[from] datafusion::error::DataFusionError),
    
    #[error("Serialization error: {0}")]
    Serde(#[from] serde_json::Error),
    
    #[error("File watcher error: {0}")]
    Notify(#[from] notify::Error),
    
    #[error("Video file is corrupted or incomplete: {0}")]
    CorruptedVideo(String),
    
    #[error("Unsupported video format: {0}")]
    UnsupportedFormat(String),
    
    #[error("Configuration error: {0}")]
    Config(String),
    
    #[error("Metadata collection error: {0}")]
    Metadata(String),
    
    #[error("Navigation detection error: {0}")]
    Navigation(String),
    
    #[error("Cursor tracking error: {0}")]
    CursorTracking(String),
    
    #[error("Event correlation error: {0}")]
    EventCorrelation(String),
}