import SwiftUI

// MARK: - HaloView

/// 抓词模式激活时的光标光晕
/// fn 按下后出现，跟随鼠标移动，半透明不遮挡内容
struct HaloView: View {

    let isActive: Bool
    let position: CGPoint

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(0.25),
                        Color.accentColor.opacity(0.0)
                    ]),
                    center: .center,
                    startRadius: 5,
                    endRadius: 30
                )
            )
            .frame(width: 60, height: 60)
            .position(position)
            .scaleEffect(isActive ? 1.0 : 0.3)
            .opacity(isActive ? 1.0 : 0.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isActive)
            .allowsHitTesting(false)
    }
}
