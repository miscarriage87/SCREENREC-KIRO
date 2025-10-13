import Foundation
import Combine

/// Privacy state enumeration
public enum PrivacyState {
    case recording      // Normal recording mode
    case paused        // Recording paused by user
    case privacyMode   // Privacy mode active (recording but not processing sensitive data)
    case emergencyStop // Emergency stop - all recording and processing stopped
    
    public var description: String {
        switch self {
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .privacyMode:
            return "Privacy Mode"
        case .emergencyStop:
            return "Emergency Stop"
        }
    }
    
    public var isRecordingActive: Bool {
        switch self {
        case .recording, .privacyMode:
            return true
        case .paused, .emergencyStop:
            return false
        }
    }
    
    public var allowsDataProcessing: Bool {
        switch self {
        case .recording:
            return true
        case .privacyMode, .paused, .emergencyStop:
            return false
        }
    }
}

/// Protocol for privacy state change notifications
public protocol PrivacyControllerDelegate: AnyObject {
    func privacyStateDidChange(_ newState: PrivacyState, previousState: PrivacyState)
    func privacyModeWillActivate()
    func privacyModeDidDeactivate()
    func emergencyStopActivated()
}

/// Manages privacy controls and secure pause functionality
public class PrivacyController: ObservableObject {
    public static let shared = PrivacyController()
    
    @Published public private(set) var currentState: PrivacyState = .paused
    @Published public private(set) var isSecurePauseActive: Bool = false
    @Published public private(set) var pauseStartTime: Date?
    @Published public private(set) var privacyModeStartTime: Date?
    
    public weak var delegate: PrivacyControllerDelegate?
    
    private let logger = Logger.shared
    private let stateQueue = DispatchQueue(label: "com.alwaysonai.privacy.state", qos: .userInitiated)
    private var securePauseTimer: Timer?
    private var stateChangeSubject = PassthroughSubject<(PrivacyState, PrivacyState), Never>()
    
    // Configuration
    private let maxPauseDuration: TimeInterval = 3600 // 1 hour max pause
    private let securePauseRequiresConfirmation = true
    
    private init() {
        setupStateChangePublisher()
    }
    
    deinit {
        securePauseTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    /// Toggles between recording and paused states
    public func toggleRecording() {
        stateQueue.async {
            let previousState = self.currentState
            
            switch self.currentState {
            case .recording:
                self.pauseRecording()
            case .paused:
                self.resumeRecording()
            case .privacyMode:
                // In privacy mode, toggle to paused
                self.pauseRecording()
            case .emergencyStop:
                // Cannot toggle from emergency stop - requires explicit resume
                self.logger.warning("Cannot toggle recording from emergency stop state")
                return
            }
            
            self.notifyStateChange(from: previousState, to: self.currentState)
        }
    }
    
    /// Pauses recording immediately
    public func pauseRecording() {
        stateQueue.async {
            let previousState = self.currentState
            
            guard previousState != .emergencyStop else {
                self.logger.warning("Cannot pause from emergency stop state")
                return
            }
            
            self.logger.info("Pausing recording (previous state: \(previousState.description))")
            
            DispatchQueue.main.async {
                self.currentState = .paused
                self.pauseStartTime = Date()
                self.isSecurePauseActive = true
            }
            
            self.startSecurePauseTimer()
            self.notifyStateChange(from: previousState, to: .paused)
        }
    }
    
    /// Resumes recording from paused state
    public func resumeRecording() {
        stateQueue.async {
            let previousState = self.currentState
            
            guard previousState == .paused else {
                self.logger.warning("Cannot resume recording from state: \(previousState.description)")
                return
            }
            
            self.logger.info("Resuming recording")
            
            DispatchQueue.main.async {
                self.currentState = .recording
                self.pauseStartTime = nil
                self.isSecurePauseActive = false
            }
            
            self.stopSecurePauseTimer()
            self.notifyStateChange(from: previousState, to: .recording)
        }
    }
    
    /// Toggles privacy mode
    public func togglePrivacyMode() {
        stateQueue.async {
            let previousState = self.currentState
            
            switch self.currentState {
            case .recording:
                self.activatePrivacyMode()
            case .privacyMode:
                self.deactivatePrivacyMode()
            case .paused:
                // From paused, go to privacy mode
                self.activatePrivacyMode()
            case .emergencyStop:
                self.logger.warning("Cannot toggle privacy mode from emergency stop state")
                return
            }
            
            self.notifyStateChange(from: previousState, to: self.currentState)
        }
    }
    
    /// Activates privacy mode (recording continues but data processing is limited)
    public func activatePrivacyMode() {
        stateQueue.async {
            let previousState = self.currentState
            
            guard previousState != .emergencyStop else {
                self.logger.warning("Cannot activate privacy mode from emergency stop state")
                return
            }
            
            self.logger.info("Activating privacy mode")
            
            // Notify delegate before state change
            DispatchQueue.main.async {
                self.delegate?.privacyModeWillActivate()
            }
            
            DispatchQueue.main.async {
                self.currentState = .privacyMode
                self.privacyModeStartTime = Date()
                self.pauseStartTime = nil
                self.isSecurePauseActive = false
            }
            
            self.stopSecurePauseTimer()
            self.notifyStateChange(from: previousState, to: .privacyMode)
        }
    }
    
    /// Deactivates privacy mode and returns to normal recording
    public func deactivatePrivacyMode() {
        stateQueue.async {
            let previousState = self.currentState
            
            guard previousState == .privacyMode else {
                self.logger.warning("Cannot deactivate privacy mode from state: \(previousState.description)")
                return
            }
            
            self.logger.info("Deactivating privacy mode")
            
            DispatchQueue.main.async {
                self.currentState = .recording
                self.privacyModeStartTime = nil
            }
            
            // Notify delegate after state change
            DispatchQueue.main.async {
                self.delegate?.privacyModeDidDeactivate()
            }
            
            self.notifyStateChange(from: previousState, to: .recording)
        }
    }
    
    /// Activates emergency stop (stops all recording and processing)
    public func activateEmergencyStop() {
        stateQueue.async {
            let previousState = self.currentState
            
            self.logger.warning("Emergency stop activated")
            
            DispatchQueue.main.async {
                self.currentState = .emergencyStop
                self.pauseStartTime = Date()
                self.privacyModeStartTime = nil
                self.isSecurePauseActive = true
            }
            
            self.stopSecurePauseTimer()
            
            // Notify delegate immediately
            DispatchQueue.main.async {
                self.delegate?.emergencyStopActivated()
            }
            
            self.notifyStateChange(from: previousState, to: .emergencyStop)
        }
    }
    
    /// Resets emergency stop and returns to paused state
    public func resetEmergencyStop() {
        resumeFromEmergencyStop()
    }
    
    /// Resumes from emergency stop (requires explicit action)
    public func resumeFromEmergencyStop() {
        stateQueue.async {
            let previousState = self.currentState
            
            guard previousState == .emergencyStop else {
                self.logger.warning("Cannot resume from emergency stop - not in emergency stop state")
                return
            }
            
            self.logger.info("Resuming from emergency stop")
            
            DispatchQueue.main.async {
                self.currentState = .paused // Go to paused state first for safety
                self.pauseStartTime = Date()
                self.isSecurePauseActive = true
            }
            
            self.startSecurePauseTimer()
            self.notifyStateChange(from: previousState, to: .paused)
        }
    }
    
    /// Checks if recording should be active based on current state
    public var shouldRecord: Bool {
        return currentState.isRecordingActive
    }
    
    /// Checks if data processing should be active based on current state
    public var shouldProcessData: Bool {
        return currentState.allowsDataProcessing
    }
    
    /// Gets the duration of current pause (if paused)
    public var pauseDuration: TimeInterval? {
        guard let startTime = pauseStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Gets the duration of current privacy mode session (if active)
    public var privacyModeDuration: TimeInterval? {
        guard let startTime = privacyModeStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Private Methods
    
    private func setupStateChangePublisher() {
        stateChangeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (previousState, newState) in
                self?.delegate?.privacyStateDidChange(newState, previousState: previousState)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func notifyStateChange(from previousState: PrivacyState, to newState: PrivacyState) {
        logger.info("Privacy state changed: \(previousState.description) → \(newState.description)")
        stateChangeSubject.send((previousState, newState))
    }
    
    private func startSecurePauseTimer() {
        stopSecurePauseTimer()
        
        securePauseTimer = Timer.scheduledTimer(withTimeInterval: maxPauseDuration, repeats: false) { [weak self] _ in
            self?.handleSecurePauseTimeout()
        }
    }
    
    private func stopSecurePauseTimer() {
        securePauseTimer?.invalidate()
        securePauseTimer = nil
    }
    
    private func handleSecurePauseTimeout() {
        logger.warning("Secure pause timeout reached, automatically resuming recording")
        
        stateQueue.async {
            if self.currentState == .paused {
                self.resumeRecording()
            }
        }
    }
}

// MARK: - State Validation
extension PrivacyController {
    /// Validates that the current state is consistent
    public func validateState() -> Bool {
        switch currentState {
        case .recording:
            return pauseStartTime == nil && privacyModeStartTime == nil && !isSecurePauseActive
        case .paused:
            return pauseStartTime != nil && privacyModeStartTime == nil && isSecurePauseActive
        case .privacyMode:
            return privacyModeStartTime != nil && !isSecurePauseActive
        case .emergencyStop:
            return pauseStartTime != nil && isSecurePauseActive
        }
    }
    
    /// Resets to a safe state if validation fails
    public func resetToSafeState() {
        logger.warning("Resetting privacy controller to safe state")
        
        stateQueue.async {
            let previousState = self.currentState
            
            DispatchQueue.main.async {
                self.currentState = .paused
                self.pauseStartTime = Date()
                self.privacyModeStartTime = nil
                self.isSecurePauseActive = true
            }
            
            self.startSecurePauseTimer()
            self.notifyStateChange(from: previousState, to: .paused)
        }
    }
}

// MARK: - Configuration
extension PrivacyController {
    /// Configuration for privacy controller behavior
    public struct Configuration {
        public let maxPauseDuration: TimeInterval
        public let requireConfirmationForResume: Bool
        public let allowEmergencyStop: Bool
        public let autoResumeAfterTimeout: Bool
        
        public static let `default` = Configuration(
            maxPauseDuration: 3600, // 1 hour
            requireConfirmationForResume: true,
            allowEmergencyStop: true,
            autoResumeAfterTimeout: true
        )
    }
}