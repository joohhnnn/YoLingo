import AppKit
import Combine
import SwiftUI

// MARK: - CapturePopoverWindow

/// 抓词浮窗的窗口管理
/// 抓词成功后在鼠标位置附近弹出，显示释义和操作按钮
/// 用户点击「忽略」或点击浮窗外部时自动关闭
final class CapturePopoverWindow {

    private var panel: NSPanel?
    private let viewModel: CapturePopoverViewModel
    private var clickMonitor: Any?
    private var dismissCancellable: AnyCancellable?

    @MainActor
    init(viewModel: CapturePopoverViewModel) {
        self.viewModel = viewModel
        // 监听 ViewModel 的 dismiss 信号（capturedText 变为空时关闭浮窗）
        dismissCancellable = viewModel.$capturedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                if text.isEmpty {
                    self?.hide()
                }
            }
    }

    /// 在指定位置显示浮窗
    /// - Parameter point: Cocoa 坐标系（左下角原点）
    func show(near point: CGPoint) {
        // 先清理已有的浮窗和监听器
        hide()

        let panelSize = CGSize(width: 320, height: 260)

        // 找到鼠标所在的屏幕（而非固定用主屏幕）
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
        guard let screen = screen else { return }

        // Cocoa 坐标系：Y 向上增长，origin 是窗口左下角
        // 浮窗默认放在鼠标下方偏右（y 减小 = 向下）
        var origin = CGPoint(
            x: point.x + 10,
            y: point.y - panelSize.height - 10
        )

        // 确保不超出屏幕边界
        let visibleFrame = screen.visibleFrame
        if origin.x + panelSize.width > visibleFrame.maxX {
            origin.x = point.x - panelSize.width - 10  // 右侧超出 → 改为左侧
        }
        if origin.x < visibleFrame.minX {
            origin.x = visibleFrame.minX  // 左侧超出 → 贴左边
        }
        if origin.y < visibleFrame.minY {
            origin.y = point.y + 20  // 下方超出 → 改为上方
        }
        if origin.y + panelSize.height > visibleFrame.maxY {
            origin.y = visibleFrame.maxY - panelSize.height  // 上方超出 → 贴顶
        }

        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces]

        let hostingView = NSHostingView(
            rootView: CapturePopoverView(viewModel: viewModel)
        )
        panel.contentView = hostingView

        panel.hidesOnDeactivate = false
        panel.orderFrontRegardless()
        self.panel = panel

        setupOutsideClickMonitor()
    }

    /// 隐藏浮窗
    func hide() {
        removeOutsideClickMonitor()
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Private

    private func setupOutsideClickMonitor() {
        // 先清理避免泄漏
        removeOutsideClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let panel = self?.panel else { return }
            let clickLocation = NSEvent.mouseLocation
            if !panel.frame.contains(clickLocation) {
                self?.hide()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    deinit {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
