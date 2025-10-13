use keyframe_indexer::csv_test;

#[tokio::main]
async fn main() {
    match csv_test::run_all_tests().await {
        Ok(()) => {
            println!("All tests completed successfully!");
            std::process::exit(0);
        }
        Err(e) => {
            eprintln!("Test failed: {}", e);
            std::process::exit(1);
        }
    }
}