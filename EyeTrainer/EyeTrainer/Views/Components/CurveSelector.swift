import SwiftUI

/// 曲线类型三选一组件
struct CurveSelector: View {
    @Binding var selected: CurveType
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(CurveType.allCases, id: \.self) { curve in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = curve
                    }
                } label: {
                    Text(curve.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(selected == curve ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(selected == curve ? .accentColor : .secondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selected == curve ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
