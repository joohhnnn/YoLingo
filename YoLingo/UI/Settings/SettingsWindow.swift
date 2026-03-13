// YoLingo/UI/Settings/SettingsWindow.swift
import AppKit
import SwiftUI

// MARK: - SettingsWindow

/// 偏好设置窗口管理
final class SettingsWindow: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        // 窗口还在 → 直接激活
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // 窗口已关闭或不存在 → 重新创建
        window = nil

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "YoLingo - 偏好设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 400, height: 480)
        window.maxSize = CGSize(width: 480, height: CGFloat.greatestFiniteMagnitude)

        let hostingView = NSHostingView(
            rootView: SettingsView(viewModel: viewModel)
        )
        window.contentView = hostingView
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    func close() {
        window?.close()
        window = nil
    }
}
