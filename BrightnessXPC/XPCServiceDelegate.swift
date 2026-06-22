import Foundation

/// XPC Service 委托：接收命令，驱动引擎，回传事件
final class XPCServiceDelegate: NSObject, NSXPCListenerDelegate, XPCServiceProtocol {
    
    private let brightnessController = BrightnessController.shared
    private let timerDriver = TimerDriver()
    
    // 当前训练状态
    private var currentCurve: CurveType = .sine
    private var currentMinBrightness: Double = 0.15
    private var currentMaxBrightness: Double = 0.90
    private var currentCycleSeconds: Double = 3.0
    private var currentStepLevels: Int = 4
    
    // 回调到主 App 的连接
    private var clientConnection: NSXPCConnection?
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        newConnection.exportedObject = self
        
        newConnection.remoteObjectInterface = NSXPCInterface(with: XPCClientProtocol.self)
        clientConnection = newConnection
        
        newConnection.invalidationHandler = { [weak self] in
            guard let self, self.clientConnection === newConnection else { return }
            self.timerDriver.stop()
            self.clientConnection = nil
        }
        
        newConnection.resume()
        return true
    }
    
    // MARK: - XPCServiceProtocol
    
    func sendCommand(_ data: Data, reply: @escaping (Data?) -> Void) {
        guard let request = try? JSONDecoder().decode(XPCRequest.self, from: data) else {
            let errorEvent = XPCEvent.error(code: 400, message: "Invalid request format")
            reply(try? JSONEncoder().encode(errorEvent))
            return
        }
        
        switch request.command {
        case .start:
            guard let startReq = request.startRequest else {
                reply(encodeEvent(.error(code: 400, message: "Missing startRequest")))
                return
            }
            handleStart(startReq, reply: reply)
            
        case .stop:
            handleStop(reply: reply)
            
        case .setBrightness:
            guard let setReq = request.setBrightnessRequest else {
                reply(encodeEvent(.error(code: 400, message: "Missing setBrightnessRequest")))
                return
            }
            handleSetBrightness(setReq.value, reply: reply)
            
        case .ping:
            reply(encodeEvent(.completed()))
        }
    }
    
    // MARK: - Command Handlers
    
    private func handleStart(_ req: XPCStartRequest, reply: @escaping (Data?) -> Void) {
        currentCurve = req.curve
        currentMinBrightness = req.minBrightness
        currentMaxBrightness = req.maxBrightness
        currentCycleSeconds = req.cycleSeconds
        currentStepLevels = req.stepLevels
        
        let duration: Double? = req.durationMinutes.map { Double($0) * 60.0 }
        
        timerDriver.onTick = { [weak self] cycleT, elapsed, remaining in
            guard let self = self else { return }
            
            let brightness = CurveEngine.calculate(
                curve: self.currentCurve,
                t: cycleT,
                minBrightness: self.currentMinBrightness,
                maxBrightness: self.currentMaxBrightness,
                cycleSeconds: self.currentCycleSeconds,
                stepLevels: self.currentStepLevels
            )
            
            self.brightnessController.setBrightness(brightness)
            self.sendEventToClient(.tick(brightness: brightness, remaining: remaining))
        }
        
        timerDriver.onCompleted = { [weak self] in
            self?.sendEventToClient(.completed())
        }
        
        timerDriver.start(cycleSeconds: req.cycleSeconds, durationSeconds: duration)
        
        // 立即回传初始亮度
        let initBrightness = CurveEngine.calculate(
            curve: currentCurve,
            t: 0,
            minBrightness: currentMinBrightness,
            maxBrightness: currentMaxBrightness,
            cycleSeconds: currentCycleSeconds,
            stepLevels: currentStepLevels
        )
        brightnessController.setBrightness(initBrightness)
        reply(encodeEvent(.tick(brightness: initBrightness, remaining: duration.map { Int($0) } ?? -1)))
    }
    
    private func handleStop(reply: @escaping (Data?) -> Void) {
        timerDriver.stop()
        reply(encodeEvent(.completed()))
    }
    
    private func handleSetBrightness(_ value: Double, reply: @escaping (Data?) -> Void) {
        timerDriver.stop()  // 手动模式下停止定时器
        brightnessController.setBrightness(value)
        reply(encodeEvent(.tick(brightness: value, remaining: 0)))
    }
    
    // MARK: - Helpers
    
    private func sendEventToClient(_ event: XPCEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        clientConnection?.remoteObjectProxyWithErrorHandler { error in
            print("[BrightnessXPC] Failed to send event: \(error)")
        }
        
        if let proxy = clientConnection?.remoteObjectProxy as? XPCClientProtocol {
            proxy.receiveEvent(data)
        }
    }
    
    private func encodeEvent(_ event: XPCEvent) -> Data? {
        try? JSONEncoder().encode(event)
    }
}
