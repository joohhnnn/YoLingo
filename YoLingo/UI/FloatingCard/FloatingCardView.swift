import SwiftUI

// MARK: - FloatingCardView

/// 桌面悬浮卡片主体视图
/// 显示待复习单词，支持左右滑动快速判断
struct FloatingCardView: View {

    @ObservedObject var viewModel: FloatingCardViewModel

    var body: some View {
        Group {
            if viewModel.isExpanded {
                expandedCard
            } else {
                collapsedBubble
            }
        }
        .scaleEffect(viewModel.bounceEffect ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: viewModel.bounceEffect)
        .onAppear {
            Task { await viewModel.loadDueWords() }
        }
    }

    // MARK: - Expanded Card

    private var expandedCard: some View {
        VStack(spacing: 12) {
            // 顶部：待复习数量 + 收缩按钮
            HStack {
                Text("\(viewModel.dueCount) 词待复习")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { viewModel.toggleExpand() }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let word = viewModel.currentWord {
                // 单词
                Text(word.word)
                    .font(.title2)
                    .fontWeight(.semibold)

                // 释义（点击翻转显示）
                if viewModel.showDefinition {
                    Text(word.definition)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }

                Spacer()

                // 底部操作区
                HStack(spacing: 20) {
                    // 不认识
                    Button(action: { viewModel.markAsForgotten() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    // 点击翻转
                    Button(action: { viewModel.toggleDefinition() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)

                    // 认识
                    Button(action: { viewModel.markAsKnown() }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Spacer()
                Text("今日复习已完成")
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 280, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Collapsed Bubble

    private var collapsedBubble: some View {
        Button(action: { viewModel.toggleExpand() }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)

                Text("\(viewModel.dueCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
        }
        .buttonStyle(.plain)
        .overlay(
            Circle()
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                .frame(width: 44, height: 44)
        )
    }
}
