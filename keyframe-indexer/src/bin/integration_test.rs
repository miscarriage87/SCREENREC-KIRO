use keyframe_indexer::integration_test::run_integration_test;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt::init();
    
    // Run the integration test
    run_integration_test().await?;
    
    Ok(())
}