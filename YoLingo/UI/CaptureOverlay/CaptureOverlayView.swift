import SwiftUI

// MARK: - CaptureOverlayView

/// 抓词覆盖层的根视图
/// 根据 ViewModel 的动画状态切换显示不同动效组件
struct CaptureOverlayView: View {

    @ObservedObject var viewModel: CaptureOverlayViewModel

    var body: some View {
        ZStack {
            // Phase 1: 光晕（fn 按下时跟随光标）
            if viewModel.animationState == .activated {
                HaloView(
                    isActive: true,
                    position: viewModel.mousePosition
                )
            }

            // Phase 2: 涟漪（点击抓词瞬间）
            if viewModel.animationState == .rippling {
                RippleView(
                    position: viewModel.capturePosition,
                    isSuccess: true
                )
            }

            // Phase 3: 飞行收纳（抓词成功）
            if viewModel.animationState == .flying,
               let word = viewModel.capturedText {
                WordFlyView(
                    word: word,
                    startPosition: viewModel.capturePosition,
                    endPosition: viewModel.targetPosition,
                    onComplete: { viewModel.onFlyAnimationComplete() }
                )
            }

            // Phase 4: 失败抖动
            if viewModel.animationState == .failed {
                RippleView(
                    position: viewModel.capturePosition,
                    isSuccess: false
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
