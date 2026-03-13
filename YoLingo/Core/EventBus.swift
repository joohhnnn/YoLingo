import Combine
import Foundation

// MARK: - EventBus

/// 全局事件总线，模块间通过发布/订阅事件实现解耦
///
/// 使用方式：
/// ```
/// // 发布事件
/// eventBus.emit(.wordCaptured(result))
///
/// // 订阅事件
/// eventBus.on(AppEvent.self) { event in
///     switch event {
///     case .wordCaptured(let result):
///         // handle
///     default: break
///     }
/// }
/// ```
final class EventBus: @unchecked Sendable {
    private let subject = PassthroughSubject<AppEvent, Never>()

    /// 事件流，供外部订阅
    var publisher: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    /// 发布一个事件
    func emit(_ event: AppEvent) {
        subject.send(event)
    }

    /// 便捷订阅方法，返回 AnyCancellable
    func on(_ handler: @escaping (AppEvent) -> Void) -> AnyCancellable {
        subject.sink(receiveValue: handler)
    }
}
