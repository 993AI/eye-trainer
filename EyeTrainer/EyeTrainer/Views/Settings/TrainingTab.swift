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

                // 变化对象
                SettingSection(title: "变化对象") {
                    Picker("对象", selection: $vm.settings.defaultTarget) {
                        ForEach(TrainingTarget.allCases, id: \.self) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 变化方式
                SettingSection(title: "变化方式") {
                    Picker("方式", selection: $vm.settings.transitionStyle) {
                        ForEach(TransitionStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(vm.settings.transitionStyle == .direct
                         ? "在最小值和最大值之间瞬间切换，建议使用较长周期。"
                         : "在完整周期内从低值平滑变化到高值，再回到低值。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 默认曲线
                SettingSection(title: "默认曲线（自动模式）") {
                    CurveSelector(selected: $vm.settings.defaultCurve)
                        .disabled(vm.settings.transitionStyle == .direct)
                        .opacity(vm.settings.transitionStyle == .direct ? 0.5 : 1)
                    if vm.settings.transitionStyle == .direct {
                        Text("直接式不使用渐变曲线参数。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 切换速度
                SettingSection(title: "完整周期") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("慢 1s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $vm.settings.cycleSeconds, in: 1...15, step: 0.5)
                                .frame(width: 200)
                            Text("快 15s")
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
                        Text("\(String(format: "%.1f", vm.settings.cycleSeconds))s / \(Int(60.0 / max(vm.settings.cycleSeconds, 0.1))) 次/分钟")
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
                
                if vm.settings.defaultTarget != .colorTemperature {
                    // 仅亮度或亮度 + 色温时显示亮度范围
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
                            Slider(value: $vm.settings.minBrightness, in: 0.05...1.00, step: 0.01)
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
                            Slider(value: $vm.settings.maxBrightness, in: 0.20...1.00, step: 0.01)
                                .frame(width: 160)
                        }
                    }
                    .onChange(of: vm.settings.minBrightness) { _, newValue in
                        // 下限不能高于上限；相同值表示固定亮度，不做额外调整。
                        if vm.settings.maxBrightness < newValue {
                            vm.settings.maxBrightness = newValue
                        }
                    }
                    .onChange(of: vm.settings.maxBrightness) { _, newValue in
                        // 上限不能低于下限；相同值表示固定亮度，不做额外调整。
                        if vm.settings.minBrightness > newValue {
                            vm.settings.minBrightness = newValue
                        }
                    }
                    }
                }

                if vm.settings.defaultTarget != .brightness {
                    // 仅色温或亮度 + 色温时显示色温范围
                    SettingSection(title: "色温范围") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("暖 1000K")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $vm.settings.minColorTemperature, in: 1000...10000, step: 100)
                                .frame(width: 200)
                            Text("\(Int(vm.settings.minColorTemperature))K")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }

                        HStack {
                            Text("冷 10000K")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $vm.settings.maxColorTemperature, in: 1000...10000, step: 100)
                                .frame(width: 200)
                            Text("\(Int(vm.settings.maxColorTemperature))K")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }

                        Text("当前手动色温：\(Int(vm.settings.manualColorTemperature))K")
                            .font(.callout)
                            .foregroundColor(.accentColor)
                    }
                    .onChange(of: vm.settings.minColorTemperature) { _, newValue in
                        if vm.settings.maxColorTemperature <= newValue {
                            vm.settings.maxColorTemperature = min(newValue + 100, 10000)
                        }
                    }
                    .onChange(of: vm.settings.maxColorTemperature) { _, newValue in
                        if vm.settings.minColorTemperature >= newValue {
                            vm.settings.minColorTemperature = max(newValue - 100, 1000)
                        }
                    }
                    }
                }
                
                // 阶梯级数只对自动模式下的渐变式阶梯曲线生效。
                if vm.settings.defaultMode == .auto,
                   vm.settings.transitionStyle == .gradual,
                   vm.settings.defaultCurve == .stepped {
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
