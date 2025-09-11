use anyhow::Result;
use clap::Parser;
use keyframe_indexer::{IndexerService, IndexerConfig};
use tracing::{info, error};
use tracing_subscriber;

#[derive(Parser)]
#[command(name = "keyframe-indexer")]
#[command(about = "A service for extracting keyframes from video segments")]
struct Cli {
    /// Configuration file path
    #[arg(short, long, default_value = "config.json")]
    config: String,
    
    /// Watch directory for new video segments
    #[arg(short, long)]
    watch_dir: Option<String>,
    
    /// Output directory for frame metadata
    #[arg(short, long)]
    output_dir: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::init();
    
    let cli = Cli::parse();
    
    let config = IndexerConfig::from_file(&cli.config)
        .unwrap_or_else(|_| {
            info!("Using default configuration");
            IndexerConfig::default()
        });
    
    let mut service = IndexerService::new(config)?;
    
    if let Some(watch_dir) = cli.watch_dir {
        info!("Starting indexer service watching directory: {}", watch_dir);
        service.start_watching(&watch_dir).await?;
    } else {
        error!("No watch directory specified");
        std::process::exit(1);
    }
    
    Ok(())
}