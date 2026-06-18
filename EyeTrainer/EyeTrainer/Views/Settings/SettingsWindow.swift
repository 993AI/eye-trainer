import SwiftUI

/// 设置窗口容器
struct SettingsWindow: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedTab: SettingsTab = .training
    
    enum SettingsTab: String, CaseIterable {
        case training = "⏱ 训练"
        case hotkey = "⌨ 热键"
        case notification = "🔔 通知"
        case about = "ℹ 关于"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .background(
                        selectedTab == tab
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider().opacity(0.3)
            
            // Tab Content
            Group {
                switch selectedTab {
                case .training:
                    TrainingTab()
                case .hotkey:
                    HotkeyTab()
                case .notification:
                    NotificationTab()
                case .about:
                    AboutTab()
                }
            }
        }
        .frame(width: 460, height: 440)
    }
}
