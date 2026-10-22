import AetherCore
import AppKit
import ApplicationServices

// The only private API, same as AeroSpace: maps an AX window element to its WindowServer id.
@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

extension AXUIElement {
    func get<T>(_ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }

    var windowId: CGWindowID? {
        var id = CGWindowID(0)
        return _AXUIElementGetWindow(self, &id) == .success && id != 0 ? id : nil
    }

    func isSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(self, attribute as CFString, &settable) == .success && settable.boolValue
    }
}

final class Window {
    let id: CGWindowID
    let pid: pid_t
    let bundleId: String
    let ax: AXUIElement

    init(id: CGWindowID, pid: pid_t, bundleId: String, ax: AXUIElement) {
        self.id = id
        self.pid = pid
        self.bundleId = bundleId
        self.ax = ax
    }

    var key: WindowKey {
        WindowKey(id: id, bundleId: bundleId, title: ax.get(kAXTitleAttribute) ?? "")
    }

    var frame: CGRect? {
        guard let p: AXValue = ax.get(kAXPositionAttribute), let s: AXValue = ax.get(kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p, .cgPoint, &origin)
        AXValueGetValue(s, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    func setPosition(_ point: CGPoint) {
        var p = point
        AXUIElementSetAttributeValue(ax, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
    }

    func setSize(_ size: CGSize) {
        var s = size
        AXUIElementSetAttributeValue(ax, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!)
    }

    /// Size, position, size: the order AeroSpace settled on (its issues #143, #335), wrapped in
    /// turning off AXEnhancedUserInterface, which otherwise makes some apps animate and lag.
    func setFrame(_ r: CGRect) {
        let app = AXUIElementCreateApplication(pid)
        let enhanced: Bool = app.get("AXEnhancedUserInterface") ?? false
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        setSize(r.size)
        setPosition(r.origin)
        setSize(r.size)
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
    }

    func focus() {
        AXUIElementSetAttributeValue(ax, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: pid)?.activate()
    }
}

/// AppKit uses a bottom-left origin, AX a top-left one; the flip is its own inverse.
func flip(_ r: CGRect) -> CGRect {
    let mainHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: r.minX, y: mainHeight - r.maxY, width: r.width, height: r.height)
}
