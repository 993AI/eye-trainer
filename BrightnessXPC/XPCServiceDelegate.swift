import Foundation

/// XPC Service 委托：接收命令，驱动引擎，回传事件
final class XPCServiceDelegate: NSObject, NSXPCListenerDelegate, XPCServiceProtocol {
    
    private let timerDriver = TimerDriver()
    
    // 当前训练状态
    private var currentCurve: CurveType = .sine
    private var currentMinBrightness: Double = 0.15
    private var currentMaxBrightness: Double = 0.90
    private var currentCycleSeconds: Double = 3.0
    private var currentStepLevels: Int = 4
    
    // 回调到主 App 的连接
    private var clientConnection: NSXPCConnection?
    private var clientProxy: XPCClientProtocol?
    private let minimumTickInterval: Double = 1.0 / 30.0
    private var lastSentTickElapsed: Double?
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        newConnection.exportedObject = self
        
        newConnection.remoteObjectInterface = NSXPCInterface(with: XPCClientProtocol.self)
        clientConnection = newConnection
        clientProxy = newConnection.remoteObjectProxyWithErrorHandler { error in
            print("[BrightnessXPC] Failed to send event: \(error)")
        } as? XPCClientProtocol
        
        newConnection.invalidationHandler = { [weak self] in
            guard let self, self.clientConnection === newConnection else { return }
            self.timerDriver.stop()
            self.clientConnection = nil
            self.clientProxy = nil
        }

        newConnection.interruptionHandler = { [weak self] in
            guard let self, self.clientConnection === newConnection else { return }
            // 中断期间由主 App 的降级计时器接管，避免两个计时器同时运行。
            self.timerDriver.stop()
            self.clientConnection = nil
            self.clientProxy = nil
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

        case .pause:
            handlePause(reply: reply)
            
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
        lastSentTickElapsed = nil
        
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
            
            let shouldSend = self.lastSentTickElapsed.map {
                elapsed - $0 >= self.minimumTickInterval
            } ?? true
            guard shouldSend else { return }

            self.lastSentTickElapsed = elapsed
            self.sendEventToClient(.tick(brightness: brightness, elapsed: elapsed, remaining: remaining))
        }
        
        timerDriver.onCompleted = { [weak self] in
            self?.sendEventToClient(.completed())
        }
        
        timerDriver.start(
            cycleSeconds: req.cycleSeconds,
            durationSeconds: duration,
            initialElapsedSeconds: req.initialElapsedSeconds
        )
        
        // 立即回传初始亮度
        let initialCycleTime = req.initialElapsedSeconds.truncatingRemainder(dividingBy: req.cycleSeconds)
        let initBrightness = CurveEngine.calculate(
            curve: currentCurve,
            t: initialCycleTime,
            minBrightness: currentMinBrightness,
            maxBrightness: currentMaxBrightness,
            cycleSeconds: currentCycleSeconds,
            stepLevels: currentStepLevels
        )
        lastSentTickElapsed = req.initialElapsedSeconds
        reply(encodeEvent(.tick(
            brightness: initBrightness,
            elapsed: req.initialElapsedSeconds,
            remaining: duration.map { max(0, Int($0) - Int(req.initialElapsedSeconds)) } ?? -1
        )))
    }
    
    private func handleStop(reply: @escaping (Data?) -> Void) {
        timerDriver.stop()
        lastSentTickElapsed = nil
        reply(encodeEvent(.completed()))
    }

    private func handlePause(reply: @escaping (Data?) -> Void) {
        timerDriver.stop()
        lastSentTickElapsed = nil
        reply(nil)
    }
    
    private func handleSetBrightness(_ value: Double, reply: @escaping (Data?) -> Void) {
        timerDriver.stop()  // 手动模式下停止定时器
        lastSentTickElapsed = nil
        reply(encodeEvent(.tick(brightness: value, elapsed: 0, remaining: 0)))
    }
    
    // MARK: - Helpers
    
    private func sendEventToClient(_ event: XPCEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        clientProxy?.receiveEvent(data)
    }
    
    private func encodeEvent(_ event: XPCEvent) -> Data? {
        try? JSONEncoder().encode(event)
    }
}
