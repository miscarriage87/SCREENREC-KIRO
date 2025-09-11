use thiserror::Error;

pub type Result<T> = std::result::Result<T, IndexerError>;

#[derive(Error, Debug)]
pub enum IndexerError {
    #[error("FFmpeg error: {0}")]
    FFmpeg(#[from] ffmpeg_next::Error),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("Image processing error: {0}")]
    Image(#[from] image::ImageError),
    
    #[error("Parquet error: {0}")]
    Parquet(#[from] parquet::errors::ParquetError),
    
    #[error("Arrow error: {0}")]
    Arrow(#[from] arrow::error::ArrowError),
    
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
}