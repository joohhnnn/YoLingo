import AppKit
import SwiftUI

// MARK: - ReviewWindow

/// 深度复习窗口管理
final class ReviewWindow {

    private var window: NSWindow?
    private let viewModel: ReviewViewModel

    init(viewModel: ReviewViewModel) {
        self.viewModel = viewModel
    }

    /// 打开复习窗口
    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "YoLingo - 复习"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 400, height: 500)

        let hostingView = NSHostingView(
            rootView: ReviewView(viewModel: viewModel)
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    /// 关闭复习窗口
    func close() {
        window?.close()
        window = nil
    }
}
