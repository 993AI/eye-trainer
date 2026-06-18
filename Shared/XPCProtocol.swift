import Foundation

// MARK: - 命令（Main App → XPC Service）

enum XPCCommand: String, Codable {
    case start         = "start"
    case stop          = "stop"
    case setBrightness = "setBrightness"
    case ping          = "ping"
}

struct XPCStartRequest: Codable {
    let mode: TrainingMode
    let curve: CurveType
    let minBrightness: Double
    let maxBrightness: Double
    let cycleSeconds: Double
    let durationMinutes: Int?
    let stepLevels: Int
}

struct XPCSetBrightnessRequest: Codable {
    let value: Double   // 0.0 ~ 1.0
}

struct XPCRequest: Codable {
    let id: UUID
    let command: XPCCommand
    let startRequest: XPCStartRequest?
    let setBrightnessRequest: XPCSetBrightnessRequest?
    
    static func start(_ req: XPCStartRequest) -> XPCRequest {
        XPCRequest(id: UUID(), command: .start, startRequest: req, setBrightnessRequest: nil)
    }
    
    static func stop() -> XPCRequest {
        XPCRequest(id: UUID(), command: .stop, startRequest: nil, setBrightnessRequest: nil)
    }
    
    static func setBrightness(_ value: Double) -> XPCRequest {
        XPCRequest(id: UUID(), command: .setBrightness, startRequest: nil, setBrightnessRequest: XPCSetBrightnessRequest(value: value))
    }
    
    static func ping() -> XPCRequest {
        XPCRequest(id: UUID(), command: .ping, startRequest: nil, setBrightnessRequest: nil)
    }
}

// MARK: - 事件（XPC Service → Main App）

enum XPCEventType: String, Codable {
    case tick      = "tick"
    case completed = "completed"
    case error     = "error"
}

struct XPCTickEvent: Codable {
    let currentBrightness: Double   // 当前亮度值 0.0~1.0
    let remainingSeconds: Int       // 剩余训练秒数
}

struct XPCErrorEvent: Codable {
    let code: Int
    let message: String
}

struct XPCEvent: Codable {
    let id: UUID           // 对应原始请求 ID
    let type: XPCEventType
    let tick: XPCTickEvent?
    let error: XPCErrorEvent?
    
    static func tick(brightness: Double, remaining: Int) -> XPCEvent {
        XPCEvent(id: UUID(), type: .tick, tick: XPCTickEvent(currentBrightness: brightness, remainingSeconds: remaining), error: nil)
    }
    
    static func completed() -> XPCEvent {
        XPCEvent(id: UUID(), type: .completed, tick: nil, error: nil)
    }
    
    static func error(code: Int, message: String) -> XPCEvent {
        XPCEvent(id: UUID(), type: .error, tick: nil, error: XPCErrorEvent(code: code, message: message))
    }
}

// MARK: - NSXPCConnection 协议

/// 主 App 暴露给 XPC Service 的接口（用于回传事件）
@objc protocol XPCClientProtocol {
    func receiveEvent(_ data: Data)
}

/// XPC Service 暴露给主 App 的接口（用于发送命令）
@objc protocol XPCServiceProtocol {
    func sendCommand(_ data: Data, reply: @escaping (Data?) -> Void)
}
