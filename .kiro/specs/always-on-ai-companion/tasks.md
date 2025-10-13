# Implementation Plan

- [x] 1. Set up project structure and core Swift recorder foundation
  - Create Xcode project with proper targets for recorder daemon and menu bar app
  - Set up Swift Package Manager dependencies for ScreenCaptureKit and VideoToolbox
  - Implement basic project structure with separate modules for recording, encoding, and management
  - Create configuration management system using JSON files
  - _Requirements: 1.1, 1.4_

- [x] 2. Implement core ScreenCaptureKit multi-display capture
  - Create ScreenCaptureManager class that enumerates and captures all connected displays
  - Implement display detection and configuration for multiple monitors simultaneously
  - Add error handling and recovery mechanisms for capture session failures
  - Write unit tests for display enumeration and capture session management
  - _Requirements: 1.1, 1.3_

- [x] 3. Implement H.264 video encoding with VideoToolbox
  - Create VideoEncoder class using VideoToolbox for hardware-accelerated H.264 encoding
  - Configure yuv420p pixel format and compression settings for optimal performance
  - Implement 2-minute segment creation with faststart enabled for immediate playback
  - Add performance monitoring to ensure ≤8% CPU usage target
  - Write tests for encoding quality and performance metrics
  - _Requirements: 1.5, 1.6_

- [x] 4. Create crash-safe recorder daemon with auto-recovery
  - Implement RecoveryManager for automatic restart within 5 seconds of failures
  - Create robust error handling for ScreenCaptureKit session interruptions
  - Add graceful degradation to single-monitor capture when multi-monitor fails
  - Implement proper cleanup of partial segments during crashes
  - Write integration tests for crash scenarios and recovery behavior
  - _Requirements: 1.3_

- [x] 5. Implement LaunchAgent for automatic system startup
  - Create LaunchAgent plist configuration for background daemon startup
  - Implement LaunchAgentManager for installation and management of system service
  - Add proper permission handling for screen recording and accessibility access
  - Create installation script that sets up all required system permissions
  - Test automatic startup behavior across system reboots
  - _Requirements: 1.4_

- [x] 6. Create Rust-based keyframe indexer service
  - Set up Rust project with FFmpeg bindings for video processing
  - Implement KeyframeExtractor that processes 2-minute segments at 1-2 FPS
  - Create file watching system that automatically processes new video segments
  - Add error handling for corrupted or incomplete video files
  - Write unit tests for keyframe extraction accuracy and timing
  - _Requirements: 2.1, 2.5_

- [x] 7. Implement scene change detection with SSIM and pHash
  - Create SceneDetector module using image processing libraries
  - Implement SSIM calculation for structural similarity between consecutive frames
  - Add perceptual hashing (pHash) for duplicate frame detection
  - Create algorithms to identify significant scene changes and transitions
  - Write tests with known video samples to validate detection accuracy
  - _Requirements: 2.2, 2.4_

- [x] 8. Create Parquet-based frame metadata storage
  - Set up Apache Arrow/Parquet dependencies in Rust project
  - Implement ParquetWriter for efficient columnar storage of frame metadata
  - Create schema for frames.parquet with timestamps, phash, entropy, app_name, win_title
  - Add macOS API integration to collect active application and window information
  - Write tests for data integrity and query performance
  - _Requirements: 2.3, 2.5_

- [x] 9. Implement Apple Vision OCR processing engine
  - Create Swift-based VisionOCRProcessor using Apple Vision framework
  - Implement image preprocessing pipeline with binarization, deskew, and ROI cropping
  - Add ROI detection to identify text regions and UI elements efficiently
  - Create batch processing system for multiple keyframes
  - Write tests with known text images to validate OCR accuracy
  - _Requirements: 3.1, 3.3, 3.5_

- [x] 10. Add Tesseract OCR fallback system
  - Integrate Tesseract OCR library as backup when Apple Vision fails
  - Implement TesseractFallback class with same interface as Vision processor
  - Add automatic fallback logic based on confidence scores and error conditions
  - Create performance comparison tests between Vision and Tesseract
  - Write integration tests for seamless fallback behavior
  - _Requirements: 3.2, 3.3_

- [x] 11. Create OCR data storage in Parquet format
  - Implement OCR result storage using Parquet columnar format
  - Create schema for ocr.parquet with frame_id, roi, text, language, confidence
  - Add efficient indexing and querying capabilities for text search
  - Implement data compression and optimization for large text datasets
  - Write tests for storage efficiency and retrieval performance
  - _Requirements: 3.4, 3.5_

- [x] 12. Implement event detection engine for field changes
  - Create DeltaAnalyzer that compares OCR results between consecutive frames
  - Implement algorithms to detect field value changes from previous to current state
  - Add confidence scoring for change detection accuracy
  - Create event classification system for different types of field modifications
  - Write tests with synthetic data to validate change detection accuracy
  - _Requirements: 4.1, 4.5_

- [x] 13. Add navigation and interaction event detection
  - Implement window and tab change detection using system APIs
  - Create cursor tracking system for click events and movement trails
  - Add application focus change detection and logging
  - Implement event correlation between cursor actions and screen changes
  - Write integration tests for various navigation scenarios
  - _Requirements: 4.2, 4.3, 4.6_

- [x] 14. Create error and modal dialog detection
  - Implement banner recognition algorithms for error messages and modal dialogs
  - Add pattern matching for common error dialog layouts and text patterns
  - Create classification system for different types of system alerts
  - Implement confidence scoring for error detection accuracy
  - Write tests with screenshots of various error conditions
  - _Requirements: 4.4, 4.5_

- [x] 15. Implement event storage in Parquet format
  - Create events.parquet schema with type, target, value_from, value_to, confidence, evidence_frames
  - Implement efficient event storage with proper indexing and compression
  - Add evidence linking system that connects events to supporting frame IDs
  - Create query optimization for temporal and categorical event searches
  - Write tests for event storage integrity and retrieval performance
  - _Requirements: 4.5, 4.6_

- [x] 16. Create secure data storage with encryption
  - Implement libsodium/AES-GCM encryption for all Parquet and SQLite files
  - Create key management system with per-user encryption keys
  - Add secure key derivation and storage using macOS Keychain
  - Implement transparent encryption/decryption for all data operations
  - Write security tests to validate encryption strength and key management
  - _Requirements: 5.3, 7.5_

- [x] 17. Implement SQLite spans storage system
  - Create SQLite database schema for spans with span_id, kind, t_start, t_end, title, summary_md, tags
  - Implement efficient indexing for temporal and categorical span queries
  - Add transaction management for atomic span operations
  - Create migration system for schema updates and data preservation
  - Write tests for database integrity and query performance
  - _Requirements: 5.1, 5.5_

- [x] 18. Add configurable data retention policies
  - Implement automatic cleanup system for raw video data (14-30 days configurable)
  - Create retention policy engine that manages different data types independently
  - Add background cleanup processes that run efficiently without impacting performance
  - Implement safe deletion with verification and rollback capabilities
  - Write tests for retention policy enforcement and data lifecycle management
  - _Requirements: 5.4_

- [x] 19. Create activity summarization engine
  - Implement ActivitySummarizer that processes events and spans into narrative summaries
  - Add temporal context analysis to maintain workflow continuity in summaries
  - Create template system for different types of activity reports
  - Implement intelligent grouping of related events into coherent activity sessions
  - Write tests with sample event data to validate summary quality and accuracy
  - _Requirements: 6.1, 6.4_

- [x] 20. Implement multi-format report generation
  - Create ReportGenerator that produces Markdown outputs with narrative and tables
  - Add CSV and JSON export capabilities for structured data consumption
  - Implement PlaybookCreator for generating step-by-step action sequences
  - Create customizable report templates for different use cases and audiences
  - Write tests for report format consistency and data accuracy
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 21. Add evidence linking and traceability
  - Implement evidence reference system that links summaries back to source frames
  - Create bidirectional linking between events, frames, and generated reports
  - Add temporal correlation analysis to strengthen evidence connections
  - Implement confidence propagation from raw data through to final summaries
  - Write tests for evidence integrity and traceability accuracy
  - _Requirements: 6.5_

- [x] 22. Implement PII masking and privacy controls
  - Create PII detection algorithms for common sensitive data patterns
  - Implement configurable masking rules for different types of personal information
  - Add real-time PII filtering during OCR processing to prevent storage of sensitive data
  - Create privacy audit system that tracks and reports on PII handling
  - Write tests with synthetic PII data to validate masking effectiveness
  - _Requirements: 7.1_

- [x] 23. Create application and screen allowlist system
  - Implement application filtering that allows users to specify which apps to monitor
  - Add screen-specific allowlists for multi-monitor setups with different privacy needs
  - Create dynamic allowlist management that can be updated without system restart
  - Implement allowlist enforcement at the recorder level to prevent unwanted capture
  - Write tests for allowlist functionality across various application scenarios
  - _Requirements: 7.2_

- [x] 24. Add pause hotkey and immediate privacy controls
  - Implement global hotkey system that responds within 100ms to pause requests
  - Create immediate recording suspension that stops capture and processing instantly
  - Add visual indicators for recording status and privacy mode activation
  - Implement secure pause state that prevents accidental recording resumption
  - Write tests for hotkey responsiveness and privacy mode reliability
  - _Requirements: 7.3_

- [x] 25. Create plugin architecture for extensible parsing
  - Design plugin interface that allows app-specific parsing extensions
  - Implement plugin loading and management system with sandboxing for security
  - Create base plugin classes for common application types (web, productivity, terminal)
  - Add plugin configuration and lifecycle management
  - Write example plugins and tests for plugin system functionality
  - _Requirements: 8.1, 8.5_

- [x] 26. Implement browser-specific parsing plugin
  - Create specialized parsing for web applications and browser content
  - Add DOM structure analysis and web page context extraction
  - Implement URL tracking and page navigation detection
  - Create enhanced OCR processing for web-specific UI elements
  - Write tests with various web applications to validate parsing accuracy
  - _Requirements: 8.2_

- [x] 27. Add productivity tool parsing plugins
  - Implement specialized parsing for Jira ticket management and workflow tracking
  - Create Salesforce-specific parsing for CRM data and process flows
  - Add enhanced field detection for form-based productivity applications
  - Implement workflow pattern recognition for common productivity tasks
  - Write tests with sample productivity application data
  - _Requirements: 8.3_

- [x] 28. Create terminal and command-line parsing plugin
  - Implement command-line specific analysis and command history tracking
  - Add terminal session detection and command execution monitoring
  - Create enhanced parsing for terminal output and error messages
  - Implement command pattern recognition and workflow analysis
  - Write tests with various terminal scenarios and command sequences
  - _Requirements: 8.4_

- [x] 29. Implement menu bar control application
  - Create SwiftUI-based menu bar application for system control and monitoring
  - Implement real-time recording status display with performance metrics
  - Add one-click pause/resume functionality with visual feedback
  - Create settings interface for configuration management
  - Write UI tests for menu bar application functionality
  - _Requirements: 9.1, 9.2, 9.3_

- [x] 30. Add system monitoring and status display
  - Implement performance metrics collection and display (CPU, memory, disk usage)
  - Create system health monitoring with alerts for performance issues
  - Add recording statistics display (segments created, data processed, errors)
  - Implement log viewing and system diagnostics interface
  - Write tests for monitoring accuracy and alert functionality
  - _Requirements: 9.3, 9.5_

- [x] 31. Create comprehensive settings and configuration interface
  - Implement intuitive controls for retention policies and privacy settings
  - Add display selection and quality configuration options
  - Create plugin management interface for enabling/disabling extensions
  - Implement data export tools and backup/restore functionality
  - Write tests for settings persistence and configuration validation
  - _Requirements: 9.4_

- [x] 32. Implement comprehensive integration testing
  - Create end-to-end tests that validate the complete pipeline from recording to reporting
  - Add multi-monitor testing scenarios with various display configurations
  - Implement performance testing that validates CPU and memory usage requirements
  - Create failure simulation tests for crash recovery and error handling
  - Write comprehensive test suite that covers all major user workflows
  - _Requirements: 1.2, 1.3, 1.6_

- [x] 33. Add deployment and installation system
  - Create automated installer that handles all system permissions and setup
  - Implement proper code signing and notarization for macOS distribution
  - Add installation validation and system requirements checking
  - Create uninstaller that cleanly removes all system components
  - Write installation tests for various macOS versions and configurations
  - _Requirements: 7.6_

- [x] 34. Create documentation and user guides
  - Write comprehensive user documentation covering installation and configuration
  - Create developer documentation for plugin development and system extension
  - Add troubleshooting guides for common issues and performance optimization
  - Implement in-app help system with contextual guidance
  - Create video tutorials for key system features and workflows
  - _Requirements: 9.4, 9.5_