import AppKit
import Foundation
import Vision

// MARK: - OCRCapturer

/// 通过小区域截图 + Vision OCR 获取文字
/// 作为 Accessibility API 的兜底方案
/// 适用于不支持 Accessibility 的应用（部分 Electron App、图片中的文字等）
final class OCRCapturer {

    /// OCR 截图区域大小（需要足够大以包含光标附近的完整单词）
    private let captureSize: CGSize

    init(captureSize: CGSize = CGSize(width: 400, height: 100)) {
        self.captureSize = captureSize
    }

    /// 获取指定位置周围的文字
    /// - Parameter position: Cocoa 坐标（左下角原点），nil 时从当前鼠标位置读取
    func captureAt(position: CGPoint? = nil) async throws -> CaptureResult {
        let mouseLocation = position ?? NSEvent.mouseLocation
        NSLog("[OCRCapturer] 抓词位置 (Cocoa): %@ %@", "\(mouseLocation)", position != nil ? "(传入)" : "(实时)")

        let captureRect = captureRectAroundPoint(mouseLocation)
        NSLog("[OCRCapturer] 截图区域 (Screen): %@", "\(captureRect)")

        // 截图 + OCR
        guard let screenshot = captureScreenRegion(captureRect) else {
            NSLog("[OCRCapturer] ❌ 截图失败（可能需要 Screen Recording 权限）")
            throw CaptureError.ocrFailed
        }
        NSLog("[OCRCapturer] 截图成功: %dx%d", screenshot.width, screenshot.height)

        let observations = try await recognizeTextObservations(in: screenshot)
        NSLog("[OCRCapturer] OCR 识别到 %d 个文本区域", observations.count)
        for (i, obs) in observations.prefix(5).enumerated() {
            if let text = obs.topCandidates(1).first?.string {
                NSLog("[OCRCapturer]   [%d] \"%@\" box=%@", i, text, "\(obs.boundingBox)")
            }
        }

        guard !observations.isEmpty else {
            throw CaptureError.noTextFound
        }

        // 光标在截图区域内的相对位置（归一化到 0~1，Vision 坐标系左下原点）
        let relativeX = 0.5  // 光标在截图中心
        let relativeY = 0.5

        // 从 OCR 结果中提取光标最近的单词
        let word = extractWordNearCursor(
            observations: observations,
            cursorX: relativeX,
            cursorY: relativeY
        )

        guard let word = word, !word.isEmpty else {
            NSLog("[OCRCapturer] ❌ 未能从 OCR 结果中提取有效单词")
            throw CaptureError.noTextFound
        }

        NSLog("[OCRCapturer] ✅ 提取单词: \"%@\"", word)
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"

        return CaptureResult(
            text: word,
            sourceApp: sourceApp,
            captureMethod: .ocr,
            position: mouseLocation  // 原始 Cocoa 坐标，用于浮窗定位和动画
        )
    }

    /// 获取指定区域内的文字（框选模式）
    func captureInRegion(_ rect: CGRect) async throws -> CaptureResult {
        guard let screenshot = captureScreenRegion(rect) else {
            throw CaptureError.ocrFailed
        }

        let observations = try await recognizeTextObservations(in: screenshot)
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")

        guard !text.isEmpty else {
            throw CaptureError.noTextFound
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"

        return CaptureResult(
            text: text,
            sourceApp: sourceApp,
            captureMethod: .ocr,
            position: CGPoint(x: rect.midX, y: rect.midY)
        )
    }

    // MARK: - Private

    /// 计算光标周围的截图区域
    /// CGWindowListCreateImage 使用全局屏幕坐标（左上原点，主屏幕左上角为 (0,0)）
    private func captureRectAroundPoint(_ point: CGPoint) -> CGRect {
        // NSEvent.mouseLocation 是 Cocoa 坐标（左下原点）
        // CGWindowListCreateImage 使用 Quartz 坐标（左上原点）
        // 主屏幕的 frame.maxY 就是全局坐标系的翻转基准
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
        let flippedY = primaryScreenHeight - point.y
        return CGRect(
            x: point.x - captureSize.width / 2,
            y: flippedY - captureSize.height / 2,
            width: captureSize.width,
            height: captureSize.height
        )
    }

    /// 截取屏幕指定区域
    private func captureScreenRegion(_ rect: CGRect) -> CGImage? {
        let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )

        // 调试：将截图保存到 /tmp 供检查（确认 Screen Recording 权限是否生效）
        #if DEBUG
        if let image = image {
            let url = URL(fileURLWithPath: "/tmp/yolingo_ocr_debug.png")
            if let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, image, nil)
                CGImageDestinationFinalize(dest)
                NSLog("[OCRCapturer] 🔍 调试截图已保存到 /tmp/yolingo_ocr_debug.png")
            }
        }
        #endif

        return image
    }

    /// 使用 Vision 框架识别图片中的文字，返回 observations 以便后续定位
    private func recognizeTextObservations(in image: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: observations)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en"]  // MVP 仅英语
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 从 OCR 结果中提取离光标最近的英文单词
    ///
    /// Vision 的 boundingBox 使用归一化坐标（0~1），原点在左下角。
    /// 光标在截图中心 (0.5, 0.5)。
    /// 丢弃紧贴截图边缘的单词（大概率被截断）。
    private func extractWordNearCursor(
        observations: [VNRecognizedTextObservation],
        cursorX: Double,
        cursorY: Double
    ) -> String? {
        // 边缘阈值：归一化坐标中距离边缘 < 3% 的单词视为可能截断
        let edgeMargin = 0.03
        var bestWord: String?
        var bestDistance = Double.greatestFiniteMagnitude

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let fullText = candidate.string

            // 将文本按单词拆分（保留连字符词如 well-known）
            let words = fullText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            for word in words {
                // 保留英文单词（至少 2 个字母，允许连字符）
                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                guard cleaned.count >= 2,
                      cleaned.range(of: "^[a-zA-Z]([a-zA-Z-]*[a-zA-Z])?$", options: .regularExpression) != nil else {
                    continue
                }

                // 获取该单词在图像中的 bounding box
                if let wordRange = candidate.string.range(of: word),
                   let wordBox = try? candidate.boundingBox(for: wordRange) {
                    let box = wordBox.boundingBox

                    // 丢弃紧贴截图左右边缘的单词（大概率被截断）
                    if box.minX < edgeMargin || box.maxX > (1.0 - edgeMargin) {
                        NSLog("[OCRCapturer] ⚠️ 跳过边缘单词 \"%@\" (box.x: %.3f~%.3f)", cleaned, box.minX, box.maxX)
                        continue
                    }

                    let centerX = box.midX
                    let centerY = box.midY
                    let distance = hypot(centerX - cursorX, centerY - cursorY)

                    if distance < bestDistance {
                        bestDistance = distance
                        bestWord = cleaned
                    }
                } else {
                    // 无法获取单词级 bounding box，用整个 observation 的位置
                    let box = observation.boundingBox
                    let centerX = box.midX
                    let centerY = box.midY
                    let distance = hypot(centerX - cursorX, centerY - cursorY)

                    if distance < bestDistance {
                        bestDistance = distance
                        bestWord = cleaned
                    }
                }
            }
        }

        return bestWord
    }
}
