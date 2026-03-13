import SwiftUI

// MARK: - WordCardView

/// 通用单词卡片组件，在多个场景中复用
/// - 抓词浮窗中显示新抓到的单词
/// - 悬浮卡片中显示待复习单词
struct WordCardView: View {

    let word: String
    let phonetic: String?
    let definition: String
    let exampleSentences: [String]

    /// 是否显示「加入生词本」按钮
    var showAddButton: Bool = false
    var onAdd: (() -> Void)?

    /// 是否显示「忽略」按钮
    var showDismissButton: Bool = false
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 单词 + 音标
            HStack(alignment: .firstTextBaseline) {
                Text(word)
                    .font(.title3)
                    .fontWeight(.bold)

                if let phonetic = phonetic {
                    Text(phonetic)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 释义
            if !definition.isEmpty {
                Text(definition)
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.85))
            }

            // 例句（最多显示 1 条，节省空间）
            if let sentence = exampleSentences.first {
                Text(sentence)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(2)
            }

            // 操作按钮
            if showAddButton || showDismissButton {
                HStack(spacing: 12) {
                    if showDismissButton {
                        Button("忽略") { onDismiss?() }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Spacer()
                    if showAddButton {
                        Button(action: { onAdd?() }) {
                            Label("加入生词本", systemImage: "plus.circle.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
