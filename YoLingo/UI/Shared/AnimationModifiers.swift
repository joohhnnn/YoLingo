import SwiftUI

// MARK: - ShakeEffect

/// 抖动效果（抓词失败时使用）
/// 类似 macOS 密码输入错误的抖动动画
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 5
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

// MARK: - BounceEffect

/// 弹跳效果修饰器（收纳区接收新词时使用）
struct BounceModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.5),
                value: isActive
            )
    }
}

// MARK: - BreathingBorder

/// 呼吸感描边（框选模式使用）
struct BreathingBorder: ViewModifier {
    @State private var opacity: Double = 0.4

    let color: Color
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(opacity), lineWidth: lineWidth)
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 0.7
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// 应用抖动效果
    func shake(amount: CGFloat = 5, trigger: CGFloat) -> some View {
        modifier(ShakeEffect(amount: amount, animatableData: trigger))
    }

    /// 应用弹跳效果
    func bounce(isActive: Bool) -> some View {
        modifier(BounceModifier(isActive: isActive))
    }

    /// 应用呼吸描边
    func breathingBorder(color: Color = .accentColor, lineWidth: CGFloat = 2) -> some View {
        modifier(BreathingBorder(color: color, lineWidth: lineWidth))
    }
}
