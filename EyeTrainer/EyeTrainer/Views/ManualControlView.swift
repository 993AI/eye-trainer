import SwiftUI

/// 手动模式控制窗口
struct ManualControlView: View {
    @Environment(AppViewModel.self) private var viewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text("手动亮度控制")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            BrightnessSlider(
                value: Binding(
                    get: { viewModel.manualBrightness },
                    set: { newValue in
                        viewModel.setManualBrightness(newValue)
                    }
                ),
                size: 220
            )

            VStack(spacing: 4) {
                HStack {
                    Text("🌡 色温")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.manualColorTemperature))K")
                        .font(.callout)
                        .foregroundColor(.orange)
                }
                Slider(
                    value: Binding(
                        get: { viewModel.manualColorTemperature },
                        set: { viewModel.setManualColorTemperature($0) }
                    ),
                    in: 1000...10000,
                    step: 100
                )
            }
            
            HStack(spacing: 12) {
                Button { viewModel.adjustBrightness(up: true) } label: {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Button { viewModel.adjustBrightness(up: false) } label: {
                    Image(systemName: "sun.min.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button { viewModel.resetManualDisplay() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 300, height: 250)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}
