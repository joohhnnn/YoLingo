import AppKit
import Combine
import Foundation

// MARK: - CaptureOverlayViewModel

/// 管理抓词覆盖层的状态（光晕、涟漪、飞行动画）
///
/// 坐标系说明：所有 Published 的位置属性均使用 SwiftUI 坐标系（左上角原点），
/// 因为 CaptureOverlayWindow 是全屏覆盖层，SwiftUI 坐标 = 屏幕左上角原点坐标。
/// EventBus 传入的 Cocoa 坐标（左下角原点）在此处统一转换。
@MainActor
final class CaptureOverlayViewModel: ObservableObject {

    // MARK: - Published State

    /// 当前动画阶段
    @Published var animationState: CaptureAnimationState = .idle

    /// fn 是否按下
    @Published var isActive: Bool = false

    /// 鼠标当前位置（SwiftUI 坐标，驱动光晕跟随）
    @Published var mousePosition: CGPoint = .zero

    /// 抓取到的文字（用于飞行动画中显示）
    @Published var capturedText: String?

    /// 涟漪/飞行动画的起始位置（SwiftUI 坐标）
    @Published var capturePosition: CGPoint = .zero

    /// 悬浮卡片位置（飞行动画的终点）
    @Published var targetPosition: CGPoint = .zero

    // MARK: - Dependencies

    private let captureService: CaptureServiceProtocol
    private let eventBus: EventBus
    private var cancellables = Set<AnyCancellable>()

    // 鼠标追踪
    private var mouseMonitor: Any?

    // MARK: - Init

    init(captureService: CaptureServiceProtocol, eventBus: EventBus) {
        self.captureService = captureService
        self.eventBus = eventBus
        subscribeToEvents()
    }

    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Actions

    /// 飞行动画完成后的回调
    func onFlyAnimationComplete() {
        animationState = .idle
        capturedText = nil
    }

    // MARK: - Private

    /// Cocoa 坐标（左下原点）→ 覆盖层 SwiftUI 坐标（左上原点）
    /// 覆盖层窗口是所有屏幕的 union frame，SwiftUI 坐标 = union 区域内的左上原点
    private func cocoaToSwiftUI(_ cocoaPoint: CGPoint) -> CGPoint {
        let unionFrame = NSScreen.screens.reduce(CGRect.zero) { result, screen in
            result == .zero ? screen.frame : result.union(screen.frame)
        }
        // Cocoa Y 轴翻转 + 相对于 union frame 原点偏移
        return CGPoint(
            x: cocoaPoint.x - unionFrame.origin.x,
            y: unionFrame.maxY - cocoaPoint.y
        )
    }

    /// 启动鼠标位置追踪（fn 激活时开始，松开时停止）
    private func startMouseTracking() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self = self else { return }
            let cocoaLocation = NSEvent.mouseLocation
            let swiftUILocation = self.cocoaToSwiftUI(cocoaLocation)
            Task { @MainActor in
                self.mousePosition = swiftUILocation
            }
        }
        // 立即更新当前位置
        mousePosition = cocoaToSwiftUI(NSEvent.mouseLocation)
    }

    private func stopMouseTracking() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func subscribeToEvents() {
        eventBus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .captureActivated:
                    self.isActive = true
                    self.animationState = .activated
                    self.startMouseTracking()

                case .captureDeactivated:
                    self.isActive = false
                    self.stopMouseTracking()
                    if self.animationState == .activated {
                        self.animationState = .idle
                    }

                case .captureClicked(let cocoaPosition):
                    // fn+点击 → 涟漪动画
                    self.capturePosition = self.cocoaToSwiftUI(cocoaPosition)
                    self.animationState = .rippling

                case .wordCaptured(let result):
                    // 抓词成功 → 飞行动画
                    if self.animationState == .rippling {
                        self.capturedText = result.text
                        self.animationState = .flying
                    }

                case .captureFailed:
                    // 抓词失败 → 红色抖动
                    if self.animationState == .rippling {
                        self.animationState = .failed
                        Task {
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            self.animationState = .idle
                        }
                    }

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - CaptureAnimationState

/// 抓词动效的状态机
enum CaptureAnimationState: Equatable {
    case idle       // 无状态
    case activated  // fn 按下，显示光晕
    case rippling   // 点击后涟漪扩散
    case flying     // 单词飞向收纳区
    case failed     // 抓取失败，红色抖动
}
