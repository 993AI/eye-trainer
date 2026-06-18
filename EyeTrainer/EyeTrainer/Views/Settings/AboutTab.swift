import SwiftUI

/// 关于标签
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 4) {
                Text("练眼")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("明暗屏幕练习程序 · Mac 版")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            Text("通过有节奏地控制系统背光亮度\n辅助眼睛肌肉锻炼与放松")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text("基于 EM视力恢复训练体系\nMIT License © 2026")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
