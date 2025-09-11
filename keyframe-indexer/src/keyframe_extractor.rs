use crate::error::{IndexerError, Result};
use ffmpeg_next as ffmpeg;
use std::path::Path;
use tracing::{debug, warn, error};
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone)]
pub struct Keyframe {
    pub id: Uuid,
    pub timestamp_ns: i64,
    pub segment_id: String,
    pub frame_path: String,
    pub width: u32,
    pub height: u32,
    pub format: String,
}

pub struct KeyframeExtractor {
    extraction_fps: f32,
}

impl KeyframeExtractor {
    pub fn new(extraction_fps: f32) -> Result<Self> {
        // Initialize FFmpeg
        ffmpeg::init().map_err(|e| {
            IndexerError::FFmpeg(e)
        })?;
        
        Ok(Self { extraction_fps })
    }
    
    pub fn set_extraction_rate(&mut self, fps: f32) {
        self.extraction_fps = fps;
    }
    
    pub async fn extract_keyframes(&self, video_path: &Path) -> Result<Vec<Keyframe>> {
        debug!("Extracting keyframes from: {}", video_path.display());
        
        // Validate video file exists and is readable
        if !video_path.exists() {
            return Err(IndexerError::CorruptedVideo(
                format!("Video file does not exist: {}", video_path.display())
            ));
        }
        
        let video_path_str = video_path.to_string_lossy().to_string();
        
        // Open input context
        let mut input_context = ffmpeg::format::input(&video_path_str)
            .map_err(|e| {
                error!("Failed to open video file: {}", e);
                IndexerError::CorruptedVideo(
                    format!("Cannot open video file: {}", video_path.display())
                )
            })?;
        
        // Find video stream
        let video_stream_index = input_context
            .streams()
            .best(ffmpeg::media::Type::Video)
            .ok_or_else(|| {
                IndexerError::UnsupportedFormat(
                    "No video stream found in file".to_string()
                )
            })?
            .index();
        
        let video_stream = input_context.stream(video_stream_index).unwrap();
        let time_base = video_stream.time_base();
        let duration = video_stream.duration();
        
        // Create decoder
        let context_decoder = ffmpeg::codec::context::Context::from_parameters(video_stream.parameters())?;
        let mut decoder = context_decoder.decoder().video()?;
        
        // Calculate frame interval based on extraction FPS
        let frame_rate = video_stream.avg_frame_rate();
        let source_fps = frame_rate.numerator() as f32 / frame_rate.denominator() as f32;
        let frame_interval = (source_fps / self.extraction_fps).round() as usize;
        
        debug!("Source FPS: {}, Extraction FPS: {}, Frame interval: {}", 
               source_fps, self.extraction_fps, frame_interval);
        
        let mut keyframes = Vec::new();
        let mut frame_count = 0;
        let segment_id = self.generate_segment_id(video_path);
        
        // Create output directory for frames
        let frames_dir = self.create_frames_directory(&segment_id)?;
        
        for (stream, packet) in input_context.packets() {
            if stream.index() == video_stream_index {
                decoder.send_packet(&packet)?;
                
                let mut decoded_frame = ffmpeg::util::frame::Video::empty();
                while decoder.receive_frame(&mut decoded_frame).is_ok() {
                    if frame_count % frame_interval == 0 {
                        match self.save_keyframe(&decoded_frame, &segment_id, &frames_dir, frame_count).await {
                            Ok(keyframe) => {
                                keyframes.push(keyframe);
                                debug!("Extracted keyframe at frame {}", frame_count);
                            }
                            Err(e) => {
                                warn!("Failed to save keyframe at frame {}: {}", frame_count, e);
                            }
                        }
                    }
                    frame_count += 1;
                }
            }
        }
        
        // Flush decoder
        decoder.send_eof()?;
        let mut decoded_frame = ffmpeg::util::frame::Video::empty();
        while decoder.receive_frame(&mut decoded_frame).is_ok() {
            if frame_count % frame_interval == 0 {
                if let Ok(keyframe) = self.save_keyframe(&decoded_frame, &segment_id, &frames_dir, frame_count).await {
                    keyframes.push(keyframe);
                }
            }
            frame_count += 1;
        }
        
        debug!("Extracted {} keyframes from {} total frames", keyframes.len(), frame_count);
        
        if keyframes.is_empty() {
            warn!("No keyframes extracted from video: {}", video_path.display());
        }
        
        Ok(keyframes)
    }
    
    async fn save_keyframe(
        &self,
        frame: &ffmpeg::util::frame::Video,
        segment_id: &str,
        frames_dir: &Path,
        frame_number: usize,
    ) -> Result<Keyframe> {
        let keyframe_id = Uuid::new_v4();
        let frame_filename = format!("frame_{}_{}.png", segment_id, frame_number);
        let frame_path = frames_dir.join(&frame_filename);
        
        // Convert FFmpeg frame to image
        let width = frame.width();
        let height = frame.height();
        let format = format!("{:?}", frame.format());
        
        // Create RGB image from frame data
        let mut rgb_frame = ffmpeg::util::frame::Video::empty();
        let mut converter = ffmpeg::software::scaling::context::Context::get(
            frame.format(),
            width,
            height,
            ffmpeg::util::format::Pixel::RGB24,
            width,
            height,
            ffmpeg::software::scaling::Flags::BILINEAR,
        )?;
        
        converter.run(frame, &mut rgb_frame)?;
        
        // Save as PNG
        let rgb_data = rgb_frame.data(0);
        let img = image::RgbImage::from_raw(width, height, rgb_data.to_vec())
            .ok_or_else(|| IndexerError::Image(
                image::ImageError::Parameter(image::error::ParameterError::from_kind(
                    image::error::ParameterErrorKind::DimensionMismatch
                ))
            ))?;
        
        img.save(&frame_path)?;
        
        // Calculate timestamp in nanoseconds
        let timestamp_ns = (frame_number as f64 / self.extraction_fps as f64 * 1_000_000_000.0) as i64;
        
        Ok(Keyframe {
            id: keyframe_id,
            timestamp_ns,
            segment_id: segment_id.to_string(),
            frame_path: frame_path.to_string_lossy().to_string(),
            width,
            height,
            format,
        })
    }
    
    fn generate_segment_id(&self, video_path: &Path) -> String {
        // Generate segment ID from video filename and timestamp
        let filename = video_path.file_stem()
            .unwrap_or_default()
            .to_string_lossy();
        let timestamp = Utc::now().timestamp();
        format!("{}_{}", filename, timestamp)
    }
    
    fn create_frames_directory(&self, segment_id: &str) -> Result<std::path::PathBuf> {
        let frames_dir = std::path::PathBuf::from("./frames").join(segment_id);
        std::fs::create_dir_all(&frames_dir)?;
        Ok(frames_dir)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use std::fs;
    
    #[tokio::test]
    async fn test_keyframe_extractor_creation() {
        let extractor = KeyframeExtractor::new(1.0);
        assert!(extractor.is_ok());
    }
    
    #[tokio::test]
    async fn test_extraction_rate_setting() {
        let mut extractor = KeyframeExtractor::new(1.0).unwrap();
        extractor.set_extraction_rate(2.0);
        assert_eq!(extractor.extraction_fps, 2.0);
    }
    
    #[tokio::test]
    async fn test_nonexistent_video_file() {
        let extractor = KeyframeExtractor::new(1.0).unwrap();
        let result = extractor.extract_keyframes(Path::new("nonexistent.mp4")).await;
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), IndexerError::CorruptedVideo(_)));
    }
    
    #[test]
    fn test_segment_id_generation() {
        let extractor = KeyframeExtractor::new(1.0).unwrap();
        let video_path = Path::new("test_video.mp4");
        let segment_id = extractor.generate_segment_id(video_path);
        assert!(segment_id.starts_with("test_video_"));
    }
}