import Foundation

/// 训练模式
enum TrainingMode: String, CaseIterable, Codable {
    case auto   = "auto"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .auto:   return "自动"
        case .manual: return "手动"
        }
    }
}

/// 亮度变化曲线类型
enum CurveType: String, CaseIterable, Codable {
    case linear  = "linear"
    case stepped = "stepped"
    case sine    = "sine"
    
    var displayName: String {
        switch self {
        case .linear:  return "线性"
        case .stepped: return "阶梯"
        case .sine:    return "正弦"
        }
    }
}

/// 自动训练时参与变化的显示属性。
enum TrainingTarget: String, CaseIterable, Codable {
    case brightness = "brightness"
    case colorTemperature = "colorTemperature"
    case both = "both"

    var displayName: String {
        switch self {
        case .brightness: return "仅亮度"
        case .colorTemperature: return "仅色温"
        case .both: return "亮度 + 色温"
        }
    }

    var includesBrightness: Bool {
        self == .brightness || self == .both
    }

    var includesColorTemperature: Bool {
        self == .colorTemperature || self == .both
    }
}

/// 自动训练的极值变化方式。
enum TransitionStyle: String, CaseIterable, Codable {
    case direct = "direct"
    case gradual = "gradual"

    var displayName: String {
        switch self {
        case .direct: return "直接式"
        case .gradual: return "渐变式"
        }
    }
}

/// 热键定义
struct HotkeyDef: Codable {
    var keyCode: UInt16
    var modifiers: UInt32   // Carbon modifier flags
}

/// 训练参数（全部持久化到 UserDefaults）
struct TrainingSettings: Codable {
    var defaultMode: TrainingMode = .auto
    var defaultCurve: CurveType = .sine
    var defaultTarget: TrainingTarget = .brightness
    var transitionStyle: TransitionStyle = .gradual
    var cycleSeconds: Double = 3.0          // 完整周期 (1.0 ~ 15.0，支持自定义更大值)
    var durationMinutes: Int? = 5           // nil = 无限时
    var minBrightness: Double = 0.15        // 亮度下限 (0.05 ~ 0.50)
    var maxBrightness: Double = 0.90        // 亮度上限 (0.50 ~ 1.00)
    var stepLevels: Int = 4                 // 阶梯级数 (3 ~ 10)
    var minColorTemperature: Double = 3000  // 色温下限 (1000K ~ 10000K)
    var maxColorTemperature: Double = 8000  // 色温上限 (1000K ~ 10000K)
    var manualColorTemperature: Double = 6500
    
    var startHotkey: HotkeyDef = HotkeyDef(keyCode: 11, modifiers: 0x0100)   // ⌘B
    var stopHotkey: HotkeyDef = HotkeyDef(keyCode: 1, modifiers: 0x0100)     // ⌘S
    var upHotkey: HotkeyDef = HotkeyDef(keyCode: 126, modifiers: 0x0100)     // ⌘↑
    var downHotkey: HotkeyDef = HotkeyDef(keyCode: 125, modifiers: 0x0100)   // ⌘↓
    
    var notifyOnComplete: Bool = true

    private enum CodingKeys: String, CodingKey {
        case defaultMode, defaultCurve, defaultTarget, transitionStyle
        case cycleSeconds, durationMinutes, minBrightness, maxBrightness, stepLevels
        case minColorTemperature, maxColorTemperature, manualColorTemperature
        case startHotkey, stopHotkey, upHotkey, downHotkey, notifyOnComplete
    }

    /// 使用 decodeIfPresent 兼容 1.1 之前保存的 UserDefaults 配置。
    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultMode = try container.decodeIfPresent(TrainingMode.self, forKey: .defaultMode) ?? .auto
        defaultCurve = try container.decodeIfPresent(CurveType.self, forKey: .defaultCurve) ?? .sine
        defaultTarget = try container.decodeIfPresent(TrainingTarget.self, forKey: .defaultTarget) ?? .brightness
        transitionStyle = try container.decodeIfPresent(TransitionStyle.self, forKey: .transitionStyle) ?? .gradual
        cycleSeconds = try container.decodeIfPresent(Double.self, forKey: .cycleSeconds) ?? 3.0
        if container.contains(.durationMinutes) {
            durationMinutes = try container.decode(Int?.self, forKey: .durationMinutes)
        } else {
            durationMinutes = 5
        }
        minBrightness = try container.decodeIfPresent(Double.self, forKey: .minBrightness) ?? 0.15
        maxBrightness = try container.decodeIfPresent(Double.self, forKey: .maxBrightness) ?? 0.90
        stepLevels = try container.decodeIfPresent(Int.self, forKey: .stepLevels) ?? 4
        minColorTemperature = try container.decodeIfPresent(Double.self, forKey: .minColorTemperature) ?? 3000
        maxColorTemperature = try container.decodeIfPresent(Double.self, forKey: .maxColorTemperature) ?? 8000
        manualColorTemperature = try container.decodeIfPresent(Double.self, forKey: .manualColorTemperature) ?? 6500
        startHotkey = try container.decodeIfPresent(HotkeyDef.self, forKey: .startHotkey) ?? HotkeyDef(keyCode: 11, modifiers: 0x0100)
        stopHotkey = try container.decodeIfPresent(HotkeyDef.self, forKey: .stopHotkey) ?? HotkeyDef(keyCode: 1, modifiers: 0x0100)
        upHotkey = try container.decodeIfPresent(HotkeyDef.self, forKey: .upHotkey) ?? HotkeyDef(keyCode: 126, modifiers: 0x0100)
        downHotkey = try container.decodeIfPresent(HotkeyDef.self, forKey: .downHotkey) ?? HotkeyDef(keyCode: 125, modifiers: 0x0100)
        notifyOnComplete = try container.decodeIfPresent(Bool.self, forKey: .notifyOnComplete) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultMode, forKey: .defaultMode)
        try container.encode(defaultCurve, forKey: .defaultCurve)
        try container.encode(defaultTarget, forKey: .defaultTarget)
        try container.encode(transitionStyle, forKey: .transitionStyle)
        try container.encode(cycleSeconds, forKey: .cycleSeconds)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(minBrightness, forKey: .minBrightness)
        try container.encode(maxBrightness, forKey: .maxBrightness)
        try container.encode(stepLevels, forKey: .stepLevels)
        try container.encode(minColorTemperature, forKey: .minColorTemperature)
        try container.encode(maxColorTemperature, forKey: .maxColorTemperature)
        try container.encode(manualColorTemperature, forKey: .manualColorTemperature)
        try container.encode(startHotkey, forKey: .startHotkey)
        try container.encode(stopHotkey, forKey: .stopHotkey)
        try container.encode(upHotkey, forKey: .upHotkey)
        try container.encode(downHotkey, forKey: .downHotkey)
        try container.encode(notifyOnComplete, forKey: .notifyOnComplete)
    }
}
