import SwiftUI
import Combine
import AppKit

/// 应用唯一状态中心
@MainActor
@Observable
final class AppViewModel {
    static let shared = AppViewModel()
    
    // MARK: - Published State
    
    var mode: TrainingMode = .auto
    var isRunning: Bool = false
    var currentBrightness: Double = 0.5
    var remainingSeconds: Int = 0
    var selectedCurve: CurveType = .sine
    var isXPCConnected: Bool = false
    
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
    
    // MARK: - Init
    
    init() {
        self.settings = Self.loadSettings()
        self.selectedCurve = settings.defaultCurve
        self.mode = settings.defaultMode
        
        setupXPC()
        setupHotkeys()
    }
    
    // MARK: - XPC Setup
    
    private func setupXPC() {
        xpcBridge.onEvent = { [weak self] event in
            self?.handleXPCEvent(event)
        }
        xpcBridge.connect()
    }
    
    private func handleXPCEvent(_ event: XPCEvent) {
        switch event.type {
        case .tick:
            if let tick = event.tick {
                currentBrightness = tick.currentBrightness
                applyExternalDisplayFallback(tick.currentBrightness)
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
        setupHotkeys()
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
                    stepLevels: settings.stepLevels
                ))
            } else {
                fallbackTimer?.stop()
                startFallbackAuto()
            }
        } else {
            fallbackTimer?.stop()
            if xpcBridge.isConnected {
                xpcBridge.setBrightness(manualBrightness)
            } else {
                applyBrightnessDirectly(manualBrightness)
            }
        }
    }
    
    // MARK: - Training Control
    
    func startTraining() {
        guard !isRunning else { return }
        
        mode = settings.defaultMode
        selectedCurve = settings.defaultCurve
        isRunning = true
        
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
                    stepLevels: settings.stepLevels
                )
                xpcBridge.startTraining(req)
            } else {
                // 降级：本地直驱
                startFallbackAuto()
            }
        } else {
            // 手动模式
            currentBrightness = manualBrightness
            if xpcBridge.isConnected {
                xpcBridge.setBrightness(manualBrightness)
            } else {
                applyBrightnessDirectly(manualBrightness)
            }
        }
    }
    
    func stopTraining() {
        guard isRunning else { return }
        
        if xpcBridge.isConnected {
            xpcBridge.stopTraining()
        } else {
            fallbackTimer?.stop()
            fallbackTimer = nil
        }
        
        isRunning = false
        remainingSeconds = 0
        screenDimmingController.restore()
    }
    
    func setManualBrightness(_ value: Double) {
        manualBrightness = min(max(value, 0.05), 1.0)
        guard isRunning, mode == .manual else { return }
        
        currentBrightness = manualBrightness
        if xpcBridge.isConnected {
            xpcBridge.setBrightness(manualBrightness)
        } else {
            applyBrightnessDirectly(manualBrightness)
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
        
        if xpcBridge.isConnected {
            xpcBridge.setBrightness(target)
        } else {
            applyBrightnessDirectly(target)
        }
        currentBrightness = target
    }
    
    // MARK: - Fallback (降级直驱)
    
    private func startFallbackAuto() {
        let driver = TimerDriver()
        let duration: Double? = settings.durationMinutes.map { Double($0) * 60.0 }
        
        driver.onTick = { [weak self] cycleT, elapsed, remaining in
            guard let self = self else { return }
            
            let brightness = CurveEngine.calculate(
                curve: self.selectedCurve,
                t: cycleT,
                minBrightness: self.settings.minBrightness,
                maxBrightness: self.settings.maxBrightness,
                cycleSeconds: self.settings.cycleSeconds,
                stepLevels: self.settings.stepLevels
            )
            
            self.applyBrightnessDirectly(brightness)
            DispatchQueue.main.async {
                self.currentBrightness = brightness
                self.remainingSeconds = remaining
            }
        }
        
        driver.onCompleted = { [weak self] in
            DispatchQueue.main.async {
                self?.stopTraining()
            }
        }
        
        driver.start(cycleSeconds: settings.cycleSeconds, durationSeconds: duration)
        fallbackTimer = driver
    }
    
    private func applyBrightnessDirectly(_ value: Double) {
        if !BrightnessController.shared.isAvailable {
            applyExternalDisplayFallback(value)
            return
        }

        // 降级模式下直接调用 IOKit
        // 通过启动一个轻量后台任务来避免阻塞主线程
        DispatchQueue.global(qos: .userInteractive).async {
            // 这里直接复用 XPC Service 层的 BrightnessController
            // 在降级模式下，主 App 直接 link BrightnessXPC 的代码
            BrightnessController.shared.setBrightness(value)
        }
    }

    private func applyExternalDisplayFallback(_ value: Double) {
        guard !BrightnessController.shared.isAvailable else { return }
        screenDimmingController.setBrightness(value)
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
    private var overlayWindows: [NSWindow] = []
    private var screenConfigurationSignature = ""
    private var screenChangeObserver: NSObjectProtocol?
    private var currentBrightness = 1.0
    private var isActive = false

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
    }

    func setBrightness(_ value: Double) {
        currentBrightness = min(max(value, 0.05), 1.0)
        isActive = true

        rebuildWindowsIfNeeded()
        applyCurrentBrightness()
    }

    func restore() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        screenConfigurationSignature = ""
        currentBrightness = 1.0
        isActive = false
    }

    private func rebuildWindowsIfNeeded() {
        let screens = NSScreen.screens
        let signature = configurationSignature(for: screens)
        guard signature != screenConfigurationSignature else { return }

        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()

        overlayWindows = screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            return window
        }
        screenConfigurationSignature = signature
    }

    private func refreshForScreenChange() {
        guard isActive else { return }
        rebuildWindowsIfNeeded()
        applyCurrentBrightness()
    }

    private func applyCurrentBrightness() {
        let opacity = 1.0 - currentBrightness
        for window in overlayWindows {
            window.alphaValue = opacity
            window.orderFrontRegardless()
        }
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
    }
}
