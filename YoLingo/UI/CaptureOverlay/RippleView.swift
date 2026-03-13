import SwiftUI

// MARK: - RippleView

/// 抓词点击瞬间的涟漪扩散效果
struct RippleView: View {

    let position: CGPoint
    let isSuccess: Bool

    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0.6

    private var rippleColor: Color {
        isSuccess ? .accentColor : .red
    }

    var body: some View {
        Circle()
            .stroke(rippleColor, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                    opacity = 0.0
                }
            }
            .allowsHitTesting(false)
    }
}
