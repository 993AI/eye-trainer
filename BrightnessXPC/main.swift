import Foundation

/// BrightnessXPC 服务入口
/// 由 launchd 或主 App 拉起，监听 XPC 连接

let delegate = XPCServiceDelegate()
let listener = NSXPCListener.service()

listener.delegate = delegate
listener.resume()

// 保持运行
RunLoop.current.run()
