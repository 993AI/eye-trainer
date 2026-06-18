import SwiftUI

/// 热键配置标签
struct HotkeyTab: View {
    @Environment(AppViewModel.self) private var viewModel
    
    var body: some View {
        @Bindable var vm = viewModel
        
        VStack(alignment: .leading, spacing: 18) {
            Text("自定义全局快捷键")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HotkeyRow(
                label: "开始训练",
                keyCode: $vm.settings.startHotkey.keyCode,
                modifiers: $vm.settings.startHotkey.modifiers,
                onChanged: { viewModel.reregisterHotkeys() }
            )
            
            HotkeyRow(
                label: "停止训练",
                keyCode: $vm.settings.stopHotkey.keyCode,
                modifiers: $vm.settings.stopHotkey.modifiers,
                onChanged: { viewModel.reregisterHotkeys() }
            )
            
            HotkeyRow(
                label: "亮度 +",
                keyCode: $vm.settings.upHotkey.keyCode,
                modifiers: $vm.settings.upHotkey.modifiers,
                onChanged: { viewModel.reregisterHotkeys() }
            )
            
            HotkeyRow(
                label: "亮度 -",
                keyCode: $vm.settings.downHotkey.keyCode,
                modifiers: $vm.settings.downHotkey.modifiers,
                onChanged: { viewModel.reregisterHotkeys() }
            )
            
            Text("点击右侧按钮录制新快捷键")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(20)
    }
}

struct HotkeyRow: View {
    let label: String
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt32
    let onChanged: () -> Void
    
    @State private var isRecording = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Button {
                isRecording.toggle()
            } label: {
                Text(hotkeyDisplay)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(isRecording ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                    .foregroundColor(isRecording ? .accentColor : .primary)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var hotkeyDisplay: String {
        if isRecording {
            return "请输入..."
        }
        
        var parts: [String] = []
        if modifiers & 0x0100 != 0 { parts.append("⌘") }
        if modifiers & 0x0200 != 0 { parts.append("⇧") }
        if modifiers & 0x0800 != 0 { parts.append("⌥") }
        if modifiers & 0x1000 != 0 { parts.append("⌃") }
        
        // 常见键码映射
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 6: "Z", 7: "X",
            11: "B", 35: "P", 49: "Space",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            36: "↩", 53: "Esc"
        ]
        
        parts.append(keyMap[keyCode] ?? "Key\(keyCode)")
        return parts.joined()
    }
}
