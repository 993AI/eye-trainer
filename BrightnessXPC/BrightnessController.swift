import Foundation
import IOKit
import IOKit.graphics

/// 通过 IOKit 直接控制系统背光亮度
final class BrightnessController {
    
    static let shared = BrightnessController()
    
    private var connect: io_connect_t = 0
    private var service: io_service_t = 0
    
    private init() {
        setupConnection()
    }
    
    // MARK: - Connection
    
    private func setupConnection() {
        service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect")
        )
        
        if service == 0 {
            // 回退：尝试 AppleBacklightDisplay
            service = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleBacklightDisplay")
            )
        }
        
        guard service != 0 else { return }
        
        let status = IOServiceOpen(service, mach_task_self_, 0, &connect)
        if status != kIOReturnSuccess {
            connect = 0
        }
    }
    
    deinit {
        if connect != 0 {
            IOServiceClose(connect)
        }
        if service != 0 {
            IOObjectRelease(service)
        }
    }
    
    // MARK: - Brightness Control
    
    /// 获取当前亮度 (0.0 ~ 1.0)
    func getBrightness() -> Double {
        guard connect != 0 else { return 0.5 }
        
        var brightness: Float = 0.5
        let result = IODisplayGetFloatParameter(
            connect,
            0,
            kIODisplayBrightnessKey as CFString,
            &brightness
        )
        
        guard result == kIOReturnSuccess else { return 0.5 }
        return Double(min(max(brightness, 0.0), 1.0))
    }
    
    /// 设置亮度 (0.0 ~ 1.0)，内部做 clamp 到 5%~100%
    func setBrightness(_ value: Double) {
        let clamped = min(max(value, 0.05), 1.0)
        
        guard connect != 0 else { return }
        
        IODisplaySetFloatParameter(
            connect,
            0,
            kIODisplayBrightnessKey as CFString,
            Float(clamped)
        )
    }
    
    /// 检查是否有亮度控制权限/能力
    var isAvailable: Bool {
        connect != 0
    }
}
