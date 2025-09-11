# Keyframe Indexer Service

A Rust-based service for extracting keyframes from video segments and generating metadata for the Always-On AI Companion system.

## Features

- **FFmpeg Integration**: Uses FFmpeg bindings for robust video processing
- **Keyframe Extraction**: Extracts keyframes at configurable 1-2 FPS intervals
- **Scene Change Detection**: SSIM and perceptual hash-based scene analysis
- **File Watching**: Automatically processes new video segments
- **Parquet Storage**: Efficient columnar storage for frame metadata
- **Error Handling**: Robust handling of corrupted or incomplete video files
- **macOS Integration**: Collects active application and window information

## Requirements

- Rust 1.70+
- FFmpeg development libraries
- macOS 14+ (for application metadata collection)

## Installation

### Install FFmpeg

```bash
# Using Homebrew
brew install ffmpeg

# Or using MacPorts
sudo port install ffmpeg
```

### Build the Project

```bash
cd keyframe-indexer
cargo build --release
```

## Usage

### Command Line

```bash
# Start the indexer service
./target/release/indexer --watch-dir /path/to/video/segments --output-dir ./output

# Use custom configuration
./target/release/indexer --config custom_config.json --watch-dir /path/to/videos
```

### Configuration

The service uses a JSON configuration file:

```json
{
  "extraction_fps": 1.5,
  "output_dir": "./output",
  "scene_detection": {
    "ssim_threshold": 0.8,
    "phash_distance_threshold": 10,
    "entropy_threshold": 0.1
  },
  "video_extensions": ["mp4", "mov", "avi", "mkv"],
  "max_concurrent_processing": 4
}
```

### As a Library

```rust
use keyframe_indexer::{IndexerService, IndexerConfig};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = IndexerConfig::default();
    let mut service = IndexerService::new(config)?;
    
    service.start_watching("/path/to/video/segments").await?;
    Ok(())
}
```

## Output Format

The service generates Parquet files with the following schema:

| Column | Type | Description |
|--------|------|-------------|
| ts_ns | Int64 | Timestamp in nanoseconds |
| monitor_id | Int32 | Display/monitor identifier |
| segment_id | String | Video segment reference |
| path | String | Path to extracted frame image |
| phash16 | Int64 | 16-bit perceptual hash |
| entropy | Float32 | Image entropy measure |
| app_name | String | Active application name |
| win_title | String | Active window title |
| width | UInt32 | Frame width in pixels |
| height | UInt32 | Frame height in pixels |

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   File Watcher  │───▶│ Keyframe Extract │───▶│ Scene Detector  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Parquet Writer  │◀───│ Metadata Collect │◀───│                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Testing

```bash
# Run all tests
cargo test

# Run with output
cargo test -- --nocapture

# Run specific test
cargo test test_keyframe_extraction
```

## Performance

- **CPU Usage**: Optimized for ≤8% CPU usage during processing
- **Memory**: Efficient streaming processing with configurable batch sizes
- **Storage**: Compressed Parquet format with SNAPPY compression
- **Throughput**: Processes 2-minute video segments at 1-2 FPS extraction rate

## Error Handling

The service includes comprehensive error handling for:

- Corrupted or incomplete video files
- Unsupported video formats
- File system errors
- FFmpeg processing errors
- Parquet writing errors

## Logging

Uses structured logging with the `tracing` crate:

```bash
# Set log level
RUST_LOG=debug ./target/release/indexer --watch-dir /path/to/videos

# JSON logging
RUST_LOG=info ./target/release/indexer --watch-dir /path/to/videos 2>&1 | jq
```

## Integration

This service is designed to work with the Always-On AI Companion system:

1. **Input**: Receives 2-minute H.264 video segments from the recorder daemon
2. **Processing**: Extracts keyframes and generates metadata
3. **Output**: Produces Parquet files for downstream OCR and event processing

## License

Part of the Always-On AI Companion project.