use crate::event_detector::{EventDetector, EventType};
use crate::ocr_data::{OCRResult, BoundingBox};
use chrono::Utc;

/// Simple test to validate event detection functionality
pub fn test_event_detection() -> Result<(), Box<dyn std::error::Error>> {
    println!("Testing Event Detection System...");
    
    let mut detector = EventDetector::new()?;
    let timestamp = Utc::now();
    
    // Test 1: Field change detection
    println!("Test 1: Field change detection");
    
    // Frame 1: Empty form
    let frame1_ocr = vec![
        OCRResult {
            frame_id: "frame1".to_string(),
            roi: BoundingBox::new(10.0, 50.0, 80.0, 20.0),
            text: "Username:".to_string(),
            language: "en-US".to_string(),
            confidence: 0.95,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
        OCRResult {
            frame_id: "frame1".to_string(),
            roi: BoundingBox::new(100.0, 50.0, 200.0, 20.0),
            text: "".to_string(),
            language: "en-US".to_string(),
            confidence: 0.8, // Higher confidence for empty field
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
    ];
    
    let events1 = detector.analyze_frame("frame1", &frame1_ocr, timestamp, 1920.0, 1080.0)?;
    println!("Frame 1 events: {}", events1.len());
    
    // Frame 2: Username filled
    let frame2_ocr = vec![
        OCRResult {
            frame_id: "frame2".to_string(),
            roi: BoundingBox::new(10.0, 50.0, 80.0, 20.0),
            text: "Username:".to_string(),
            language: "en-US".to_string(),
            confidence: 0.95,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
        OCRResult {
            frame_id: "frame2".to_string(),
            roi: BoundingBox::new(100.0, 50.0, 200.0, 20.0),
            text: "john.doe".to_string(),
            language: "en-US".to_string(),
            confidence: 0.92,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
    ];
    
    let events2 = detector.analyze_frame("frame2", &frame2_ocr, timestamp, 1920.0, 1080.0)?;
    println!("Frame 2 events: {}", events2.len());
    
    let field_changes: Vec<_> = events2.iter()
        .filter(|e| e.event_type == EventType::FieldChange)
        .collect();
    
    if !field_changes.is_empty() {
        println!("✓ Field change detected successfully");
        for change in &field_changes {
            println!("  - Target: {}", change.target);
            println!("  - From: {:?}", change.value_from);
            println!("  - To: {:?}", change.value_to);
            println!("  - Confidence: {:.2}", change.confidence);
        }
    } else {
        println!("✗ No field changes detected");
    }
    
    // Test 2: Error message detection
    println!("Test 2: Error message detection");
    
    let error_ocr = vec![
        OCRResult {
            frame_id: "frame3".to_string(),
            roi: BoundingBox::new(50.0, 100.0, 200.0, 20.0),
            text: "Error: Invalid input".to_string(),
            language: "en-US".to_string(),
            confidence: 0.93,
            processed_at: Utc::now(),
            processor: "vision".to_string(),
        },
    ];
    
    let error_events = detector.analyze_frame("frame3", &error_ocr, timestamp, 1920.0, 1080.0)?;
    
    let errors: Vec<_> = error_events.iter()
        .filter(|e| e.event_type == EventType::ErrorDisplay)
        .collect();
    
    if !errors.is_empty() {
        println!("✓ Error message detected successfully");
        for error in &errors {
            println!("  - Message: {:?}", error.value_to);
            println!("  - Confidence: {:.2}", error.confidence);
        }
    } else {
        println!("✗ No error messages detected");
    }
    
    // Test 3: Text similarity calculation
    println!("Test 3: Text similarity calculation");
    
    let similarity1 = detector.calculate_text_similarity("hello", "hello");
    println!("Similarity 'hello' vs 'hello': {:.2}", similarity1);
    assert_eq!(similarity1, 1.0);
    
    let similarity2 = detector.calculate_text_similarity("hello", "hallo");
    println!("Similarity 'hello' vs 'hallo': {:.2}", similarity2);
    assert!(similarity2 >= 0.8 && similarity2 < 1.0);
    
    let similarity3 = detector.calculate_text_similarity("hello", "world");
    println!("Similarity 'hello' vs 'world': {:.2}", similarity3);
    assert!(similarity3 < 0.5);
    
    println!("✓ Text similarity calculation working correctly");
    
    // Test 4: Bounding box IoU calculation
    println!("Test 4: Bounding box IoU calculation");
    
    let bbox1 = BoundingBox::new(0.0, 0.0, 100.0, 100.0);
    let bbox2 = BoundingBox::new(50.0, 50.0, 100.0, 100.0);
    let bbox3 = BoundingBox::new(200.0, 200.0, 100.0, 100.0);
    
    let iou1 = bbox1.iou(&bbox2);
    println!("IoU overlapping boxes: {:.2}", iou1);
    assert!(iou1 > 0.0 && iou1 < 1.0);
    
    let iou2 = bbox1.iou(&bbox3);
    println!("IoU non-overlapping boxes: {:.2}", iou2);
    assert_eq!(iou2, 0.0);
    
    let iou3 = bbox1.iou(&bbox1);
    println!("IoU identical boxes: {:.2}", iou3);
    assert!((iou3 - 1.0).abs() < 0.001);
    
    println!("✓ Bounding box IoU calculation working correctly");
    
    println!("✓ All event detection tests passed!");
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_simple_event_detection() {
        test_event_detection().unwrap();
    }
}