import SwiftUI

/// 菜单栏下拉菜单
struct MenuBarView: View {
    @Environment(AppViewModel.self) private var viewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            Text("练眼")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider().opacity(0.3)
            
            // 开始/停止
            if viewModel.isRunning {
                MenuButton(
                    icon: "■",
                    label: "停止训练",
                    shortcut: stopHotkeyDisplay,
                    action: { viewModel.stopTraining() }
                )
            } else {
                MenuButton(
                    icon: "▶",
                    label: "开始训练",
                    shortcut: startHotkeyDisplay,
                    action: { viewModel.startTraining() }
                )
            }
            
            Divider().opacity(0.3)
            
            // 亮度范围快速显示
            VStack(spacing: 4) {
                HStack {
                    Text("🔆 上限: \(Int(viewModel.settings.maxBrightness * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                HStack {
                    Text("🌑 下限: \(Int(viewModel.settings.minBrightness * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider().opacity(0.3)
            
            // 曲线选择
            CurveSelector(selected: Binding(
                get: { viewModel.selectedCurve },
                set: { viewModel.selectedCurve = $0 }
            ))
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            
            Divider().opacity(0.3)
            
            // 偏好设置
            MenuButton(
                icon: "⚙",
                label: "偏好设置...",
                action: { openSettings() }
            )
            
            // 退出
            MenuButton(
                icon: "🚪",
                label: "退出",
                shortcut: "⌘Q",
                action: { NSApplication.shared.terminate(nil) }
            )
        }
        .padding(.vertical, 4)
        .frame(width: 220)
    }
    
    // MARK: - Helpers
    
    private var settings: TrainingSettings {
        viewModel.settings
    }
    
    private var settingsWindow: NSWindow? {
        NSApp.windows.first { $0.title == "偏好设置" }
    }
    
    private func openSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
        } else {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }
    
    private var startHotkeyDisplay: String {
        "⌘B"
    }
    
    private var stopHotkeyDisplay: String {
        "⌘S"
    }
}

// MARK: - Supporting Types

struct MenuButton: View {
    let icon: String
    let label: String
    var shortcut: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(icon)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
