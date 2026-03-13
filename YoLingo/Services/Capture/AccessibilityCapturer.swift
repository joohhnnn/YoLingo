import AppKit
import Foundation

// MARK: - AccessibilityCapturer

/// 通过 macOS Accessibility API 获取光标下的文字
/// 适用于大部分原生 App（Safari、Mail、TextEdit、Notes 等）
/// 速度最快，精确度最高
///
/// 工作原理：
/// 1. 通过 AXUIElementCopyElementAtPosition 获取鼠标位置下的 AX 元素
/// 2. 用 kAXRangeForPositionParameterizedAttribute 获取鼠标位置对应的字符索引
/// 3. 根据索引向左右扫描提取完整单词
final class AccessibilityCapturer {

    /// 获取指定位置下的单词
    /// - Parameter position: Cocoa 坐标（左下角原点），nil 时从当前鼠标位置读取
    func captureAt(position: CGPoint? = nil) async throws -> CaptureResult {
        // 先检查权限
        guard AXIsProcessTrusted() else {
            NSLog("[AccessibilityCapturer] ❌ 无 Accessibility 权限，跳过")
            throw CaptureError.accessibilityNotAvailable
        }

        // 使用传入的点击坐标或当前鼠标位置（Cocoa 坐标系，左下角原点）
        let cocoaLocation = position ?? NSEvent.mouseLocation
        NSLog("[AccessibilityCapturer] 坐标来源: %@", position != nil ? "传入" : "实时")
        // Accessibility API 使用左上角原点的屏幕坐标系
        // 使用主屏幕高度翻转（AX 坐标系原点 = 主屏幕左上角）
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let screenLocation = CGPoint(
            x: cocoaLocation.x,
            y: primaryScreenHeight - cocoaLocation.y
        )

        NSLog("[AccessibilityCapturer] 尝试抓词 at screen(%@)", "\(screenLocation)")

        // 获取前台应用
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw CaptureError.accessibilityNotAvailable
        }
        let sourceApp = frontApp.localizedName ?? "Unknown"
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Step 1: 获取鼠标位置下的 AX 元素
        var targetElement: AXUIElement?
        let posResult = AXUIElementCopyElementAtPosition(
            appElement,
            Float(screenLocation.x),
            Float(screenLocation.y),
            &targetElement
        )

        guard posResult == .success, let element = targetElement else {
            NSLog("[AccessibilityCapturer] ❌ AXUIElementCopyElementAtPosition 失败: %d", posResult.rawValue)
            throw CaptureError.accessibilityNotAvailable
        }

        // Step 2: 尝试从元素中提取文本并定位单词
        let word = try extractWordFromElement(element, at: screenLocation)
        NSLog("[AccessibilityCapturer] ✅ 抓到单词: \"%@\" (app: %@)", word, sourceApp)

        return CaptureResult(
            text: word,
            sourceApp: sourceApp,
            captureMethod: .accessibility,
            position: cocoaLocation  // UI 动画用 Cocoa 坐标
        )
    }

    // MARK: - Text Extraction

    /// 从 AX 元素中提取鼠标位置处的单词
    private func extractWordFromElement(_ element: AXUIElement, at point: CGPoint) throws -> String {
        // 方案 A：用参数化属性精确定位鼠标位置对应的字符
        if let word = extractWordAtPosition(element, at: point) {
            return word
        }

        // 方案 B：元素有文本内容，尝试用选区或其他方式
        if let word = try? extractWordFromTextField(element, at: point) {
            return word
        }

        // 方案 C：尝试获取 AXTitle 或 AXDescription（按钮、标签等）
        if let title = getStringAttribute(element, attribute: kAXTitleAttribute as CFString) {
            return extractFirstWord(from: title)
        }

        if let description = getStringAttribute(element, attribute: kAXDescriptionAttribute as CFString) {
            return extractFirstWord(from: description)
        }

        throw CaptureError.noTextFound
    }

    /// 使用 AXRangeForPosition 参数化属性精确获取鼠标位置处的单词
    /// 这是最精确的方式：直接用屏幕坐标获取对应的字符索引
    private func extractWordAtPosition(_ element: AXUIElement, at point: CGPoint) -> String? {
        // 获取完整文本
        guard let fullText = getStringAttribute(element, attribute: kAXValueAttribute as CFString),
              !fullText.isEmpty else {
            return nil
        }

        // 用 kAXRangeForPositionParameterizedAttribute 获取鼠标位置对应的字符范围
        // 参数是一个 AXValue 包装的 CGPoint
        var pointValue = point
        guard let axPoint = AXValueCreate(.cgPoint, &pointValue) else { return nil }

        var rangeResult: CFTypeRef?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXRangeForPosition" as CFString,
            axPoint,
            &rangeResult
        )

        if err == .success, let axRange = rangeResult {
            var range = CFRange(location: 0, length: 0)
            if AXValueGetValue(axRange as! AXValue, .cfRange, &range) {
                NSLog("[AccessibilityCapturer] AXRangeForPosition → index=%ld", range.location)
                let word = extractWordAtIndex(range.location, in: fullText)
                if !word.isEmpty {
                    return word
                }
            }
        } else {
            NSLog("[AccessibilityCapturer] AXRangeForPosition 不支持 (err=%d)，尝试其他方式", err.rawValue)
        }

        return nil
    }

    /// 从文本字段中提取单词（fallback：用选区位置或估算）
    private func extractWordFromTextField(_ element: AXUIElement, at point: CGPoint) throws -> String {
        guard let fullText = getStringAttribute(element, attribute: kAXValueAttribute as CFString),
              !fullText.isEmpty else {
            throw CaptureError.noTextFound
        }

        // 方案 1：通过选区位置定位（某些文本框会在点击时更新选区）
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )

        if rangeResult == .success, let cfRange = rangeValue {
            var range = CFRange(location: 0, length: 0)
            if AXValueGetValue(cfRange as! AXValue, .cfRange, &range) {
                NSLog("[AccessibilityCapturer] AXSelectedTextRange → location=%ld", range.location)
                let word = extractWordAtIndex(range.location, in: fullText)
                if !word.isEmpty {
                    return word
                }
            }
        }

        // 方案 2：用元素边界和鼠标位置估算字符索引
        if let charIndex = estimateCharIndexFromPosition(element, at: point, textLength: (fullText as NSString).length) {
            NSLog("[AccessibilityCapturer] 位置估算 → index=%d", charIndex)
            let word = extractWordAtIndex(charIndex, in: fullText)
            if !word.isEmpty {
                return word
            }
        }

        // 方案 3：尝试获取选中的文本
        if let selectedText = getStringAttribute(element, attribute: kAXSelectedTextAttribute as CFString),
           !selectedText.isEmpty {
            return extractFirstWord(from: selectedText)
        }

        // 兜底
        return extractFirstWord(from: fullText)
    }

    /// 根据鼠标在元素中的相对水平位置估算字符索引
    /// 假设文本均匀分布在元素宽度内（粗略但比取第一个词好）
    private func estimateCharIndexFromPosition(_ element: AXUIElement, at point: CGPoint, textLength: Int) -> Int? {
        // 获取元素的位置和大小
        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        let posErr = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        let sizeErr = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

        guard posErr == .success, sizeErr == .success,
              let axPos = positionValue, let axSize = sizeValue else {
            return nil
        }

        var elementOrigin = CGPoint.zero
        var elementSize = CGSize.zero
        AXValueGetValue(axPos as! AXValue, .cgPoint, &elementOrigin)
        AXValueGetValue(axSize as! AXValue, .cgSize, &elementSize)

        guard elementSize.width > 0 else { return nil }

        // 鼠标在元素内的相对水平位置 (0.0 ~ 1.0)
        let relativeX = (point.x - elementOrigin.x) / elementSize.width
        let clampedX = max(0.0, min(1.0, relativeX))

        // 估算字符索引
        return Int(clampedX * CGFloat(textLength))
    }

    // MARK: - Word Extraction Helpers

    /// 从文本中的指定字符索引位置提取完整单词
    /// 支持连字符词（如 well-known）：遇到连字符时继续扫描
    private func extractWordAtIndex(_ index: Int, in text: String) -> String {
        let nsText = text as NSString
        guard nsText.length > 0 else { return "" }

        // 边界检查
        let safeIndex = max(0, min(index, nsText.length - 1))

        // 判断字符是否属于单词（字母 + 连字符，连字符两侧必须是字母）
        func isWordChar(at i: Int) -> Bool {
            guard i >= 0 && i < nsText.length else { return false }
            let c = nsText.character(at: i)
            if CharacterSet.letters.contains(UnicodeScalar(c)!) { return true }
            // 连字符：只有两侧都是字母时才算词内字符
            if c == 0x2D { // '-'
                let hasPrev = i > 0 && CharacterSet.letters.contains(UnicodeScalar(nsText.character(at: i - 1))!)
                let hasNext = i + 1 < nsText.length && CharacterSet.letters.contains(UnicodeScalar(nsText.character(at: i + 1))!)
                return hasPrev && hasNext
            }
            return false
        }

        // 向左扫描到单词边界
        var wordStart = safeIndex
        while wordStart > 0 && isWordChar(at: wordStart - 1) {
            wordStart -= 1
        }

        // 向右扫描到单词边界
        var wordEnd = safeIndex
        while wordEnd < nsText.length && isWordChar(at: wordEnd) {
            wordEnd += 1
        }

        guard wordEnd > wordStart else {
            return ""
        }

        let wordRange = NSRange(location: wordStart, length: wordEnd - wordStart)
        return nsText.substring(with: wordRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 从文本中提取第一个英文单词（最后兜底，支持连字符词）
    private func extractFirstWord(from text: String) -> String {
        let pattern = "[a-zA-Z](?:[a-zA-Z-]*[a-zA-Z])?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              let range = Range(match.range, in: text) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text[range])
    }

    // MARK: - AX Attribute Helpers

    /// 获取 AX 元素的字符串属性
    private func getStringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let str = value as? String, !str.isEmpty else {
            return nil
        }
        return str
    }

    // MARK: - Permission

    static func hasPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
