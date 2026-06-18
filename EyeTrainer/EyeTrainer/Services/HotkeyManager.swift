import AppKit
import Carbon

/// 全局热键管理器（基于 Carbon Event）
final class HotkeyManager {
    
    struct HotkeyAction: Hashable {
        let id: String
        let keyCode: UInt16
        let modifiers: UInt32
    }
    
    private var registeredHotkeys: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    
    var onHotkeyPressed: ((String) -> Void)?
    
    // MARK: - API
    
    func register(id: String, keyCode: UInt16, modifiers: UInt32) -> Bool {
        // 先检查是否冲突
        if let existing = registeredHotkeys.first(where: { $0.key.keyCode == keyCode && $0.key.modifiers == modifiers }) {
            print("[HotkeyManager] Hotkey '\(id)' conflicts with '\(existing.key.id)'")
            return false
        }
        
        // 如果已注册同 ID，先注销
        unregister(id: id)
        
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: fourCharCode("WQET"), id: UInt32(id.hashValue & 0xFFFF))
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        guard status == noErr, let ref = hotkeyRef else {
            print("[HotkeyManager] Failed to register hotkey '\(id)' (error: \(status))")
            return false
        }
        
        let action = HotkeyAction(id: id, keyCode: keyCode, modifiers: modifiers)
        registeredHotkeys[action] = ref
        
        // 确保事件处理器已安装
        installEventHandlerIfNeeded()
        
        return true
    }
    
    func unregister(id: String) {
        guard let entry = registeredHotkeys.first(where: { $0.key.id == id }) else { return }
        let ref = entry.value
        
        UnregisterEventHotKey(ref)
        registeredHotkeys.removeValue(forKey: entry.key)
    }
    
    func unregisterAll() {
        for (_, ref) in registeredHotkeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotkeys.removeAll()
    }
    
    // MARK: - Event Handler
    
    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return -1 }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotkeyEvent(event)
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
        
        if status != noErr {
            print("[HotkeyManager] Failed to install event handler: \(status)")
        }
    }
    
    private func handleHotkeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return -1 }
        
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )
        
        guard status == noErr else { return status }
        
        // 根据 hotkeyID 找到对应的 action
        if let entry = registeredHotkeys.first(where: { UInt32($0.key.id.hashValue & 0xFFFF) == hotkeyID.id }) {
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyPressed?(entry.key.id)
            }
        }
        
        return noErr
    }
    
    deinit {
        unregisterAll()
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
        }
    }
    
    // MARK: - Helpers
    
    private func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for char in string.utf8.prefix(4) {
            result = (result << 8) | OSType(char)
        }
        return result
    }
}
