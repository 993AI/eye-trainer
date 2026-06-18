import SwiftUI

/// 可复用的亮度滑块组件
struct BrightnessSlider: View {
    @Binding var value: Double
    var minLabel: String = "🌑"
    var maxLabel: String = "🔆"
    var showValue: Bool = true
    var size: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 6) {
            if showValue {
                Text("\(Int(value * 100))%")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 8) {
                Text(minLabel)
                Slider(value: $value, in: 0.05...1.0)
                    .frame(width: size)
                    .tint(.accentColor)
                Text(maxLabel)
            }
        }
    }
}
