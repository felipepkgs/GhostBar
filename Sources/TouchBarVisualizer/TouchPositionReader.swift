import Foundation
import CoreFoundation

// MultitouchSupport.framework is private and undocumented — every symbol is
// resolved via dlopen/dlsym so a missing/renamed symbol on a future macOS
// disables this feature instead of crashing the app at launch.

private typealias MTDeviceRef = UnsafeMutableRawPointer

private struct MTPoint {
    var x: Float = 0
    var y: Float = 0
}

private struct MTVector {
    var position = MTPoint()
    var velocity = MTPoint()
}

// ponytail: field layout reverse-engineered (no header from Apple); order
// matches the commonly-referenced community struct. If x/y read as garbage,
// this layout is the first thing to re-check against a fresh reverse-engineered header.
private struct MTTouch {
    var frame: Int32 = 0
    var timestamp: Double = 0
    var identifier: Int32 = 0
    var state: Int32 = 0
    var fingerId: Int32 = 0
    var handId: Int32 = 0
    var normalizedVector = MTVector()
    var zTotal: Float = 0
    var unknown3: Int32 = 0
    var angle: Float = 0
    var majorAxis: Float = 0
    var minorAxis: Float = 0
    var absoluteVector = MTVector()
    var unknown4: Int32 = 0
    var unknown5: Int32 = 0
    var zDensity: Float = 0
}

// Note: the touches pointer is declared as an untyped UnsafeMutableRawPointer
// rather than UnsafeMutablePointer<MTTouch> — Swift's @convention(c) requires
// every parameter type to be Objective-C representable, which a plain Swift
// struct pointer is not. It's rebound to MTTouch inside the callback body instead.
private typealias MTFrameCallback = @convention(c) (
    MTDeviceRef?, UnsafeMutableRawPointer?, Int, Double, Int
) -> Void

private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
private typealias MTDeviceGetFamilyIDFn = @convention(c) (MTDeviceRef?, UnsafeMutablePointer<Int32>?) -> Int32
private typealias MTRegisterContactFrameCallbackFn = @convention(c) (MTDeviceRef?, MTFrameCallback?) -> Void
private typealias MTDeviceStartFn = @convention(c) (MTDeviceRef?, Int32) -> Void
private typealias MTDeviceStopFn = @convention(c) (MTDeviceRef?) -> Void

final class TouchPositionReader {
    static let shared = TouchPositionReader()

    /// Called on the main thread with the active touch's normalized x [0, 1] and whether a finger is down.
    var onTouch: ((_ x: Float, _ active: Bool) -> Void)?

    private let touchBarFamilyID: Int32 = 176 // 113 is the trackpad
    private var devices: [MTDeviceRef] = []
    private var deviceStop: MTDeviceStopFn?

    private static weak var activeReader: TouchPositionReader?

    private init() {}

    func start() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
            RTLD_NOW
        ) else {
            NSLog("TouchBarVisualizer: MultitouchSupport unavailable, touch position disabled")
            return
        }

        func sym<T>(_ name: String, as _: T.Type) -> T? {
            guard let s = dlsym(handle, name) else { return nil }
            return unsafeBitCast(s, to: T.self)
        }

        guard
            let createList = sym("MTDeviceCreateList", as: MTDeviceCreateListFn.self),
            let getFamilyID = sym("MTDeviceGetFamilyID", as: MTDeviceGetFamilyIDFn.self),
            let registerCallback = sym("MTRegisterContactFrameCallback", as: MTRegisterContactFrameCallbackFn.self),
            let deviceStart = sym("MTDeviceStart", as: MTDeviceStartFn.self)
        else {
            NSLog("TouchBarVisualizer: MultitouchSupport symbols missing, touch position disabled")
            return
        }
        deviceStop = sym("MTDeviceStop", as: MTDeviceStopFn.self)

        guard let listRef = createList() else {
            NSLog("TouchBarVisualizer: MTDeviceCreateList returned nil")
            return
        }
        let list = listRef.takeRetainedValue()
        let count = CFArrayGetCount(list)

        for i in 0..<count {
            guard let raw = CFArrayGetValueAtIndex(list, i) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            var family: Int32 = 0
            _ = getFamilyID(device, &family)
            if family == touchBarFamilyID {
                devices.append(device)
            }
        }

        guard !devices.isEmpty else {
            NSLog("TouchBarVisualizer: no Touch Bar digitizer found (is this a Touch Bar Mac?)")
            return
        }

        Self.activeReader = self
        for device in devices {
            registerCallback(device, Self.frameCallback)
            deviceStart(device, 0)
        }
    }

    func stop() {
        for device in devices {
            deviceStop?(device)
        }
    }

    private static let frameCallback: MTFrameCallback = { _, touchesRaw, count, _, _ in
        guard let reader = TouchPositionReader.activeReader else { return }
        guard let touchesRaw, count > 0 else {
            DispatchQueue.main.async { reader.onTouch?(0, false) }
            return
        }
        let touches = touchesRaw.assumingMemoryBound(to: MTTouch.self)
        let x = touches[0].normalizedVector.position.x
        DispatchQueue.main.async { reader.onTouch?(x, true) }
    }
}
