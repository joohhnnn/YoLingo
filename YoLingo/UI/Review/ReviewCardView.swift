import SwiftUI

// MARK: - ReviewCardView

/// 复习界面中的翻转卡片
struct ReviewCardView: View {

    let word: WordEntry
    let isFlipped: Bool

    var body: some View {
        ZStack {
            // 正面：单词
            frontFace
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? -90 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            // 背面：释义 + 例句
            backFace
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : 90),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFlipped)
    }

    // MARK: - Front Face

    private var frontFace: some View {
        VStack(spacing: 16) {
            Spacer()

            Text(word.word)
                .font(.largeTitle)
                .fontWeight(.bold)

            if let phonetic = word.phonetic {
                Text(phonetic)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("点击翻转查看释义")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    // MARK: - Back Face

    private var backFace: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 单词 + 音标
            HStack {
                Text(word.word)
                    .font(.title2)
                    .fontWeight(.semibold)
                if let phonetic = word.phonetic {
                    Text(phonetic)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            // 释义
            Text(word.definition)
                .font(.body)

            // 例句
            if !word.exampleSentences.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("例句")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)

                    ForEach(word.exampleSentences, id: \.self) { sentence in
                        Text(sentence)
                            .font(.callout)
                            .foregroundColor(.primary.opacity(0.8))
                            .italic()
                    }
                }
            }

            Spacer()

            // 来源标记
            HStack {
                Image(systemName: "app.badge")
                    .font(.caption2)
                Text("\(word.sourceApp) · \(word.capturedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
}
