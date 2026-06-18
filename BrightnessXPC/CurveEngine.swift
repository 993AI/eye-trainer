import Foundation

/// 亮度曲线计算引擎
final class CurveEngine {
    
    /// 根据曲线类型和当前时间，计算亮度值
    /// - Parameters:
    ///   - curve: 曲线类型
    ///   - t: 当前周期内的相对时间（0 ~ cycleSeconds）
    ///   - minBrightness: 亮度下限
    ///   - maxBrightness: 亮度上限
    ///   - cycleSeconds: 完整周期时长
    ///   - stepLevels: 阶梯级数（仅 stepped 模式使用）
    /// - Returns: 亮度值 (0.0 ~ 1.0)
    static func calculate(
        curve: CurveType,
        t: Double,
        minBrightness: Double,
        maxBrightness: Double,
        cycleSeconds: Double,
        stepLevels: Int = 4
    ) -> Double {
        let range = maxBrightness - minBrightness
        let normalizedT = t / cycleSeconds // 0 ~ 1
        
        let factor: Double
        
        switch curve {
        case .linear:
            // 前半周期：min → max；后半周期：max → min
            if normalizedT <= 0.5 {
                factor = normalizedT * 2.0
            } else {
                factor = (1.0 - normalizedT) * 2.0
            }
            
        case .stepped:
            // 将半周期等分为 stepLevels 级
            let halfT = normalizedT <= 0.5 ? normalizedT : (1.0 - normalizedT)
            let stepRaw = halfT * 2.0 * Double(stepLevels)
            let stepIndex = min(Int(stepRaw), stepLevels - 1)
            factor = Double(stepIndex + 1) / Double(stepLevels)
            
        case .sine:
            // sin² 曲线: 0 → 1 → 0，自然呼吸感
            let phase = normalizedT * .pi
            factor = sin(phase) * sin(phase)
        }
        
        return minBrightness + range * factor
    }
}
