import Foundation

/// XPC 双向通信桥：封装 NSXPCConnection 的创建、命令发送、事件接收
/// 支持自动重连和降级模式
@Observable
final class XPCBridge: NSObject, XPCClientProtocol {
    
    private var connection: NSXPCConnection?
    private var serviceProxy: XPCServiceProtocol?
    
    private(set) var isConnected = false
    private var reconnectAttempts = 0
    private var reconnectWorkItem: DispatchWorkItem?
    
    /// 事件回调
    var onEvent: ((XPCEvent) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    
    // MARK: - Connection Management
    
    func connect() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        // 主动替换连接时不要让旧连接的回调再次触发重连。
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        
        let conn = NSXPCConnection(
            serviceName: "com.wenquan.BrightnessXPC"
        )
        
        conn.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: XPCClientProtocol.self)
        conn.exportedObject = self
        
        conn.invalidationHandler = { [weak self, weak conn] in
            DispatchQueue.main.async {
                guard let self, self.connection === conn else { return }
                self.updateConnectionState(false)
                self.attemptReconnect()
            }
        }
        
        conn.interruptionHandler = { [weak self, weak conn] in
            DispatchQueue.main.async {
                guard let self, self.connection === conn else { return }
                self.updateConnectionState(false)
                self.attemptReconnect()
            }
        }
        
        conn.resume()
        connection = conn
        serviceProxy = conn.remoteObjectProxyWithErrorHandler { [weak self] error in
            print("[XPCBridge] Connection error: \(error)")
            DispatchQueue.main.async {
                self?.updateConnectionState(false)
                self?.attemptReconnect()
            }
        } as? XPCServiceProtocol
        
        // 验证连接
        serviceProxy?.sendCommand(
            encodeRequest(.ping()) ?? Data(),
            reply: { [weak self, weak conn] _ in
                DispatchQueue.main.async {
                    guard let self, self.connection === conn else { return }
                    self.updateConnectionState(true)
                    self.reconnectAttempts = 0
                }
            }
        )
    }
    
    func disconnect() {
        connection?.invalidate()
        connection = nil
        serviceProxy = nil
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        updateConnectionState(false)
    }
    
    private func attemptReconnect() {
        guard reconnectWorkItem == nil, !isConnected else { return }
        
        reconnectAttempts += 1
        let delay = min(0.5 * pow(2.0, Double(reconnectAttempts - 1)), 30.0)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            guard !self.isConnected else { return }
            self.connect()
        }
        reconnectWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func updateConnectionState(_ connected: Bool) {
        guard isConnected != connected else { return }
        isConnected = connected
        onConnectionChange?(connected)
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
