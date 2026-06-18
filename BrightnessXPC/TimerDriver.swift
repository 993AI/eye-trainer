import Foundation

/// 高精度定时驱动，60fps 刷新，基于 mach_absolute_time
final class TimerDriver {
    
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.wenquan.eye-trainer.timer", qos: .userInteractive)
    
    private var startTime: UInt64 = 0
    private var durationSeconds: Double = 0
    private var cycleSeconds: Double = 0
    private var isRunning = false
    
    /// 每帧回调：(当前周期时间, 已过总秒数, 剩余秒数) -> Void
    var onTick: ((Double, Double, Int) -> Void)?
    
    /// 训练完成回调
    var onCompleted: (() -> Void)?
    
    // MARK: - Control
    
    func start(cycleSeconds: Double, durationSeconds: Double? = nil) {
        stop()
        
        self.cycleSeconds = cycleSeconds
        self.durationSeconds = durationSeconds ?? Double.infinity
        self.startTime = mach_absolute_time()
        self.isRunning = true
        
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0, leeway: .microseconds(1000))
        
        timer.setEventHandler { [weak self] in
            self?.fireTick()
        }
        
        timer.resume()
        self.timer = timer
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }
    
    // MARK: - Private
    
    private func fireTick() {
        guard isRunning else { return }
        
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        
        let elapsed = Double(mach_absolute_time() - startTime) * Double(timebase.numer) / Double(timebase.denom) / 1e9
        
        // 检查是否训练完成
        if elapsed >= durationSeconds {
            stop()
            DispatchQueue.main.async { [weak self] in
                self?.onCompleted?()
            }
            return
        }
        
        let remaining: Int
        if durationSeconds.isFinite {
            remaining = max(0, Int(durationSeconds - elapsed))
        } else {
            // -1 表示无限时，避免将 Double.infinity 转成 Int 导致运行时错误。
            remaining = -1
        }
        let cycleT = elapsed.truncatingRemainder(dividingBy: cycleSeconds)
        
        DispatchQueue.main.async { [weak self] in
            self?.onTick?(cycleT, elapsed, remaining)
        }
    }
}
