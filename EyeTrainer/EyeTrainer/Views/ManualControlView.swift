import SwiftUI

/// 手动模式控制窗口
struct ManualControlView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var sliderValue: Double = 0.5
    
    var body: some View {
        VStack(spacing: 16) {
            Text("手动亮度控制")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            BrightnessSlider(
                value: Binding(
                    get: { sliderValue },
                    set: { newValue in
                        sliderValue = newValue
                        viewModel.setManualBrightness(newValue)
                    }
                ),
                size: 240
            )
            
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
            }
        }
        .padding(20)
        .frame(width: 300, height: 180)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}
