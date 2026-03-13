import Foundation

// MARK: - CaptureServiceProtocol

/// 抓词服务协议
/// 负责从屏幕上获取用户指向/选中的文字
protocol CaptureServiceProtocol {
    /// 抓取指定位置的单词（fn + 单击模式）
    /// - Parameter position: 点击瞬间的 Cocoa 坐标（左下角原点），nil 时从当前鼠标位置读取
    func captureWord(at position: CGPoint?) async throws -> CaptureResult

    /// 抓取指定区域的文字（fn + 拖选模式）
    func captureWordsInRegion(_ rect: CGRect) async throws -> CaptureResult

    /// 开始监听 fn 键
    func startListening()

    /// 停止监听 fn 键
    func stopListening()
}
