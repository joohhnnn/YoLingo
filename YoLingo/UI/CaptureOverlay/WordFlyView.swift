import SwiftUI

// MARK: - WordFlyView

/// 抓词成功后单词飞向收纳区的动画
/// 沿贝塞尔弧线飞行，到达时缩小淡出
struct WordFlyView: View {

    let word: String
    let startPosition: CGPoint
    let endPosition: CGPoint
    var onComplete: (() -> Void)?

    @State private var progress: CGFloat = 0

    /// 贝塞尔弧线上的当前位置
    private var currentPosition: CGPoint {
        let t = progress
        // 控制点在起终点中间偏上，形成上弧轨迹
        let controlPoint = CGPoint(
            x: (startPosition.x + endPosition.x) / 2,
            y: min(startPosition.y, endPosition.y) - 50
        )
        let x = pow(1 - t, 2) * startPosition.x
            + 2 * (1 - t) * t * controlPoint.x
            + pow(t, 2) * endPosition.x
        let y = pow(1 - t, 2) * startPosition.y
            + 2 * (1 - t) * t * controlPoint.y
            + pow(t, 2) * endPosition.y
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        Text(word)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.85)))
            .foregroundColor(.white)
            .position(currentPosition)
            .scaleEffect(1.0 - progress * 0.4)
            .opacity(1.0 - progress * 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4)) {
                    progress = 1.0
                }
                // 动画完成后回调
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onComplete?()
                }
            }
            .allowsHitTesting(false)
    }
}
