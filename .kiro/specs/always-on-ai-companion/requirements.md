# Requirements Document

## Introduction

The Always-On AI Companion is a comprehensive system that continuously records, analyzes, summarizes, and archives all user activity across multiple monitors and applications on macOS. The system provides an AI companion with complete context of user activities through stable background recording, intelligent content analysis, and structured knowledge storage. The solution replaces unstable ffmpeg-based approaches with native macOS ScreenCaptureKit technology and provides robust data processing pipelines for real-time insights.

## Requirements

### Requirement 1

**User Story:** As a user, I want a stable background recording system that captures all my screen activity across multiple monitors, so that I have a reliable foundation for AI companion knowledge without system crashes or performance degradation.

#### Acceptance Criteria

1. WHEN the system starts THEN the recorder daemon SHALL capture all connected displays simultaneously using macOS ScreenCaptureKit
2. WHEN recording multiple displays THEN the system SHALL maintain ≤8% CPU usage for 3x 1440p@30fps capture
3. WHEN the system encounters errors THEN the recorder SHALL automatically recover and resume recording within 5 seconds
4. WHEN the system starts THEN the recorder SHALL automatically launch via LaunchAgent on macOS boot
5. WHEN recording THEN the system SHALL generate H.264 yuv420p encoded segments of 2-minute duration with faststart enabled
6. WHEN storage I/O occurs THEN the system SHALL maintain ≤20MB/s sustained write performance

### Requirement 2

**User Story:** As a user, I want intelligent frame indexing and scene detection, so that the system can efficiently identify and catalog significant visual changes without storing redundant information.

#### Acceptance Criteria

1. WHEN video segments are created THEN the indexer SHALL extract keyframes at 1-2 FPS intervals
2. WHEN analyzing frames THEN the system SHALL detect scene changes using SSIM and pHash algorithms
3. WHEN storing frame metadata THEN the system SHALL use Parquet format with timestamps, phash, entropy, app_name, and win_title
4. WHEN processing frames THEN the system SHALL calculate perceptual hashes for duplicate detection
5. WHEN frame analysis completes THEN the system SHALL store results in frames.parquet with monitor_id and segment_id references

### Requirement 3

**User Story:** As a user, I want accurate text extraction from screen content, so that the AI companion can understand textual information from all applications and interfaces.

#### Acceptance Criteria

1. WHEN processing keyframes THEN the system SHALL use Apple Vision OCR as the primary text extraction method
2. WHEN Apple Vision OCR fails THEN the system SHALL fallback to Tesseract OCR processing
3. WHEN performing OCR THEN the system SHALL apply preprocessing including binarization, deskew, and ROI cropping
4. WHEN text is extracted THEN the system SHALL store results in ocr.parquet with frame_id, roi, text, language, and confidence
5. WHEN OCR processing completes THEN the system SHALL achieve field-level granularity for detecting value changes

### Requirement 4

**User Story:** As a user, I want intelligent event detection that identifies meaningful interactions and changes, so that the AI companion understands my workflow patterns and decision points.

#### Acceptance Criteria

1. WHEN analyzing OCR deltas THEN the system SHALL detect field value changes from previous to current state
2. WHEN monitoring system events THEN the system SHALL capture window and tab navigation changes
3. WHEN processing cursor data THEN the system SHALL track click events and cursor movement trails
4. WHEN analyzing screen content THEN the system SHALL detect error messages and modal dialogs via banner recognition
5. WHEN events are detected THEN the system SHALL store them in events.parquet with type, target, value_from, value_to, confidence, and evidence_frames
6. WHEN event processing occurs THEN the system SHALL maintain evidence linking through OCR deltas, pHash, frame IDs, and cursor vectors

### Requirement 5

**User Story:** As a user, I want secure and efficient data storage with configurable retention policies, so that my sensitive information is protected while maintaining system performance.

#### Acceptance Criteria

1. WHEN storing structured data THEN the system SHALL use SQLite for events and spans storage
2. WHEN storing frame and OCR data THEN the system SHALL use Parquet format for efficient columnar storage
3. WHEN handling sensitive data THEN the system SHALL implement end-to-end encryption using libsodium/AES-GCM
4. WHEN managing data retention THEN the system SHALL retain raw data for 14-30 days and summaries permanently
5. WHEN storing spans THEN the system SHALL include span_id, kind, t_start, t_end, title, summary_md, and tags in spans.sqlite

### Requirement 6

**User Story:** As a user, I want comprehensive activity summaries and reports, so that I can review my work patterns and share actionable insights with colleagues.

#### Acceptance Criteria

1. WHEN generating reports THEN the system SHALL create Markdown outputs with narrative text and structured tables
2. WHEN exporting data THEN the system SHALL provide CSV and JSON formats for structured consumption
3. WHEN creating summaries THEN the system SHALL generate action and flow spans that serve as playbooks for colleagues
4. WHEN summarizing activities THEN the system SHALL maintain temporal context and workflow continuity
5. WHEN reports are generated THEN the system SHALL include evidence references linking back to source frames and events

### Requirement 7

**User Story:** As a user, I want comprehensive privacy controls and security features, so that I can safely use the system while protecting sensitive information and maintaining control over my data.

#### Acceptance Criteria

1. WHEN processing sensitive content THEN the system SHALL implement PII masking capabilities
2. WHEN configuring privacy THEN the system SHALL provide application and screen allowlist functionality
3. WHEN needing immediate privacy THEN the system SHALL respond to a pause hotkey within 100ms
4. WHEN managing data THEN the system SHALL enforce configurable retention policies
5. WHEN operating THEN the system SHALL maintain local-first architecture with optional cloud sync
6. WHEN handling data THEN the system SHALL ensure compatibility with macOS 14+ on both Intel and Apple Silicon

### Requirement 8

**User Story:** As a user, I want extensible architecture for application-specific parsing, so that the system can provide enhanced understanding of specialized tools and workflows.

#### Acceptance Criteria

1. WHEN integrating with applications THEN the system SHALL support plugin architecture for app-specific parsing
2. WHEN processing browser content THEN the system SHALL provide enhanced parsing for web applications
3. WHEN analyzing productivity tools THEN the system SHALL support specialized parsing for Jira and Salesforce
4. WHEN monitoring terminal sessions THEN the system SHALL provide command-line specific analysis capabilities
5. WHEN extending functionality THEN the system SHALL maintain plugin compatibility across system updates

### Requirement 9

**User Story:** As a user, I want a user-friendly control interface, so that I can easily manage the system, monitor its status, and adjust settings without technical complexity.

#### Acceptance Criteria

1. WHEN accessing controls THEN the system SHALL provide a menu bar application interface
2. WHEN managing privacy THEN the system SHALL offer one-click pause and private mode activation
3. WHEN monitoring system status THEN the interface SHALL display recording status and performance metrics
4. WHEN configuring settings THEN the system SHALL provide intuitive controls for retention policies and privacy settings
5. WHEN system issues occur THEN the interface SHALL display clear status indicators and error messages