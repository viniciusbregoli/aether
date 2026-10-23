import AetherCore
import AppKit
import ApplicationServices
import Carbon.HIToolbox

// Private API, same as AeroSpace: maps an AX window element to its WindowServer id.
@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

// Private API, same as yabai: AX can't see windows of Spaces that aren't on screen, WindowServer can.
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ connection: Int32, _ mask: Int32, _ windows: CFArray) -> CFArray

/// A closed window is on no Space; one on a Space that isn't shown still exists.
func isOnSomeSpace(_ id: CGWindowID) -> Bool {
    // Mask 7: current, other and fullscreen Spaces.
    CFArrayGetCount(CGSCopySpacesForWindows(CGSMainConnectionID(), 7, [id] as CFArray)) > 0
}

var isScreenLocked: Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return true }
    // This session key covers refreshes that arrive before the distributed lock notification.
    return session["CGSSessionScreenIsLocked"] as? Bool == true
        || session[kCGSessionOnConsoleKey as String] as? Bool == false
}

extension AXUIElement {
    func get<T>(_ attribute: String, ifUnsupported fallback: T? = nil) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)
        if result == .attributeUnsupported { return fallback }
        guard result == .success else { return nil }
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

/// Sends cmd-N to an app, which is "new window" in most of them.
func requestNewWindow(_ pid: pid_t) {
    for keyDown in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_N), keyDown: keyDown)
        event?.flags = .maskCommand
        event?.postToPid(pid)
    }
}

/// AppKit uses a bottom-left origin, AX a top-left one; the flip is its own inverse.
func flip(_ r: CGRect) -> CGRect {
    let mainHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: r.minX, y: mainHeight - r.maxY, width: r.width, height: r.height)
}
