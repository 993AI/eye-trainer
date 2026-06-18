import SwiftUI

/// 浮动状态窗：训练时弹出，显示实时状态和快捷操作
struct FloatingPanelView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("👁")
                    Text(viewModel.isRunning ? "训练中" : "准备就绪")
                        .font(.system(size: 12, weight: .semibold))
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(viewModel.selectedCurve.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                Circle()
                    .fill(viewModel.isRunning ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text(viewModel.isRunning ? "运行" : "待机")
                    .font(.system(size: 9))
                    .foregroundColor(viewModel.isRunning ? .green : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider().opacity(0.3)
            
            // Brightness Display
            VStack(spacing: 8) {
                HStack {
                    Text("🌑 \(Int(viewModel.settings.minBrightness * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("亮度")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.settings.maxBrightness * 100))% 🔆")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(white: viewModel.settings.minBrightness * 0.5),
                                        .yellow,
                                        .white
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * viewModel.currentBrightness,
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
                
                Text("\(Int(viewModel.currentBrightness * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(14)
            
            // Action Buttons
            HStack(spacing: 8) {
                PanelButton(
                    label: viewModel.isRunning ? "⏸ 停止" : "▶ 开始",
                    color: viewModel.isRunning ? .orange : .green,
                    action: {
                        if viewModel.isRunning {
                            viewModel.stopTraining()
                        } else {
                            viewModel.startTraining()
                        }
                    }
                )
                
                PanelButton(
                    label: "⏭ 跳过",
                    action: { viewModel.skipToNextCycle() }
                )
                
                PanelButton(
                    label: "⚙ 设置",
                    action: { openSettings() }
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            
            Divider().opacity(0.3)
            
            // Timer Info
            HStack {
                if viewModel.mode == .auto,
                   viewModel.settings.durationMinutes != nil,
                   viewModel.remainingSeconds > 0 {
                    Text("剩余 \(formatTime(viewModel.remainingSeconds))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("间隔 \(String(format: "%.1f", viewModel.settings.cycleSeconds))s")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 240)
    }
    
    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Panel Button

struct PanelButton: View {
    let label: String
    var color: Color? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background((color ?? .white).opacity(0.08))
                .foregroundColor(color ?? .primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke((color ?? .white).opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
