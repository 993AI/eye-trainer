import Foundation

/// XPC 双向通信桥：封装 NSXPCConnection 的创建、命令发送、事件接收
/// 支持自动重连和降级模式
@Observable
final class XPCBridge: NSObject, XPCClientProtocol {
    
    private var connection: NSXPCConnection?
    private var serviceProxy: XPCServiceProtocol?
    
    private(set) var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    
    /// 事件回调
    var onEvent: ((XPCEvent) -> Void)?
    
    // MARK: - Connection Management
    
    func connect() {
        connection?.invalidate()
        
        let conn = NSXPCConnection(
            serviceName: "com.wenquan.BrightnessXPC"
        )
        
        conn.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: XPCClientProtocol.self)
        conn.exportedObject = self
        
        conn.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.attemptReconnect()
            }
        }
        
        conn.interruptionHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        conn.resume()
        connection = conn
        serviceProxy = conn.remoteObjectProxyWithErrorHandler { [weak self] error in
            print("[XPCBridge] Connection error: \(error)")
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        } as? XPCServiceProtocol
        
        // 验证连接
        serviceProxy?.sendCommand(
            encodeRequest(.ping()) ?? Data(),
            reply: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.reconnectAttempts = 0
                }
            }
        )
    }
    
    func disconnect() {
        connection?.invalidate()
        connection = nil
        serviceProxy = nil
        isConnected = false
    }
    
    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else { return }
        
        reconnectAttempts += 1
        let delay: Double = [0.5, 1.0, 2.0][reconnectAttempts - 1]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isConnected else { return }
            self.connect()
        }
    }
    
    // MARK: - Sending Commands
    
    func startTraining(_ req: XPCStartRequest) {
        send(.start(req))
    }
    
    func stopTraining() {
        send(.stop())
    }
    
    func setBrightness(_ value: Double) {
        send(.setBrightness(value))
    }
    
    private func send(_ request: XPCRequest) {
        guard let data = encodeRequest(request) else { return }
        
        if isConnected, let proxy = serviceProxy {
            proxy.sendCommand(data) { [weak self] responseData in
                guard let data = responseData,
                      let event = try? JSONDecoder().decode(XPCEvent.self, from: data) else { return }
                DispatchQueue.main.async {
                    self?.onEvent?(event)
                }
            }
        } else {
            // 未连接，走降级——由 ViewModel 处理
        }
    }
    
    // MARK: - XPCClientProtocol
    
    func receiveEvent(_ data: Data) {
        guard let event = try? JSONDecoder().decode(XPCEvent.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
    
    // MARK: - Helpers
    
    private func encodeRequest(_ request: XPCRequest) -> Data? {
        try? JSONEncoder().encode(request)
    }
}
