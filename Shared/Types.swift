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

/// 热键定义
struct HotkeyDef: Codable {
    var keyCode: UInt16
    var modifiers: UInt32   // Carbon modifier flags
}

/// 训练参数（全部持久化到 UserDefaults）
struct TrainingSettings: Codable {
    var defaultMode: TrainingMode = .auto
    var defaultCurve: CurveType = .sine
    var cycleSeconds: Double = 3.0          // 切换周期 (1.0 ~ 10.0)
    var durationMinutes: Int? = 5           // nil = 无限时
    var minBrightness: Double = 0.15        // 亮度下限 (0.05 ~ 0.50)
    var maxBrightness: Double = 0.90        // 亮度上限 (0.50 ~ 1.00)
    var stepLevels: Int = 4                 // 阶梯级数 (3 ~ 10)
    
    var startHotkey: HotkeyDef = HotkeyDef(keyCode: 11, modifiers: 0x0100)   // ⌘B
    var stopHotkey: HotkeyDef = HotkeyDef(keyCode: 1, modifiers: 0x0100)     // ⌘S
    var upHotkey: HotkeyDef = HotkeyDef(keyCode: 126, modifiers: 0x0100)     // ⌘↑
    var downHotkey: HotkeyDef = HotkeyDef(keyCode: 125, modifiers: 0x0100)   // ⌘↓
    
    var notifyOnComplete: Bool = true
}
