use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

/// OCR result data structure matching the design specification
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OCRResult {
    /// Reference to the frame that was processed
    pub frame_id: String,
    /// Region of Interest where text was detected
    pub roi: BoundingBox,
    /// Extracted text content
    pub text: String,
    /// Detected language code (e.g., "en-US", "zh-Hans")
    pub language: String,
    /// OCR confidence score (0.0 to 1.0)
    pub confidence: f32,
    /// Timestamp when OCR was performed
    pub processed_at: DateTime<Utc>,
    /// OCR processor used (e.g., "vision", "tesseract")
    pub processor: String,
}

/// Bounding box coordinates for text regions
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BoundingBox {
    /// X coordinate of top-left corner
    pub x: f32,
    /// Y coordinate of top-left corner  
    pub y: f32,
    /// Width of the bounding box
    pub width: f32,
    /// Height of the bounding box
    pub height: f32,
}

impl BoundingBox {
    pub fn new(x: f32, y: f32, width: f32, height: f32) -> Self {
        Self { x, y, width, height }
    }
    
    /// Calculate the area of the bounding box
    pub fn area(&self) -> f32 {
        self.width * self.height
    }
    
    /// Check if this bounding box intersects with another
    pub fn intersects(&self, other: &BoundingBox) -> bool {
        !(self.x + self.width < other.x ||
          other.x + other.width < self.x ||
          self.y + self.height < other.y ||
          other.y + other.height < self.y)
    }
    
    /// Calculate intersection over union (IoU) with another bounding box
    pub fn iou(&self, other: &BoundingBox) -> f32 {
        if !self.intersects(other) {
            return 0.0;
        }
        
        let intersection_x = self.x.max(other.x);
        let intersection_y = self.y.max(other.y);
        let intersection_width = (self.x + self.width).min(other.x + other.width) - intersection_x;
        let intersection_height = (self.y + self.height).min(other.y + other.height) - intersection_y;
        
        let intersection_area = intersection_width * intersection_height;
        let union_area = self.area() + other.area() - intersection_area;
        
        if union_area > 0.0 {
            intersection_area / union_area
        } else {
            0.0
        }
    }
}

/// Batch of OCR results for efficient processing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OCRBatch {
    pub results: Vec<OCRResult>,
    pub batch_id: String,
    pub created_at: DateTime<Utc>,
}

impl OCRBatch {
    pub fn new(results: Vec<OCRResult>) -> Self {
        Self {
            results,
            batch_id: uuid::Uuid::new_v4().to_string(),
            created_at: Utc::now(),
        }
    }
    
    /// Get total number of text regions in this batch
    pub fn text_region_count(&self) -> usize {
        self.results.len()
    }
    
    /// Get average confidence score for this batch
    pub fn average_confidence(&self) -> f32 {
        if self.results.is_empty() {
            return 0.0;
        }
        
        let total_confidence: f32 = self.results.iter().map(|r| r.confidence).sum();
        total_confidence / self.results.len() as f32
    }
    
    /// Filter results by minimum confidence threshold
    pub fn filter_by_confidence(&self, min_confidence: f32) -> Vec<&OCRResult> {
        self.results.iter()
            .filter(|r| r.confidence >= min_confidence)
            .collect()
    }
    
    /// Group results by language
    pub fn group_by_language(&self) -> std::collections::HashMap<String, Vec<&OCRResult>> {
        let mut groups = std::collections::HashMap::new();
        
        for result in &self.results {
            groups.entry(result.language.clone())
                .or_insert_with(Vec::new)
                .push(result);
        }
        
        groups
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_bounding_box_area() {
        let bbox = BoundingBox::new(10.0, 20.0, 100.0, 50.0);
        assert_eq!(bbox.area(), 5000.0);
    }
    
    #[test]
    fn test_bounding_box_intersection() {
        let bbox1 = BoundingBox::new(0.0, 0.0, 100.0, 100.0);
        let bbox2 = BoundingBox::new(50.0, 50.0, 100.0, 100.0);
        let bbox3 = BoundingBox::new(200.0, 200.0, 100.0, 100.0);
        
        assert!(bbox1.intersects(&bbox2));
        assert!(!bbox1.intersects(&bbox3));
    }
    
    #[test]
    fn test_bounding_box_iou() {
        let bbox1 = BoundingBox::new(0.0, 0.0, 100.0, 100.0);
        let bbox2 = BoundingBox::new(50.0, 50.0, 100.0, 100.0);
        
        let iou = bbox1.iou(&bbox2);
        assert!(iou > 0.0 && iou < 1.0);
        
        // Same bounding box should have IoU of 1.0
        let iou_same = bbox1.iou(&bbox1);
        assert!((iou_same - 1.0).abs() < 0.001);
    }
    
    #[test]
    fn test_ocr_batch_creation() {
        let results = vec![
            OCRResult {
                frame_id: "frame_1".to_string(),
                roi: BoundingBox::new(10.0, 10.0, 100.0, 20.0),
                text: "Hello World".to_string(),
                language: "en-US".to_string(),
                confidence: 0.95,
                processed_at: Utc::now(),
                processor: "vision".to_string(),
            },
            OCRResult {
                frame_id: "frame_1".to_string(),
                roi: BoundingBox::new(10.0, 40.0, 80.0, 20.0),
                text: "Test Text".to_string(),
                language: "en-US".to_string(),
                confidence: 0.87,
                processed_at: Utc::now(),
                processor: "vision".to_string(),
            },
        ];
        
        let batch = OCRBatch::new(results);
        assert_eq!(batch.text_region_count(), 2);
        assert!((batch.average_confidence() - 0.91).abs() < 0.01);
    }
    
    #[test]
    fn test_confidence_filtering() {
        let results = vec![
            OCRResult {
                frame_id: "frame_1".to_string(),
                roi: BoundingBox::new(10.0, 10.0, 100.0, 20.0),
                text: "High confidence".to_string(),
                language: "en-US".to_string(),
                confidence: 0.95,
                processed_at: Utc::now(),
                processor: "vision".to_string(),
            },
            OCRResult {
                frame_id: "frame_1".to_string(),
                roi: BoundingBox::new(10.0, 40.0, 80.0, 20.0),
                text: "Low confidence".to_string(),
                language: "en-US".to_string(),
                confidence: 0.45,
                processed_at: Utc::now(),
                processor: "tesseract".to_string(),
            },
        ];
        
        let batch = OCRBatch::new(results);
        let high_confidence = batch.filter_by_confidence(0.8);
        assert_eq!(high_confidence.len(), 1);
        assert_eq!(high_confidence[0].text, "High confidence");
    }
}