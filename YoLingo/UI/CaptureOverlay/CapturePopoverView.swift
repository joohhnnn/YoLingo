import SwiftUI

// MARK: - CapturePopoverView

/// 抓词成功后弹出的浮窗
/// 显示单词释义、例句，提供「加入生词本」和「忽略」操作
struct CapturePopoverView: View {

    @ObservedObject var viewModel: CapturePopoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部：单词 + 音标
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.capturedText)
                    .font(.title3)
                    .fontWeight(.bold)

                if let phonetic = viewModel.dictionaryResult?.phonetic {
                    Text(phonetic)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 来源标记
                Text(viewModel.sourceApp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.primary.opacity(0.06))
                    )
            }

            Divider()

            // 释义区域
            if viewModel.isLoadingDefinition {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("查询中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let result = viewModel.dictionaryResult {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.definitions.prefix(3), id: \.meaning) { def in
                        HStack(alignment: .top, spacing: 6) {
                            Text(def.partOfSpeech)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .frame(width: 36, alignment: .trailing)
                            Text(def.meaning)
                                .font(.callout)
                                .foregroundColor(.primary.opacity(0.85))
                        }
                    }
                }
            } else {
                Text("未找到释义")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            // 例句区域
            if viewModel.isLoadingSentences {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("生成例句...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !viewModel.exampleSentences.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.exampleSentences, id: \.self) { sentence in
                        Text(sentence)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
                }
            }

            // 底部操作按钮
            HStack(spacing: 12) {
                Button("忽略") {
                    viewModel.dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)

                Spacer()

                if viewModel.isAdded {
                    Label("已添加", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button(action: { viewModel.addToVocabulary() }) {
                        Label("加入生词本", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
