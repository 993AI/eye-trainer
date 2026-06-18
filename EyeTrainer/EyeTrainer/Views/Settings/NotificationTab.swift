import SwiftUI

/// 通知设置标签
struct NotificationTab: View {
    @Environment(AppViewModel.self) private var viewModel
    
    var body: some View {
        @Bindable var vm = viewModel
        
        VStack(alignment: .leading, spacing: 18) {
            Text("通知设置")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Toggle("训练完成时发送通知", isOn: $vm.settings.notifyOnComplete)
            
            Text("训练时长到达后，系统通知中心会弹出提醒")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(20)
    }
}
