import SwiftUI
import Combine
import AppKit
import CoreGraphics

/// 应用唯一状态中心
@MainActor
@Observable
final class AppViewModel {
    static let shared = AppViewModel()

    private static let globalHotkeysEnabledKey = "globalHotkeysEnabled"
    
    // MARK: - Published State
    
    var mode: TrainingMode = .auto
    var isRunning: Bool = false
    var currentBrightness: Double = 0.5
    var remainingSeconds: Int = 0
    var selectedCurve: CurveType = .sine
    var isXPCConnected: Bool = false

    var globalHotkeysEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(globalHotkeysEnabled, forKey: Self.globalHotkeysEnabledKey)

            if globalHotkeysEnabled {
                setupHotkeys()
            } else {
                hotkeyManager.unregisterAll()
            }
        }
    }
    
    var settings: TrainingSettings {
        didSet {
            saveSettings()
            scheduleRunningTrainingUpdate()
        }
    }
    
    // 手动模式下的滑块值
    var manualBrightness: Double = 0.5
    
    // MARK: - Services
    
    private let xpcBridge = XPCBridge()
    private let hotkeyManager = HotkeyManager()
    private let screenDimmingController = ScreenDimmingController()
    
    // 降级模式下的本地引擎（当 XPC 不可用时）
    private var fallbackTimer: TimerDriver?
    private var fallbackCurveEngine = CurveEngine.self
    private var settingsUpdateWorkItem: DispatchWorkItem?
    private var displayLifecycleObservers: [NSObjectProtocol] = []
    private var displayIsSleeping = false
    private var trainingElapsedSeconds = 0.0
    private var fallbackGeneration = 0
    private var wakeGeneration = 0
    
    // MARK: - Init
    
    init() {
        self.settings = Self.loadSettings()
        self.globalHotkeysEnabled = UserDefaults.standard.object(forKey: Self.globalHotkeysEnabledKey) as? Bool ?? true
        self.selectedCurve = settings.defaultCurve
        self.mode = settings.defaultMode
        
        setupDisplayLifecycleObservers()
        setupXPC()
        setupHotkeys()
    }

    private func setupDisplayLifecycleObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let sleepNotifications: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ]
        let wakeNotifications: [Notification.Name] = [
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]

        for name in sleepNotifications {
            displayLifecycleObservers.append(
                workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.handleDisplaySleep()
                    }
                }
            )
        }

        for name in wakeNotifications {
            displayLifecycleObservers.append(
                workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.handleDisplayWake()
                    }
                }
            )
        }
    }

    private func handleDisplaySleep() {
        guard !displayIsSleeping else { return }
        displayIsSleeping = true
        wakeGeneration += 1
        stopFallbackTimer()
        if mode == .auto, xpcBridge.isConnected {
            xpcBridge.pauseTraining()
        }
        screenDimmingController.restore()
    }

    private func handleDisplayWake() {
        // sessionDidBecomeActive 可能在 screensDidWake 之后重复到达；无论当前标记如何，
        // 都要把显示器后端重新绑定到解锁后的实际屏幕列表。
        displayIsSleeping = false
        wakeGeneration += 1
        let generation = wakeGeneration
        screenDimmingController.invalidateDisplayConfiguration()

        guard isRunning else { return }

        // WindowServer 在唤醒后需要一点时间重新枚举显示器；先恢复一次，
        // 再做一次无可见变化的布局检查，只有发现布局改变时才会再次写屏幕。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self,
                  generation == self.wakeGeneration,
                  !self.displayIsSleeping,
                  self.isRunning else { return }
            self.reapplyBrightnessAfterWake()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self] in
            guard let self,
                  generation == self.wakeGeneration,
                  !self.displayIsSleeping,
                  self.isRunning else { return }
            self.screenDimmingController.rebindIfDisplayConfigurationChanged()
        }
    }

    private func reapplyBrightnessAfterWake() {
        // 先恢复当前画面亮度，再重新对齐训练计时器；XPC 初始 tick 若相同会被输出节流合并。
        screenDimmingController.setBrightness(
            mode == .manual ? manualBrightness : currentBrightness,
            force: true
        )

        if mode == .auto {
            if xpcBridge.isConnected {
                xpcBridge.startTraining(XPCStartRequest(
                    mode: .auto,
                    curve: selectedCurve,
                    minBrightness: settings.minBrightness,
                    maxBrightness: settings.maxBrightness,
                    cycleSeconds: settings.cycleSeconds,
                    durationMinutes: settings.durationMinutes,
                    stepLevels: settings.stepLevels,
                    initialElapsedSeconds: trainingElapsedSeconds
                ))
            } else if fallbackTimer == nil {
                startFallbackAuto(initialElapsedSeconds: trainingElapsedSeconds)
            }
        }
    }
    
    // MARK: - XPC Setup
    
    private func setupXPC() {
        xpcBridge.onEvent = { [weak self] event in
            self?.handleXPCEvent(event)
        }
        xpcBridge.onConnectionChange = { [weak self] connected in
            self?.handleXPCConnectionChange(connected)
        }
        xpcBridge.connect()
    }

    private func handleXPCConnectionChange(_ connected: Bool) {
        guard isRunning, mode == .auto else { return }

        if displayIsSleeping {
            if !connected {
                stopFallbackTimer()
            }
            return
        }

        if connected {
            // 重连成功后交还给 XPC，并停止本地降级计时器。
            stopFallbackTimer()
            xpcBridge.startTraining(XPCStartRequest(
                mode: .auto,
                curve: selectedCurve,
                minBrightness: settings.minBrightness,
                maxBrightness: settings.maxBrightness,
                cycleSeconds: settings.cycleSeconds,
                durationMinutes: settings.durationMinutes,
                stepLevels: settings.stepLevels,
                initialElapsedSeconds: trainingElapsedSeconds
            ))
        } else if fallbackTimer == nil {
            // XPC 中断时立即由主进程继续训练，UI 与亮度都不会假运行。
            startFallbackAuto(initialElapsedSeconds: trainingElapsedSeconds)
        }
    }
    
    private func handleXPCEvent(_ event: XPCEvent) {
        switch event.type {
        case .tick:
            if let tick = event.tick {
                currentBrightness = tick.currentBrightness
                trainingElapsedSeconds = tick.elapsedSeconds
                if !displayIsSleeping {
                    // 显示器可能在锁屏期间被拔掉，屏幕变化通知也可能延迟到第一条 tick 之后。
                    // setBrightness 会检测布局签名并在需要时强制重建后端。
                    screenDimmingController.setBrightness(tick.currentBrightness)
                }
                if tick.remainingSeconds >= 0 {
                    remainingSeconds = tick.remainingSeconds
                }
            }
        case .completed:
            stopTraining()
        case .error:
            if let error = event.error {
                print("[AppViewModel] XPC Error: \(error.message)")
            }
        }
    }
    
    // MARK: - Hotkey Setup
    
    private func setupHotkeys() {
        guard globalHotkeysEnabled else { return }

        hotkeyManager.unregisterAll()
        hotkeyManager.onHotkeyPressed = { [weak self] id in
            guard let self = self else { return }
            switch id {
            case "start":
                self.startTraining()
            case "stop":
                self.stopTraining()
            case "up":
                self.adjustBrightness(up: true)
            case "down":
                self.adjustBrightness(up: false)
            default:
                break
            }
        }
        
        _ = hotkeyManager.register(
            id: "start",
            keyCode: settings.startHotkey.keyCode,
            modifiers: settings.startHotkey.modifiers
        )
        _ = hotkeyManager.register(
            id: "stop",
            keyCode: settings.stopHotkey.keyCode,
            modifiers: settings.stopHotkey.modifiers
        )
        _ = hotkeyManager.register(
            id: "up",
            keyCode: settings.upHotkey.keyCode,
            modifiers: settings.upHotkey.modifiers
        )
        _ = hotkeyManager.register(
            id: "down",
            keyCode: settings.downHotkey.keyCode,
            modifiers: settings.downHotkey.modifiers
        )
    }
    
    func reregisterHotkeys() {
        hotkeyManager.unregisterAll()
        if globalHotkeysEnabled {
            setupHotkeys()
        }
    }

    private func scheduleRunningTrainingUpdate() {
        guard isRunning else { return }

        settingsUpdateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.applySettingsToRunningTraining()
        }
        settingsUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func applySettingsToRunningTraining() {
        guard isRunning else { return }

        mode = settings.defaultMode
        selectedCurve = settings.defaultCurve

        if mode == .auto {
            if xpcBridge.isConnected {
                xpcBridge.startTraining(XPCStartRequest(
                    mode: .auto,
                    curve: selectedCurve,
                    minBrightness: settings.minBrightness,
                    maxBrightness: settings.maxBrightness,
                    cycleSeconds: settings.cycleSeconds,
                    durationMinutes: settings.durationMinutes,
                    stepLevels: settings.stepLevels,
                    initialElapsedSeconds: trainingElapsedSeconds
                ))
            } else {
                stopFallbackTimer()
                startFallbackAuto(initialElapsedSeconds: trainingElapsedSeconds)
            }
        } else {
            stopFallbackTimer()
            if xpcBridge.isConnected {
                // 复用 setBrightness 命令停止 XPC 自动计时器；实际调光统一由主 App 完成。
                xpcBridge.setBrightness(manualBrightness)
            }
            if !displayIsSleeping {
                screenDimmingController.setBrightness(manualBrightness, force: true)
            }
        }
    }
    
    // MARK: - Training Control
    
    func startTraining() {
        guard !isRunning else { return }
        
        mode = settings.defaultMode
        selectedCurve = settings.defaultCurve
        isRunning = true
        trainingElapsedSeconds = 0
        
        if mode == .auto {
            if xpcBridge.isConnected {
                // XPC 模式
                let req = XPCStartRequest(
                    mode: .auto,
                    curve: selectedCurve,
                    minBrightness: settings.minBrightness,
                    maxBrightness: settings.maxBrightness,
                    cycleSeconds: settings.cycleSeconds,
                    durationMinutes: settings.durationMinutes,
                    stepLevels: settings.stepLevels,
                    initialElapsedSeconds: 0
                )
                xpcBridge.startTraining(req)
            } else {
                // 降级：本地直驱
                startFallbackAuto(initialElapsedSeconds: 0)
            }
        } else {
            // 手动模式
            currentBrightness = manualBrightness
            if xpcBridge.isConnected {
                xpcBridge.setBrightness(manualBrightness)
            }
            if !displayIsSleeping {
                screenDimmingController.setBrightness(manualBrightness, force: true)
            }
        }
    }
    
    func stopTraining() {
        guard isRunning else { return }

        let wasXPCConnected = xpcBridge.isConnected
        isRunning = false
        remainingSeconds = 0
        trainingElapsedSeconds = 0
        stopFallbackTimer()
        if wasXPCConnected {
            xpcBridge.stopTraining()
        }
        screenDimmingController.restore()
    }
    
    func setManualBrightness(_ value: Double) {
        manualBrightness = min(max(value, 0.05), 1.0)
        guard isRunning, mode == .manual else { return }
        
        currentBrightness = manualBrightness
        if !displayIsSleeping {
            screenDimmingController.setBrightness(manualBrightness, force: true)
        }
    }
    
    func adjustBrightness(up: Bool) {
        let step: Double = 0.1
        let newValue = up
            ? min(manualBrightness + step, 1.0)
            : max(manualBrightness - step, 0.05)
        setManualBrightness(newValue)
    }
    
    func skipToNextCycle() {
        // 跳到下一个半周期终点
        // 简单实现：跳到极值（如果当前 < 中点，跳到 max；否则跳到 min）
        let midpoint = (settings.minBrightness + settings.maxBrightness) / 2.0
        let target = currentBrightness < midpoint ? settings.maxBrightness : settings.minBrightness
        
        if !displayIsSleeping {
            screenDimmingController.setBrightness(target, force: true)
        }
        currentBrightness = target
    }
    
    // MARK: - Fallback (降级直驱)
    
    private func startFallbackAuto(initialElapsedSeconds: Double = 0) {
        stopFallbackTimer()
        let generation = fallbackGeneration
        let driver = TimerDriver()
        let duration: Double? = settings.durationMinutes.map { Double($0) * 60.0 }
        
        driver.onTick = { [weak self] cycleT, elapsed, remaining in
            guard let self,
                  generation == self.fallbackGeneration,
                  !self.displayIsSleeping else { return }
            let brightness = CurveEngine.calculate(
                curve: self.selectedCurve,
                t: cycleT,
                minBrightness: self.settings.minBrightness,
                maxBrightness: self.settings.maxBrightness,
                cycleSeconds: self.settings.cycleSeconds,
                stepLevels: self.settings.stepLevels
            )
            self.screenDimmingController.setBrightness(brightness)
            self.currentBrightness = brightness
            self.trainingElapsedSeconds = elapsed
            self.remainingSeconds = remaining
        }
        
        driver.onCompleted = { [weak self] in
            guard let self, generation == self.fallbackGeneration else { return }
            self.stopTraining()
        }
        
        driver.start(
            cycleSeconds: settings.cycleSeconds,
            durationSeconds: duration,
            initialElapsedSeconds: initialElapsedSeconds
        )
        fallbackTimer = driver
    }

    private func stopFallbackTimer() {
        fallbackGeneration += 1
        fallbackTimer?.stop()
        fallbackTimer = nil
    }
    
    // MARK: - Settings Persistence
    
    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "trainingSettings")
    }
    
    private static func loadSettings() -> TrainingSettings {
        guard let data = UserDefaults.standard.data(forKey: "trainingSettings"),
              let settings = try? JSONDecoder().decode(TrainingSettings.self, from: data) else {
            return TrainingSettings()
        }
        return settings
    }

}

/// 外接显示器不暴露 Apple 背光接口时，以鼠标穿透的黑色覆盖层模拟亮度。
/// 这不会修改显示器 OSD 中的硬件亮度，但能可靠提供训练所需的明暗变化。
@MainActor
final class ScreenDimmingController {
    private enum DimmingBackend: Equatable {
        case gamma
        case overlay
    }

    private struct GammaFormula {
        let redMin: CGGammaValue
        let redMax: CGGammaValue
        let redGamma: CGGammaValue
        let greenMin: CGGammaValue
        let greenMax: CGGammaValue
        let greenGamma: CGGammaValue
        let blueMin: CGGammaValue
        let blueMax: CGGammaValue
        let blueGamma: CGGammaValue
    }

    private var overlayWindows: [NSWindow] = []
    private var originalGammaByDisplay: [CGDirectDisplayID: GammaFormula] = [:]
    private var screenConfigurationSignature = ""
    private var backend: DimmingBackend?
    private var backendConfigurationSignature = ""
    private var gammaFailureSignature: String?
    private var screenChangeObserver: NSObjectProtocol?
    private var activeSpaceChangeObserver: NSObjectProtocol?
    private var currentBrightness = 1.0
    private var isActive = false
    private var overlayNeedsFront = false
    private var lastAppliedBrightness: Double?
    private var lastAppliedAt: TimeInterval = 0
    private var outputUpdateScheduled = false
    private var outputGeneration = 0

    // 训练曲线仍由 TimerDriver 以 60 FPS 计算，但实际显示输出限制为 20 FPS，
    // 避免每一帧重写 Gamma LUT 或触发 WindowServer 窗口合成。
    private let minimumOutputInterval: TimeInterval = 1.0 / 20.0
    private let minimumBrightnessDelta = 0.004

    init() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshForScreenChange()
            }
        }

        activeSpaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshForActiveSpaceChange()
            }
        }
    }

    func setBrightness(_ value: Double, force: Bool = false) {
        currentBrightness = min(max(value, 0.05), 1.0)
        isActive = true

        let displaySignature = configurationSignature(for: NSScreen.screens)
        let configurationChanged = backendConfigurationSignature != displaySignature
        if configurationChanged,
           backend != nil || !overlayWindows.isEmpty || !originalGammaByDisplay.isEmpty {
            invalidateDisplayConfiguration()
        }

        if force || configurationChanged {
            cancelPendingOutput()
            applyBrightnessNow(bringOverlayToFront: true)
        } else {
            requestBrightnessOutput()
        }
    }

    func restore() {
        invalidateDisplayConfiguration()
        currentBrightness = 1.0
        isActive = false
    }

    func invalidateDisplayConfiguration() {
        cancelPendingOutput()
        restoreGammaBrightness()
        hideOverlayWindows()
        screenConfigurationSignature = ""
        backend = nil
        backendConfigurationSignature = ""
        gammaFailureSignature = nil
        overlayNeedsFront = false
        lastAppliedBrightness = nil
        lastAppliedAt = 0
    }

    func rebindIfDisplayConfigurationChanged() {
        guard isActive else { return }

        let displaySignature = configurationSignature(for: NSScreen.screens)
        guard backendConfigurationSignature != displaySignature else { return }
        setBrightness(currentBrightness, force: true)
    }

    private func requestBrightnessOutput() {
        guard isActive else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let changeIsLargeEnough = lastAppliedBrightness == nil
            || abs(currentBrightness - (lastAppliedBrightness ?? currentBrightness)) >= minimumBrightnessDelta
        guard changeIsLargeEnough else { return }

        let timeSinceLastOutput = now - lastAppliedAt
        if lastAppliedBrightness == nil || timeSinceLastOutput >= minimumOutputInterval {
            applyBrightnessNow()
            return
        }

        guard !outputUpdateScheduled else { return }
        outputUpdateScheduled = true
        let generation = outputGeneration
        let delay = max(0, minimumOutputInterval - timeSinceLastOutput)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.outputGeneration == generation else { return }
            self.outputUpdateScheduled = false
            self.requestBrightnessOutput()
        }
    }

    private func cancelPendingOutput() {
        outputGeneration += 1
        outputUpdateScheduled = false
    }

    private func applyBrightnessNow(bringOverlayToFront: Bool = false) {
        guard isActive else { return }

        ensureBackend()
        switch backend {
        case .gamma:
            guard applyGammaBrightness() else {
                // Gamma 在当前布局下失效后只切换一次到遮罩，避免每一帧重复探测。
                gammaFailureSignature = backendConfigurationSignature
                restoreGammaBrightness()
                backend = .overlay
                rebuildWindowsIfNeeded()
                applyCurrentBrightness(bringToFront: true)
                break
            }
        case .overlay:
            rebuildWindowsIfNeeded()
            applyCurrentBrightness(bringToFront: bringOverlayToFront)
        case nil:
            break
        }

        lastAppliedBrightness = currentBrightness
        lastAppliedAt = ProcessInfo.processInfo.systemUptime
    }

    private func ensureBackend() {
        let displaySignature = configurationSignature(for: NSScreen.screens)
        guard backend == nil || backendConfigurationSignature != displaySignature else { return }

        if backend == .gamma {
            restoreGammaBrightness()
        }
        hideOverlayWindows()
        screenConfigurationSignature = ""
        backendConfigurationSignature = displaySignature

        if gammaFailureSignature == displaySignature {
            backend = .overlay
        } else {
            // 先固定选择 Gamma；真正写入时若失败，再切换到遮罩并缓存失败布局。
            // 这样初始化时不会连续写两次 Gamma LUT。
            backend = .gamma
        }

        if backend == .overlay {
            rebuildWindowsIfNeeded()
        }
    }

    private func rebuildWindowsIfNeeded() {
        let screens = NSScreen.screens
        let signature = configurationSignature(for: screens)
        guard signature != screenConfigurationSignature else { return }

        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()

        overlayWindows = screens.map { screen in
            let window = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.hidesOnDeactivate = false
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]
            return window
        }
        screenConfigurationSignature = signature
        overlayNeedsFront = true
    }

    private func refreshForScreenChange() {
        invalidateDisplayConfiguration()
        guard isActive else { return }
        setBrightness(currentBrightness, force: true)
    }

    private func refreshForActiveSpaceChange() {
        guard isActive, backend == .overlay else { return }

        // Space/全屏切换只在事件发生时重新置顶，训练 tick 不再触发窗口置顶。
        applyCurrentBrightness(bringToFront: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.isActive, self.backend == .overlay else { return }
            self.applyCurrentBrightness(bringToFront: true)
        }
    }

    private func applyCurrentBrightness(bringToFront: Bool = false) {
        let opacity = 1.0 - currentBrightness
        let shouldBringToFront = bringToFront || overlayNeedsFront
        for window in overlayWindows {
            window.alphaValue = opacity
            if shouldBringToFront {
                window.orderFrontRegardless()
            }
        }
        if shouldBringToFront {
            overlayNeedsFront = false
        }
    }

    /// 直接缩放显示输出的 RGB Gamma 范围。该方式不依赖窗口，切换 App、Space
    /// 或全屏页面时不会短暂失去调光效果。
    private func applyGammaBrightness() -> Bool {
        let displayIDs = activeDisplayIDs()
        guard !displayIDs.isEmpty else { return false }

        let scale = CGGammaValue(currentBrightness)
        for displayID in displayIDs {
            guard let original = originalGammaByDisplay[displayID] ?? captureGamma(for: displayID) else {
                restoreGammaBrightness()
                return false
            }
            originalGammaByDisplay[displayID] = original

            let result = CGSetDisplayTransferByFormula(
                displayID,
                original.redMin * scale,
                original.redMax * scale,
                original.redGamma,
                original.greenMin * scale,
                original.greenMax * scale,
                original.greenGamma,
                original.blueMin * scale,
                original.blueMax * scale,
                original.blueGamma
            )
            guard result == .success else {
                restoreGammaBrightness()
                return false
            }
        }
        return true
    }

    private func captureGamma(for displayID: CGDirectDisplayID) -> GammaFormula? {
        var redMin: CGGammaValue = 0
        var redMax: CGGammaValue = 1
        var redGamma: CGGammaValue = 1
        var greenMin: CGGammaValue = 0
        var greenMax: CGGammaValue = 1
        var greenGamma: CGGammaValue = 1
        var blueMin: CGGammaValue = 0
        var blueMax: CGGammaValue = 1
        var blueGamma: CGGammaValue = 1

        let result = CGGetDisplayTransferByFormula(
            displayID,
            &redMin, &redMax, &redGamma,
            &greenMin, &greenMax, &greenGamma,
            &blueMin, &blueMax, &blueGamma
        )
        guard result == .success else { return nil }

        return GammaFormula(
            redMin: redMin,
            redMax: redMax,
            redGamma: redGamma,
            greenMin: greenMin,
            greenMax: greenMax,
            greenGamma: greenGamma,
            blueMin: blueMin,
            blueMax: blueMax,
            blueGamma: blueGamma
        )
    }

    private func restoreGammaBrightness() {
        for (displayID, original) in originalGammaByDisplay {
            CGSetDisplayTransferByFormula(
                displayID,
                original.redMin, original.redMax, original.redGamma,
                original.greenMin, original.greenMax, original.greenGamma,
                original.blueMin, original.blueMax, original.blueGamma
            )
        }
        originalGammaByDisplay.removeAll()
    }

    private func activeDisplayIDs() -> [CGDirectDisplayID] {
        NSScreen.screens.compactMap { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        }
    }

    private func hideOverlayWindows() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        screenConfigurationSignature = ""
        overlayNeedsFront = false
    }

    private func configurationSignature(for screens: [NSScreen]) -> String {
        screens.map { screen in
            let frame = screen.frame
            let rawScreenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            let screenID = rawScreenID.map { String(describing: $0) } ?? "unknown"
            let origin = "\(frame.origin.x),\(frame.origin.y)"
            let size = "\(frame.size.width)x\(frame.size.height)"
            let scale = "\(screen.backingScaleFactor)"
            return "\(screenID):\(screen.localizedName):\(origin):\(size):\(scale)"
        }
        .joined(separator: "|")
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        if let activeSpaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceChangeObserver)
        }
    }
}
