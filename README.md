# 练眼 · Mac 版

明暗屏幕练习程序 — 通过有节奏地控制系统背光亮度，辅助眼肌锻炼与视力训练。

基于 EM视力恢复训练体系。

## 项目结构

```
WenquanEyeTrainer/
├── WenquanEyeTrainer/          # 主 App
│   ├── App/
│   │   └── WenquanEyeTrainerApp.swift
│   ├── ViewModel/
│   │   └── AppViewModel.swift
│   ├── Views/
│   │   ├── MenuBarView.swift
│   │   ├── FloatingPanel.swift
│   │   ├── ManualControlView.swift
│   │   ├── Components/
│   │   │   ├── BrightnessSlider.swift
│   │   │   └── CurveSelector.swift
│   │   └── Settings/
│   │       ├── SettingsWindow.swift
│   │       ├── TrainingTab.swift
│   │       ├── HotkeyTab.swift
│   │       ├── NotificationTab.swift
│   │       └── AboutTab.swift
│   ├── Services/
│   │   ├── XPCBridge.swift
│   │   └── HotkeyManager.swift
│   ├── Models/
│   │   └── TrainingSettings.swift
│   ├── Resources/
│   │   └── Info.plist
│   └── Entitlements/
│       └── WenquanEyeTrainer.entitlements
│
├── BrightnessXPC/              # XPC Service
│   ├── main.swift
│   ├── XPCServiceDelegate.swift
│   ├── CurveEngine.swift
│   ├── TimerDriver.swift
│   ├── BrightnessController.swift
│   └── Info.plist
│
├── Shared/
│   └── XPCProtocol.swift
│
└── README.md
```

## 构建方式

### 1. 用 Xcode 构建（推荐）

1. 打开 Xcode，创建新项目：
   - 模板：**macOS → App**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - 项目名：`WenquanEyeTrainer`

2. 删除自动生成的 ContentView.swift 等模板文件

3. 将 `WenquanEyeTrainer/` 下所有 `.swift` 文件拖入项目（保持目录结构）

4. 添加 XPC Service Target：
   - File → New → Target → macOS → XPC Service
   - Product Name: `BrightnessXPC`
   - Bundle Identifier: `com.wenquan.BrightnessXPC`

5. 将 `BrightnessXPC/` 和 `Shared/` 下所有 `.swift` 文件添加为 **两个 Target 都编译** 的成员

6. 设置主 App Target：
   - Info.plist → `LSUIElement` = `YES`（隐藏 Dock 图标，仅菜单栏）
   - Signing & Capabilities → 关闭 Sandbox（IOKit 需要）
   - Build Phases → Embed XPC Services → 添加 BrightnessXPC.xpc

7. Info.plist 配置：
   - 主 App: 使用 `WenquanEyeTrainer/Resources/Info.plist`
   - XPC Service: 使用 `BrightnessXPC/Info.plist`

8. 选择 My Mac 作为目标，⌘R 运行

### 2. 首次运行授权

首次启动会弹出权限请求。需要在：
**系统设置 → 辅助功能** 中授权 `文全练眼`，以允许控制屏幕亮度。

## 功能

- 🔄 自动模式：3 种曲线（线性 / 阶梯 / 正弦），可调速度、时长、亮度范围
- 🖐 手动模式：滑块 + 热键控制亮度
- 📌 菜单栏常驻
- 🪟 浮动状态窗实时显示亮度
- ⌨ 全局快捷键（⌘B 开始 / ⌘S 停止 / ⌘↑↓ 调节）

## 技术栈

- Swift 5.9+
- SwiftUI + AppKit
- IOKit（CoreBrightness）
- NSXPCConnection（双进程架构）
- macOS 14 Sonoma+

## 许可

MIT License
