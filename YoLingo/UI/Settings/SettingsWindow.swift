// YoLingo/UI/Settings/SettingsWindow.swift
import AppKit
import SwiftUI

// MARK: - SettingsWindow

/// 偏好设置窗口管理
final class SettingsWindow {

    private var window: NSWindow?
    private let viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func close() {
        window?.close()
        window = nil
    }
}
