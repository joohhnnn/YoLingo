import AppKit
import Carbon
import Foundation
import IOKit
import IOKit.hid

// MARK: - FnKeyMonitor

/// 全局 fn 键监听器
///
/// 三层策略检测 fn/Globe 键（Apple Silicon Mac 兼容）：
/// 1. CGEvent Tap：监听 flagsChanged 事件，提取 keyCode 判断 fn 键状态
///    — 参考 Typeless 方案：用 CGEventGetIntegerValueField 获取 keyCode（63=fn, 179=Globe）
///    — 同时监听 leftMouseDown 实现 fn+点击抓词
/// 2. IOHIDManager：HID 驱动层监听 Apple Vendor Top Case 的 fn 键事件
///    — 在 CGEvent Tap 被系统拦截时作为补充
/// 3. NSEvent.addGlobalMonitorForEvents：应用层兜底
///
/// 需要权限：Accessibility + Input Monitoring
final class FnKeyMonitor {

    // MARK: - Callbacks

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?
    var onClickWhileFnHeld: ((CGPoint) -> Void)?

    // MARK: - State

    private(set) var isFnHeld: Bool = false

    // fn 键的 keyCode 常量
    private static let fnKeyCode: Int64 = 0x3F      // 63 — 标准 fn 键
    private static let globeKeyCode: Int64 = 0xB3    // 179 — Globe 键变体

    // CGEvent Tap
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // IOHIDManager
    private var hidManager: IOHIDManager?

    // NSEvent 全局监听（兜底）
    private var globalFlagsMonitor: Any?
    private var globalClickMonitor: Any?

    // 防止多源重复触发
    private var lastFnChangeTime: UInt64 = 0

    // MARK: - Lifecycle

    func start() {
        NSLog("[FnKeyMonitor] 正在启动 fn 键监听...")

        // 1. CGEvent Tap（主通道 — 参照 Typeless 方案）
        startEventTap()

        // 2. IOHIDManager（HID 层补充）
        startHIDMonitor()

        // 3. NSEvent 全局监听（兜底）
        startNSEventMonitor()
    }

    func stop() {
        stopEventTap()
        stopHIDMonitor()
        stopNSEventMonitor()
        isFnHeld = false
    }

    deinit {
        stop()
    }

    // MARK: - fn 键状态变更（统一入口）

    /// 所有检测通道都通过此方法更新 fn 键状态，内置去重
    private func setFnState(_ pressed: Bool, source: String) {
        // 防抖：50ms 内的重复事件忽略
        let now = mach_absolute_time()
        let elapsed = now - lastFnChangeTime
        // mach_absolute_time 单位转换：简化按 ~1ns/tick 估算，50ms ≈ 50_000_000
        if elapsed < 50_000_000 && isFnHeld == pressed { return }

        if pressed && !isFnHeld {
            isFnHeld = true
            lastFnChangeTime = now
            NSLog("[FnKeyMonitor] 🔽 fn 键按下 (%@)", source)
            DispatchQueue.main.async { [weak self] in
                self?.onFnDown?()
            }
        } else if !pressed && isFnHeld {
            isFnHeld = false
            lastFnChangeTime = now
            NSLog("[FnKeyMonitor] 🔼 fn 键松开 (%@)", source)
            DispatchQueue.main.async { [weak self] in
                self?.onFnUp?()
            }
        }
    }

    // MARK: - 1. CGEvent Tap（主通道）

    private func startEventTap() {
        guard eventTap == nil else { return }

        NSLog("[FnKeyMonitor] Accessibility 权限: %@", AXIsProcessTrusted() ? "✅ 已授权" : "❌ 未授权")

        if !AXIsProcessTrusted() {
            NSLog("[FnKeyMonitor] ❌ 需要辅助功能权限")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }

        // 只监听 flagsChanged + leftMouseDown
        // 不再监听 keyDown：功能键(方向键/Delete 等)的 keyDown 会携带 maskSecondaryFn，
        // 导致误判 fn 被按下
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue)

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: fnKeyEventCallback,
            userInfo: selfPointer
        ) else {
            NSLog("[FnKeyMonitor] ❌ 无法创建 CGEvent Tap")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source

        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[FnKeyMonitor] ✅ CGEvent Tap 启动成功")
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// 处理 CGEvent Tap 收到的事件
    fileprivate func handleCGEvent(_ type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .leftMouseDown:
            handleMouseDown(event)
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        // 参照 Typeless：从 flagsChanged 事件中提取 keyCode
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let rawFlags = flags.rawValue

        // 首次收到 flagsChanged 时打印诊断信息
        NSLog("[FnKeyMonitor] flagsChanged: keyCode=%lld flags=0x%llx", keyCode, rawFlags)

        // 只处理 fn/Globe 键的 keyCode，不再做 maskSecondaryFn 兜底
        // 兜底逻辑会被功能键(方向键/Delete 等)触发误判
        if keyCode == FnKeyMonitor.fnKeyCode || keyCode == FnKeyMonitor.globeKeyCode {
            let fnFlagSet = (rawFlags & 0x800000) != 0
            setFnState(fnFlagSet, source: "CGEvent keyCode=\(keyCode)")
        }
        // 其他 keyCode 的 flagsChanged 不处理（由 HID/NSEvent 兜底）
    }

    private func handleMouseDown(_ event: CGEvent) {
        guard isFnHeld else { return }

        // CGEvent.location 是屏幕坐标（左上原点），统一转为 Cocoa 坐标（左下原点）
        // CGEvent 坐标系原点 = 主屏幕左上角
        let screenLocation = event.location
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoaLocation = CGPoint(x: screenLocation.x, y: primaryScreenHeight - screenLocation.y)
        NSLog("[FnKeyMonitor] 🖱️ fn+点击 at %@ (CGEvent, Cocoa坐标)", "\(cocoaLocation)")
        DispatchQueue.main.async { [weak self] in
            self?.onClickWhileFnHeld?(cocoaLocation)
        }
    }

    // MARK: - 2. IOHIDManager（HID 层补充）

    private func startHIDMonitor() {
        guard hidManager == nil else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        // 匹配 Apple 内置键盘的 Top Case（fn/Globe 键所在的 HID 设备）
        let matchingCriteria: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey as String: 0x00FF,  // AppleVendorTopCase
                kIOHIDDeviceUsageKey as String: 0x0003       // KeyboardFn
            ],
            // 也匹配 Apple Vendor Keyboard（某些设备上 fn 键在这个 page）
            [
                kIOHIDDeviceUsagePageKey as String: 0x00FF,  // AppleVendorTopCase
                kIOHIDDeviceUsageKey as String: 0x0001       // TopCase 其他用途
            ],
            // 通用键盘（外接键盘的 fn 键）
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
            ]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingCriteria as CFArray)

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, hidInputValueCallback, selfPointer)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess {
            hidManager = manager
            NSLog("[FnKeyMonitor] ✅ IOHIDManager 启动成功")
        } else {
            NSLog("[FnKeyMonitor] ⚠️ IOHIDManager 启动失败 (0x%x)", result)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    private func stopHIDMonitor() {
        if let manager = hidManager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidManager = nil
    }

    fileprivate func handleHIDValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)

        // 诊断日志：打印所有 AppleVendorTopCase 的事件
        if usagePage == 0x00FF {
            NSLog("[FnKeyMonitor] HID event: page=0x%x usage=0x%x value=%ld", usagePage, usage, intValue)
        }

        // fn 键：AppleVendorTopCase (0x00FF), KeyboardFn (0x0003)
        if usagePage == 0x00FF && usage == 0x0003 {
            let pressed = intValue != 0
            setFnState(pressed, source: "HID")
        }
    }

    // MARK: - 3. NSEvent 全局监听（兜底）

    private func startNSEventMonitor() {
        // NSEvent.addGlobalMonitorForEvents 不需要 Accessibility 权限
        // 但在某些场景下可以补充 CGEvent Tap 收不到的事件
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            let fnPressed = event.modifierFlags.contains(.function)
            let keyCode = event.keyCode

            NSLog("[FnKeyMonitor] NSEvent flagsChanged: keyCode=%d fn=%@", keyCode, fnPressed ? "true" : "false")

            if keyCode == UInt16(FnKeyMonitor.fnKeyCode) || keyCode == UInt16(FnKeyMonitor.globeKeyCode) {
                self.setFnState(fnPressed, source: "NSEvent keyCode=\(keyCode)")
            } else if fnPressed != self.isFnHeld {
                self.setFnState(fnPressed, source: "NSEvent flags")
            }
        }

        // 鼠标点击监听：fn 按住时点击触发抓词（不依赖 Accessibility 权限）
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, self.isFnHeld else { return }
            // 统一传递 Cocoa 坐标（左下角原点），由下游负责转换
            let cocoaLocation = NSEvent.mouseLocation
            NSLog("[FnKeyMonitor] 🖱️ fn+点击 at %@ (NSEvent, Cocoa坐标)", "\(cocoaLocation)")
            DispatchQueue.main.async {
                self.onClickWhileFnHeld?(cocoaLocation)
            }
        }

        if globalFlagsMonitor != nil {
            NSLog("[FnKeyMonitor] ✅ NSEvent 全局监听启动成功")
        }
    }

    private func stopNSEventMonitor() {
        if let monitor = globalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}

// MARK: - C Callbacks

/// IOHIDManager 输入值回调
private func hidInputValueCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard let context = context else { return }
    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleHIDValue(value)
}

/// CGEvent Tap 回调
private func fnKeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        NSLog("[FnKeyMonitor] ⚠️ Event tap 被系统禁用，正在重新启用...")
        if let userInfo = userInfo {
            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    if let userInfo = userInfo {
        let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handleCGEvent(type, event: event)
    }

    return Unmanaged.passUnretained(event)
}
