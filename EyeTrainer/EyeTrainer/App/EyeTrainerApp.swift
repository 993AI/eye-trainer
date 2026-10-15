import SwiftUI
import AppKit

/// App 入口
@main
struct EyeTrainerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = AppViewModel.shared
    
    var body: some Scene {
        // 主状态窗：使用 WindowGroup，确保应用启动时有可见界面。
        WindowGroup("练眼 · 训练状态", id: "floating-panel") {
            MainWindowContent()
                .environment(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 260, height: 220)
        .defaultPosition(.center)
        
        // 设置窗口
        Window("偏好设置", id: "settings") {
            SettingsWindow()
                .environment(viewModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 440)
        
        // 手动模式亮度控制
        Window("手动控制", id: "manual-control") {
            ManualControlView()
                .environment(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 250)
    }
}

/// 保存 SwiftUI 主窗口及其打开动作，供菜单栏图标调用。
private final class MainWindowCoordinator {
    static let shared = MainWindowCoordinator()

    // 强引用主窗口，避免窗口仍然存在但引用已经失效，导致 WindowGroup 重复创建。
    private var window: NSWindow?
    var openWindow: OpenWindowAction?
    private var isOpening = false

    func show() {
        if let existing = mainWindows().first {
            register(existing)
            existing.makeKeyAndOrderFront(nil)
        } else if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 快速连续点击时，只允许一个 WindowGroup 打开请求进入系统队列。
            guard !isOpening else {
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            isOpening = true
            openWindow?(id: "floating-panel")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isOpening = false
                if let window = self?.mainWindows().first {
                    self?.register(window)
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func register(_ window: NSWindow) {
        let windows = mainWindows()
        for duplicate in windows.dropFirst() {
            duplicate.close()
        }
        self.window = windows.first ?? window
        isOpening = false
    }

    private func mainWindows() -> [NSWindow] {
        NSApp.windows.filter { $0.title == "练眼 · 训练状态" }
    }
}

private struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        FloatingPanelView()
            .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
            .onAppear {
                MainWindowCoordinator.shared.openWindow = openWindow
                NSApp.activate(ignoringOtherApps: true)

                // onAppear 时 SwiftUI 已创建窗口；下一轮主线程事件中保存稳定引用。
                DispatchQueue.main.async {
                    if let window = NSApp.windows.first(where: { $0.title == "练眼 · 训练状态" }) {
                        MainWindowCoordinator.shared.register(window)
                    }
                }
            }
    }
}

// MARK: - Application Lifecycle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettingsWindow),
            name: .openSettings,
            object: nil
        )

        NSApp.activate(ignoringOtherApps: true)

        if CommandLine.arguments.contains("--auto-start") {
            AppViewModel.shared.startTraining()
        }
        if CommandLine.arguments.contains("--show-settings") {
            showSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppViewModel.shared.stopTraining()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "练眼")
            button.toolTip = "练眼菜单"
            button.target = self
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusItemMenu()
        } else {
            showMainWindow()
        }
    }

    private func showStatusItemMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "退出 Quit", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 4),
            in: button
        )
    }

    @objc private func quitApplication() {
        Task { @MainActor in
            AppViewModel.shared.stopTraining()
            NSApp.terminate(nil)
        }
    }

    @objc private func showMainWindow() {
        MainWindowCoordinator.shared.show()
    }

    @objc private func showSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
        window.contentView = NSHostingView(
            rootView: SettingsWindow().environment(AppViewModel.shared)
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Settings Launcher

/// 当 MenuBarView 触发打开设置时，通过通知激活 Settings 窗口
/// 这在这里作为 onAppear 监听
extension EyeTrainerApp {
    // Settings 窗口通过 WindowGroup(id:) 由系统自动管理
    // 通过 openSettings 通知 + NSApp.activate 来打开
}

// MARK: - NSVisualEffectView Bridge

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
