import Foundation

/// 亮度曲线计算引擎
final class CurveEngine {

    /// 计算一个完整周期中的归一化位置：0 表示最小值，1 表示最大值。
    static func calculateFactor(
        curve: CurveType,
        t: Double,
        cycleSeconds: Double,
        transitionStyle: TransitionStyle = .gradual,
        stepLevels: Int = 4
    ) -> Double {
        let safeCycle = max(cycleSeconds, 0.001)
        let normalizedT = min(max(t / safeCycle, 0), 1)

        if transitionStyle == .direct {
            return normalizedT < 0.5 ? 0 : 1
        }

        switch curve {
        case .linear:
            return normalizedT <= 0.5
                ? normalizedT * 2.0
                : (1.0 - normalizedT) * 2.0

        case .stepped:
            // 保留最小值和最大值两个端点，中间按级数离散化。
            let halfT = normalizedT <= 0.5 ? normalizedT : (1.0 - normalizedT)
            let levelCount = max(stepLevels, 1)
            let rawLevel = min(Int((halfT * 2.0 * Double(levelCount)).rounded(.down)), levelCount)
            return Double(rawLevel) / Double(levelCount)

        case .sine:
            let phase = normalizedT * .pi
            let sine = sin(phase)
            return sine * sine
        }
    }
    
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
        stepLevels: Int = 4,
        transitionStyle: TransitionStyle = .gradual
    ) -> Double {
        let range = maxBrightness - minBrightness
        let factor = calculateFactor(
            curve: curve,
            t: t,
            cycleSeconds: cycleSeconds,
            transitionStyle: transitionStyle,
            stepLevels: stepLevels
        )
        return minBrightness + range * factor
    }

    static func calculateColorTemperature(
        curve: CurveType,
        t: Double,
        minTemperature: Double,
        maxTemperature: Double,
        cycleSeconds: Double,
        stepLevels: Int = 4,
        transitionStyle: TransitionStyle = .gradual
    ) -> Double {
        let factor = calculateFactor(
            curve: curve,
            t: t,
            cycleSeconds: cycleSeconds,
            transitionStyle: transitionStyle,
            stepLevels: stepLevels
        )
        return minTemperature + (maxTemperature - minTemperature) * factor
    }
}

/// 色温到 RGB 通道比例的近似转换。
/// 该转换用于 Gamma 输出，避免把色温误实现成三个通道等比例缩放。
enum ColorTemperatureEngine {
    struct RGBMultiplier {
        let red: Double
        let green: Double
        let blue: Double
    }

    static func multipliers(for temperature: Double) -> RGBMultiplier {
        let kelvin = min(max(temperature, 1000), 10000)
        let scaled = kelvin / 100.0

        let red: Double
        let green: Double
        let blue: Double

        if scaled <= 66 {
            red = 255
            green = 99.4708025861 * log(max(scaled, 1)) - 161.1195681661
        } else {
            red = 329.698727446 * pow(scaled - 60, -0.1332047592)
            green = 288.1221695283 * pow(scaled - 60, -0.0755148492)
        }

        if scaled >= 66 {
            blue = 255
        } else if scaled <= 19 {
            blue = 0
        } else {
            blue = 138.5177312231 * log(scaled - 10) - 305.0447927307
        }

        let normalizedRed = min(max(red / 255.0, 0), 1)
        let normalizedGreen = min(max(green / 255.0, 0), 1)
        let normalizedBlue = min(max(blue / 255.0, 0), 1)
        let peak = max(normalizedRed, max(normalizedGreen, normalizedBlue))
        let redByPeak = normalizedRed / max(peak, 0.001)
        let greenByPeak = normalizedGreen / max(peak, 0.001)
        let blueByPeak = normalizedBlue / max(peak, 0.001)

        // 以感知亮度做一次补偿，使色温变化尽量不被感知为额外的亮度变化。
        let luminance = 0.2126 * redByPeak + 0.7152 * greenByPeak + 0.0722 * blueByPeak
        let compensation = 1.0 / max(luminance, 0.001)

        return RGBMultiplier(
            red: min(max(redByPeak * compensation, 0), 1),
            green: min(max(greenByPeak * compensation, 0), 1),
            blue: min(max(blueByPeak * compensation, 0), 1)
        )
    }

    /// 覆盖层后端使用的近似色调和强度。
    static func overlayTint(for temperature: Double) -> (red: Double, green: Double, blue: Double, strength: Double) {
        let distance = min(abs(temperature - 6500) / 3500, 1)
        guard distance > 0.001 else {
            return (1, 1, 1, 0)
        }

        if temperature < 6500 {
            return (1.0, 0.42, 0.08, distance * 0.28)
        } else {
            return (0.12, 0.38, 1.0, distance * 0.20)
        }
    }
}
