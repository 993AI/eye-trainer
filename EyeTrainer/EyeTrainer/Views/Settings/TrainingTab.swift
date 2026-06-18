import SwiftUI

/// 训练参数标签
struct TrainingTab: View {
    @Environment(AppViewModel.self) private var viewModel
    
    var body: some View {
        @Bindable var vm = viewModel
        
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 默认模式
                SettingSection(title: "默认模式") {
                    Picker("模式", selection: $vm.settings.defaultMode) {
                        ForEach(TrainingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // 默认曲线
                SettingSection(title: "默认曲线（自动模式）") {
                    CurveSelector(selected: $vm.settings.defaultCurve)
                }
                
                // 切换速度
                SettingSection(title: "切换速度（周期）") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("慢 1s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $vm.settings.cycleSeconds, in: 1...10, step: 0.5)
                                .frame(width: 200)
                            Text("快 10s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 8) {
                            Text("自定义")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("秒数", value: Binding(
                                get: { vm.settings.cycleSeconds },
                                set: { vm.settings.cycleSeconds = min(max($0, 0.1), 3600) }
                            ), format: .number.precision(.fractionLength(1...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            Text("秒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("范围 0.1–3600 秒")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        Text("\(String(format: "%.1f", vm.settings.cycleSeconds))s / \(Int(60.0 / vm.settings.cycleSeconds)) 次/分钟")
                            .font(.callout)
                            .foregroundColor(.accentColor)
                    }
                }
                
                // 训练时长
                SettingSection(title: "训练时长") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("1 分钟")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: Binding(
                                get: { Double(vm.settings.durationMinutes ?? 5) },
                                set: { vm.settings.durationMinutes = Int($0) }
                            ), in: 1...60, step: 1)
                            .frame(width: 200)
                            Text("60 分钟")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("\(vm.settings.durationMinutes ?? 0) 分钟")
                            .font(.callout)
                            .foregroundColor(.accentColor)
                        
                        Toggle("无限时（手动停止）", isOn: Binding(
                            get: { vm.settings.durationMinutes == nil },
                            set: { vm.settings.durationMinutes = $0 ? nil : 5 }
                        ))
                    }
                }
                
                // 亮度范围
                SettingSection(title: "亮度范围") {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("🌑 下限")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(vm.settings.minBrightness * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            Slider(value: $vm.settings.minBrightness, in: 0.05...0.50, step: 0.01)
                                .frame(width: 160)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("🔆 上限")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(vm.settings.maxBrightness * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            Slider(value: $vm.settings.maxBrightness, in: 0.50...1.00, step: 0.01)
                                .frame(width: 160)
                        }
                    }
                    .onChange(of: vm.settings.minBrightness) { _, newValue in
                        // 确保上限不低于下限+5%
                        if vm.settings.maxBrightness <= newValue + 0.05 {
                            vm.settings.maxBrightness = min(newValue + 0.10, 1.0)
                        }
                    }
                }
                
                // 阶梯级数
                SettingSection(title: "阶梯级数（阶梯曲线）") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("3 级")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: Binding(
                                get: { Double(vm.settings.stepLevels) },
                                set: { vm.settings.stepLevels = Int($0) }
                            ), in: 3...10, step: 1)
                            .frame(width: 200)
                            Text("10 级")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("\(vm.settings.stepLevels) 级")
                            .font(.callout)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - SettingSection

struct SettingSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            content()
        }
    }
}
