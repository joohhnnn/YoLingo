import AppKit
import Foundation

// MARK: - CaptureService

/// 抓词服务的具体实现
/// 内部封装 OCR 优先 + Accessibility 兜底的分层策略
/// OCR 通过截图+Vision定位光标最近的词，位置精确不漂移
/// Accessibility API 在部分应用中字符索引不准确，作为兜底
/// 外部调用者不感知具体使用了哪种方式
final class CaptureService: CaptureServiceProtocol {

    private let accessibilityCapturer: AccessibilityCapturer
    private let ocrCapturer: OCRCapturer
    private let eventBus: EventBus
    private let fnKeyMonitor: FnKeyMonitor

    init(
        accessibilityCapturer: AccessibilityCapturer,
        ocrCapturer: OCRCapturer,
        eventBus: EventBus
    ) {
        self.accessibilityCapturer = accessibilityCapturer
        self.ocrCapturer = ocrCapturer
        self.eventBus = eventBus
        self.fnKeyMonitor = FnKeyMonitor()

        setupFnKeyCallbacks()
    }

    // MARK: - CaptureServiceProtocol

    func captureWord(at position: CGPoint?) async throws -> CaptureResult {
        NSLog("[CaptureService] 开始抓词... position=%@", position != nil ? "\(position!)" : "nil(实时)")

        // 策略 1：优先使用 OCR（截图+Vision，光标定位精确，不漂移）
        do {
            let result = try await ocrCapturer.captureAt(position: position)
            NSLog("[CaptureService] ✅ OCR 抓词成功: \"%@\" (app: %@)", result.text, result.sourceApp)
            eventBus.emit(.wordCaptured(result))
            return result
        } catch {
            NSLog("[CaptureService] ⚠️ OCR 抓词失败: %@", "\(error)")
        }

        // 策略 2：兜底使用 Accessibility API（部分应用中字符索引可能漂移）
        do {
            NSLog("[CaptureService] 尝试 Accessibility 兜底...")
            let result = try await accessibilityCapturer.captureAt(position: position)
            NSLog("[CaptureService] ✅ Accessibility 抓词成功: \"%@\" (app: %@)", result.text, result.sourceApp)
            eventBus.emit(.wordCaptured(result))
            return result
        } catch {
            NSLog("[CaptureService] ❌ Accessibility 抓词也失败: %@", "\(error)")
            let captureError = CaptureError.noTextFound
            eventBus.emit(.captureFailed(captureError))
            throw captureError
        }
    }

    func captureWordsInRegion(_ rect: CGRect) async throws -> CaptureResult {
        // 框选模式直接走 OCR
        do {
            let result = try await ocrCapturer.captureInRegion(rect)
            eventBus.emit(.wordCaptured(result))
            return result
        } catch {
            let captureError = CaptureError.ocrFailed
            eventBus.emit(.captureFailed(captureError))
            throw captureError
        }
    }

    func startListening() {
        fnKeyMonitor.start()
    }

    func stopListening() {
        fnKeyMonitor.stop()
    }

    // MARK: - Private

    /// 将 FnKeyMonitor 的回调接入 EventBus 和抓词逻辑
    private func setupFnKeyCallbacks() {
        fnKeyMonitor.onFnDown = { [weak self] in
            NSLog("[CaptureService] 📡 fn 按下 → 发送 captureActivated")
            self?.eventBus.emit(.captureActivated)
        }

        fnKeyMonitor.onFnUp = { [weak self] in
            NSLog("[CaptureService] 📡 fn 松开 → 发送 captureDeactivated")
            self?.eventBus.emit(.captureDeactivated)
        }

        fnKeyMonitor.onClickWhileFnHeld = { [weak self] position in
            guard let self = self else { return }
            NSLog("[CaptureService] 📡 fn+点击 → 发送 captureClicked(%@)", "\(position)")
            // fn + 点击 → 先通知 UI 开始动画，再用点击瞬间的坐标触发抓词
            self.eventBus.emit(.captureClicked(position))
            Task {
                do {
                    _ = try await self.captureWord(at: position)
                } catch {
                    NSLog("[CaptureService] ❌ 抓词最终失败: %@", "\(error)")
                }
            }
        }
    }
}
