import SwiftUI

// MARK: - ReviewView

/// 深度复习界面的根视图
/// 默认显示词库列表，点击「开始复习」进入 SRS 翻卡模式
struct ReviewView: View {

    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isSessionActive {
                reviewSessionView
            } else {
                wordLibraryView
            }
        }
        .onAppear {
            Task { await viewModel.loadWords() }
        }
    }

    // MARK: - Word Library (default)

    private var wordLibraryView: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("生词本")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(viewModel.allWords.count) 个单词 · \(viewModel.dueCount) 个待复习")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.dueCount > 0 {
                    Button("开始复习 (\(viewModel.dueCount))") {
                        Task { await viewModel.startSession() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(16)

            Divider()

            // 词库列表
            if viewModel.allWords.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("还没有生词")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("按 fn + 点击来抓取新词")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.allWords) { word in
                        WordRowView(word: word)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteWord(viewModel.allWords[index])
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Review Session (SRS flashcard)

    private var reviewSessionView: some View {
        VStack(spacing: 24) {
            // 顶部：进度 + 退出按钮
            HStack {
                ReviewStatsView(progress: viewModel.progress)
                Button(action: { viewModel.endSession() }) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Spacer()

            // 翻转卡片
            if let word = viewModel.currentWord {
                ReviewCardView(word: word, isFlipped: viewModel.isFlipped)
                    .frame(height: 320)
                    .padding(.horizontal)
                    .onTapGesture {
                        viewModel.flipCard()
                    }
            }

            Spacer()

            // 反馈按钮（翻转后才显示）
            if viewModel.isFlipped {
                feedbackButtons
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(24)
        .animation(.spring(response: 0.3), value: viewModel.isFlipped)
    }

    // MARK: - Feedback Buttons

    private var feedbackButtons: some View {
        HStack(spacing: 12) {
            ForEach(ReviewFeedback.allCases, id: \.rawValue) { feedback in
                Button(action: { viewModel.submitFeedback(feedback) }) {
                    Text(feedback.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(color(for: feedback).opacity(0.15))
                        )
                        .foregroundColor(color(for: feedback))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func color(for feedback: ReviewFeedback) -> Color {
        switch feedback {
        case .forgot: return .red
        case .hard:   return .orange
        case .good:   return .green
        case .easy:   return .blue
        }
    }
}

// MARK: - WordRowView

/// 词库列表中的单行
private struct WordRowView: View {
    let word: WordEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.word)
                        .font(.body)
                        .fontWeight(.medium)
                    stateTag
                }
                Text(word.definition)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(word.capturedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var stateTag: some View {
        Text(word.learningState.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(stateColor.opacity(0.15))
            )
            .foregroundColor(stateColor)
    }

    private var stateColor: Color {
        switch word.learningState {
        case .new:      return .blue
        case .learning: return .orange
        case .mastered: return .green
        }
    }
}
