import AppKit
import SwiftUI

// MARK: - CaptureOverlayWindow

/// 抓词覆盖层窗口管理
/// 为每个屏幕创建一个透明全屏 NSPanel，用于显示光晕、涟漪和飞行动画
/// 窗口不接收点击事件（ignoresMouseEvents），不影响用户正常操作
final class CaptureOverlayWindow {

    private var panels: [NSPanel] = []
    private let viewModel: CaptureOverlayViewModel

    init(viewModel: CaptureOverlayViewModel) {
        self.viewModel = viewModel
    }

    /// 为所有屏幕创建并显示覆盖层
    func show() {
        guard panels.isEmpty else { return }

        // 计算所有屏幕合并后的总区域（全局 Cocoa 坐标系）
        let unionFrame = NSScreen.screens.reduce(CGRect.zero) { result, screen in
            result == .zero ? screen.frame : result.union(screen.frame)
        }
        guard !unionFrame.isEmpty else { return }

        // 创建一个跨所有屏幕的巨大 panel
        let panel = NSPanel(
            contentRect: unionFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(
            rootView: CaptureOverlayView(viewModel: viewModel)
        )
        panel.contentView = hostingView

        panel.orderFrontRegardless()
        panels.append(panel)
    }

    /// 隐藏所有覆盖层
    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}
