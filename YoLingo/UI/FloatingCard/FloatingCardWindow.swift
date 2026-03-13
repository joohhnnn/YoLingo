import AppKit
import SwiftUI

// MARK: - FloatingCardWindow

/// 桌面悬浮卡片窗口管理
/// 常驻桌面角落，可拖动，可收缩为小气泡
final class FloatingCardWindow {

    private var panel: NSPanel?
    private let viewModel: FloatingCardViewModel

    /// 卡片尺寸
    private let cardSize = CGSize(width: 280, height: 160)
    private let bubbleSize = CGSize(width: 44, height: 44)

    init(viewModel: FloatingCardViewModel) {
        self.viewModel = viewModel
    }

    /// 显示悬浮卡片
    func show(at position: FloatingCardPosition = .bottomRight) {
        guard panel == nil, let screen = NSScreen.main else { return }

        let origin = calculateOrigin(for: position, screen: screen)

        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: cardSize),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true  // 可拖动
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(
            rootView: FloatingCardView(viewModel: viewModel)
        )
        panel.contentView = hostingView

        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// 隐藏悬浮卡片
    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// 获取卡片在屏幕上的位置（用于飞行动画终点）
    var windowPosition: CGPoint {
        guard let frame = panel?.frame else { return .zero }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: - Private

    private func calculateOrigin(for position: FloatingCardPosition, screen: NSScreen) -> CGPoint {
        let padding: CGFloat = 20
        let visibleFrame = screen.visibleFrame

        switch position {
        case .bottomRight:
            return CGPoint(
                x: visibleFrame.maxX - cardSize.width - padding,
                y: visibleFrame.minY + padding
            )
        case .bottomLeft:
            return CGPoint(
                x: visibleFrame.minX + padding,
                y: visibleFrame.minY + padding
            )
        case .topRight:
            return CGPoint(
                x: visibleFrame.maxX - cardSize.width - padding,
                y: visibleFrame.maxY - cardSize.height - padding
            )
        case .topLeft:
            return CGPoint(
                x: visibleFrame.minX + padding,
                y: visibleFrame.maxY - cardSize.height - padding
            )
        }
    }
}
