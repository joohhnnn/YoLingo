import SwiftUI

// MARK: - ReviewStatsView

/// 复习进度统计条
struct ReviewStatsView: View {

    let progress: ReviewProgress

    var body: some View {
        VStack(spacing: 8) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * progress.percentage,
                            height: 8
                        )
                        .animation(.spring(response: 0.3), value: progress.percentage)
                }
            }
            .frame(height: 8)

            // 数字统计
            HStack {
                Label("\(progress.completed) 已完成", systemImage: "checkmark.circle")
                Spacer()
                Label("\(progress.remaining) 剩余", systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}
