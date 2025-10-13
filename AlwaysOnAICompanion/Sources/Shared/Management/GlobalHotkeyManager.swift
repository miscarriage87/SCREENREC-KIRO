import Foundation
import Carbon
import Cocoa

/// Protocol for hotkey event handling
public protocol GlobalHotkeyDelegate: AnyObject {
    func hotkeyPressed(_ hotkey: GlobalHotkey)
}

/// Represents a global hotkey configuration
public struct GlobalHotkey {
    public let id: String
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let description: String
    
    public init(id: String, keyCode: UInt32, modifiers: UInt32, description: String) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.description = description
    }
    
    /// Creates a hotkey from a string representation (e.g., "cmd+shift+p")
    public static func from(string: String, id: String, description: String) -> GlobalHotkey? {
        let components = string.lowercased().split(separator: "+").map(String.init)
        
        var modifiers: UInt32 = 0
        var keyCode: UInt32 = 0
        
        for component in components {
            switch component {
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "alt", "option":
                modifiers |= UInt32(optionKey)
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            default:
                // Try to parse as key
                if let code = keyCodeFromString(component) {
                    keyCode = code
                }
            }
        }
        
        guard keyCode != 0 else { return nil }
        
        return GlobalHotkey(id: id, keyCode: keyCode, modifiers: modifiers, description: description)
    }
    
    private static func keyCodeFromString(_ key: String) -> UInt32? {
        switch key.lowercased() {
        case "a": return 0
        case "b": return 11
        case "c": return 8
        case "d": return 2
        case "e": return 14
        case "f": return 3
        case "g": return 5
        case "h": return 4
        case "i": return 34
        case "j": return 38
        case "k": return 40
        case "l": return 37
        case "m": return 46
        case "n": return 45
        case "o": return 31
        case "p": return 35
        case "q": return 12
        case "r": return 15
        case "s": return 1
        case "t": return 17
        case "u": return 32
        case "v": return 9
        case "w": return 13
        case "x": return 7
        case "y": return 16
        case "z": return 6
        case "0": return 29
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25
        case "space": return 49
        case "return", "enter": return 36
        case "escape", "esc": return 53
        case "tab": return 48
        case "delete", "backspace": return 51
        case "f1": return 122
        case "f2": return 120
        case "f3": return 99
        case "f4": return 118
        case "f5": return 96
        case "f6": return 97
        case "f7": return 98
        case "f8": return 100
        case "f9": return 101
        case "f10": return 109
        case "f11": return 103
        case "f12": return 111
        default: return nil
        }
    }
}

/// Manages global hotkeys for the application
public class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()
    
    private var registeredHotkeys: [String: EventHotKeyRef] = [:]
    private var hotkeyConfigs: [String: GlobalHotkey] = [:]
    private var eventHandler: EventHandlerRef?
    private let logger = Logger.shared
    
    public weak var delegate: GlobalHotkeyDelegate?
    
    private init() {
        setupEventHandler()
    }
    
    deinit {
        unregisterAllHotkeys()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
    
    /// Registers a global hotkey
    public func registerHotkey(_ hotkey: GlobalHotkey) -> Bool {
        // Unregister existing hotkey with same ID if it exists
        unregisterHotkey(id: hotkey.id)
        
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: OSType(hotkey.id.hashValue), id: UInt32(hotkey.id.hashValue))
        
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr, let ref = hotkeyRef {
            registeredHotkeys[hotkey.id] = ref
            hotkeyConfigs[hotkey.id] = hotkey
            logger.info("Registered global hotkey: \(hotkey.description) (ID: \(hotkey.id))")
            return true
        } else {
            logger.error("Failed to register global hotkey: \(hotkey.description) (Status: \(status))")
            return false
        }
    }
    
    /// Unregisters a specific hotkey
    public func unregisterHotkey(id: String) {
        if let hotkeyRef = registeredHotkeys[id] {
            UnregisterEventHotKey(hotkeyRef)
            registeredHotkeys.removeValue(forKey: id)
            hotkeyConfigs.removeValue(forKey: id)
            logger.info("Unregistered global hotkey with ID: \(id)")
        }
    }
    
    /// Unregisters all hotkeys
    public func unregisterAllHotkeys() {
        for (id, hotkeyRef) in registeredHotkeys {
            UnregisterEventHotKey(hotkeyRef)
            logger.info("Unregistered global hotkey with ID: \(id)")
        }
        registeredHotkeys.removeAll()
        hotkeyConfigs.removeAll()
    }
    
    /// Gets all registered hotkeys
    public var registeredHotkeyConfigs: [GlobalHotkey] {
        return Array(hotkeyConfigs.values)
    }
    
    /// Checks if a hotkey is registered
    public func isHotkeyRegistered(id: String) -> Bool {
        return registeredHotkeys[id] != nil
    }
    
    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let callback: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotkeyEvent(theEvent)
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if status != noErr {
            logger.error("Failed to install hotkey event handler (Status: \(status))")
        } else {
            logger.info("Global hotkey event handler installed successfully")
        }
    }
    
    private func handleHotkeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }
        
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )
        
        guard status == noErr else {
            logger.error("Failed to get hotkey ID from event (Status: \(status))")
            return OSStatus(eventNotHandledErr)
        }
        
        // Find the hotkey configuration by matching the ID
        for (id, config) in hotkeyConfigs {
            if id.hashValue == hotkeyID.signature && id.hashValue == Int(hotkeyID.id) {
                logger.info("Hotkey pressed: \(config.description)")
                
                // Notify delegate on main queue with 100ms response time requirement
                DispatchQueue.main.async {
                    self.delegate?.hotkeyPressed(config)
                }
                
                return noErr
            }
        }
        
        logger.warning("Received hotkey event for unknown hotkey ID: \(hotkeyID.id)")
        return OSStatus(eventNotHandledErr)
    }
}

// MARK: - Hotkey String Parsing Extensions
extension GlobalHotkey {
    /// Common hotkey presets
    public static let pauseRecording = GlobalHotkey(
        id: "pause_recording",
        keyCode: 35, // P key
        modifiers: UInt32(cmdKey | shiftKey),
        description: "Pause/Resume Recording (⌘⇧P)"
    )
    
    public static let togglePrivacyMode = GlobalHotkey(
        id: "toggle_privacy",
        keyCode: 35, // P key
        modifiers: UInt32(cmdKey | optionKey),
        description: "Toggle Privacy Mode (⌘⌥P)"
    )
    
    public static let emergencyStop = GlobalHotkey(
        id: "emergency_stop",
        keyCode: 53, // Escape key
        modifiers: UInt32(cmdKey | shiftKey),
        description: "Emergency Stop (⌘⇧⎋)"
    )
}