import AetherCore
import AppKit

/// Workspaces work like AeroSpace's: they only exist in memory, and windows of hidden workspaces
/// are parked in the screen's bottom-right corner (macOS keeps a 1px sliver visible).
// shortcut: single monitor (the menu bar screen) and all AX calls on the main thread with a 0.5s
// messaging timeout, so a hung app can stall aether briefly. Upgrade to per-monitor workspaces and
// AeroSpace's per-app AX threads when either starts to hurt.
final class WindowManager {
    static let shared = WindowManager()

    private var windows: [CGWindowID: Window] = [:]
    /// Window order per workspace is the dwindle order.
    private var workspaces = Array(repeating: [CGWindowID](), count: Config.workspaces.count)
    private var current = 0
    private var previous: Int?
    private var layouts: [Int: Layout] = [:]
    private var ratios: [Int: [CGFloat]] = [:]
    private var fullscreen: Set<CGWindowID> = []
    private var floating: Set<CGWindowID> = []
    private var parked: Set<CGWindowID> = []
    private var floatingFrames: [CGWindowID: CGRect] = [:]
    private var lastFocus: [Int: CGWindowID] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    private var refreshScheduled = false
    private var followFocusOnRefresh = false
    private let animator = Animator()
    private let border = Border()
    /// Cached so per-frame border updates don't cost AX round trips.
    private var borderTarget: CGWindowID?

    private init() {
        animator.onFrame = { [unowned self] id, frame in
            if id == borderTarget { border.show(around: frame, within: screenRect) }
        }
    }

    // MARK: Events

    func start() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [unowned self] _ in
            scheduleRefresh(followFocus: true)
        }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [unowned self] _ in scheduleRefresh() }
        }
        // AeroSpace's backstop: destroy notifications are unreliable, and a mouse-up after the user
        // drags a tiled window should snap it back into place.
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [unowned self] _ in scheduleRefresh() }
        refresh(followFocus: false)
    }

    fileprivate func handle(_ notification: String, _ element: AXUIElement) {
        switch notification {
        case kAXMovedNotification, kAXResizedNotification:
            if let id = element.windowId, id == borderTarget, !animator.isAnimating(id) { updateBorder() }
        case kAXFocusedWindowChangedNotification:
            scheduleRefresh(followFocus: true)
        default:
            scheduleRefresh()
        }
    }

    private func scheduleRefresh(followFocus: Bool = false) {
        followFocusOnRefresh = followFocusOnRefresh || followFocus
        guard !refreshScheduled else { return }
        refreshScheduled = true
        // A short delay lets new windows finish setting their subrole before we classify them.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            refreshScheduled = false
            let follow = followFocusOnRefresh
            followFocusOnRefresh = false
            refresh(followFocus: follow)
        }
    }

    // MARK: Model

    private func refresh(followFocus: Bool) {
        var alive: [CGWindowID: Window] = [:]
        var running: Set<pid_t> = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != getpid() {
            let pid = app.processIdentifier
            running.insert(pid)
            let axApp = AXUIElementCreateApplication(pid)
            observe(pid, axApp)
            for element in (axApp.get(kAXWindowsAttribute) as [AXUIElement]?) ?? [] {
                guard let id = element.windowId, isManageable(element) else { continue }
                alive[id] = windows[id] ?? register(Window(id: id, pid: pid, ax: element))
            }
        }
        for pid in observers.keys where !running.contains(pid) { observers[pid] = nil }

        let gone = Set(windows.keys).subtracting(alive.keys)
        for i in workspaces.indices { workspaces[i].removeAll(where: gone.contains) }
        parked.subtract(gone)
        floating.subtract(gone)
        fullscreen.subtract(gone)
        for id in gone { animator.cancel(id) }

        let focused = focusedId
        for id in alive.keys.sorted() where windows[id] == nil {
            // Like Hyprland's dwindle, a new window goes right after the focused one.
            let ws = workspaces[current]
            let index = focused.flatMap(ws.firstIndex(of:)).map { $0 + 1 } ?? ws.count
            workspaces[current].insert(id, at: index)
            let window = alive[id]!
            let bundleId = NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier ?? ""
            if Config.floatingApps.contains(bundleId) || !window.ax.isSettable(kAXSizeAttribute) { floating.insert(id) }
        }
        windows = alive

        // Cmd-Tab or a click on a window that lives on another workspace switches to it.
        if followFocus, let focused, let ws = workspace(of: focused), ws != current {
            switchTo(ws, focusing: focused)
            return
        }
        if let focused, workspace(of: focused) == current { lastFocus[current] = focused }
        layout()
    }

    private func register(_ window: Window) -> Window {
        if let observer = observers[window.pid] {
            for n in [kAXUIElementDestroyedNotification, kAXMovedNotification, kAXResizedNotification,
                      kAXWindowMiniaturizedNotification] {
                AXObserverAddNotification(observer, window.ax, n as CFString, nil)
            }
        }
        return window
    }

    private func observe(_ pid: pid_t, _ axApp: AXUIElement) {
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, { _, element, notification, _ in
            WindowManager.shared.handle(notification as String, element)
        }, &observer) == .success, let observer else { return }
        for n in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification] {
            AXObserverAddNotification(observer, axApp, n as CFString, nil)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    private func isManageable(_ element: AXUIElement) -> Bool {
        (element.get(kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole
            && (element.get(kAXMinimizedAttribute) as Bool?) != true
            && (element.get("AXFullScreen") as Bool?) != true
    }

    private var focusedId: CGWindowID? {
        // AX requests to our own process can hang (AeroSpace hit this), and aether has no windows.
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else { return nil }
        let window: AXUIElement? = AXUIElementCreateApplication(app.processIdentifier).get(kAXFocusedWindowAttribute)
        return window?.windowId
    }

    private func workspace(of id: CGWindowID) -> Int? {
        workspaces.firstIndex { $0.contains(id) }
    }

    // MARK: Layout

    private var screenRect: CGRect {
        flip(NSScreen.screens.first?.visibleFrame ?? .zero)
    }

    private var tiled: [CGWindowID] {
        workspaces[current].filter { !floating.contains($0) }
    }

    private var workArea: CGRect {
        screenRect.insetBy(dx: Config.gapsOut, dy: Config.gapsOut)
    }

    private var tiledFrames: [CGRect] {
        let ids = tiled
        switch layouts[current] ?? .dwindle {
        case .dwindle:
            return dwindle(count: ids.count, in: workArea, gap: Config.gapsIn, ratios: ratios[current] ?? [])
        case .accordion:
            let focused = lastFocus[current].flatMap(ids.firstIndex(of:)) ?? 0
            return accordion(count: ids.count, focused: focused, in: workArea, padding: Config.accordionPadding)
        }
    }

    /// `slide` is -1/+1 when switching workspaces: incoming windows slide in from that side and
    /// outgoing ones leave through the other, Hyprland style, using only position writes.
    private func layout(slide: CGFloat = 0) {
        let screen = screenRect
        let dx = slide * screen.width
        for (id, frame) in zip(tiled, tiledFrames) { place(id, fullscreen.contains(id) ? workArea : frame, dx) }
        for id in workspaces[current] where floating.contains(id) && parked.contains(id) {
            if let frame = floatingFrames[id] { place(id, frame, dx) }
        }

        let corner = CGPoint(x: screen.maxX - 1, y: screen.maxY - 1)
        for (i, ws) in workspaces.enumerated() where i != current {
            for id in ws where !parked.contains(id) {
                guard let window = windows[id] else { continue }
                if floating.contains(id) { floatingFrames[id] = window.frame }
                parked.insert(id)
                if slide != 0, let frame = window.frame {
                    animator.animate(window, to: frame.offsetBy(dx: -dx, dy: 0)) { window.setPosition(corner) }
                } else {
                    animator.cancel(id)
                    window.setPosition(corner)
                }
            }
        }
        updateBorder()
    }

    private func place(_ id: CGWindowID, _ frame: CGRect, _ dx: CGFloat) {
        guard let window = windows[id] else { return }
        let wasParked = parked.remove(id) != nil
        animator.animate(window, from: wasParked ? frame.offsetBy(dx: dx, dy: 0) : nil, to: frame)
    }

    private func updateBorder() {
        guard let id = focusedId, workspace(of: id) == current, !parked.contains(id),
              let frame = windows[id]?.frame else {
            borderTarget = nil
            return border.hide()
        }
        borderTarget = id
        border.show(around: frame, within: screenRect)
    }

    // MARK: Commands

    func execute(_ action: Action) {
        switch action {
        case .workspace(let name): Config.workspaces.firstIndex(of: name).map { switchTo($0) }
        case .moveToWorkspace(let name): Config.workspaces.firstIndex(of: name).map(moveFocused(to:))
        case .move(let direction): swap(direction)
        case .resize(let delta): resize(by: delta)
        case .layout(let layout):
            layouts[current] = layout
            self.layout()
        case .fullscreen: toggleFullscreen()
        case .backAndForth: previous.map { switchTo($0) }
        case .exec(let command): _ = try? Process.run(URL(fileURLWithPath: "/bin/bash"), arguments: ["-c", command])
        case .mode(let mode): Hotkeys.shared.activate(mode)
        case .toggleFloating: toggleFloating()
        case .resetLayout:
            layouts[current] = nil
            ratios[current] = nil
            fullscreen.subtract(workspaces[current])
            layout()
        case .closeAllButCurrent: closeAllButFocused()
        case .reload: refresh(followFocus: false)
        case .quit:
            restoreAll()
            exit(0)
        }
    }

    /// AeroSpace's `move`: in dwindle that means swapping places with the neighbour on that side.
    private func swap(_ direction: Direction) {
        let ids = tiled
        guard let focused = focusedId, let index = ids.firstIndex(of: focused) else { return }
        let next: Int?
        if layouts[current] == .accordion {
            // Accordion frames overlap, so geometry can't find a neighbour; use list order.
            let step = direction == .left || direction == .up ? -1 : 1
            next = ids.indices.contains(index + step) ? index + step : nil
        } else {
            next = neighbor(of: index, in: tiledFrames, direction)
        }
        guard let next, let a = workspaces[current].firstIndex(of: ids[index]),
              let b = workspaces[current].firstIndex(of: ids[next]) else { return }
        workspaces[current].swapAt(a, b)
        layout()
    }

    private func resize(by delta: CGFloat) {
        let ids = tiled
        guard layouts[current] ?? .dwindle == .dwindle, let focused = focusedId, let index = ids.firstIndex(of: focused) else { return }
        ratios[current] = resized(ratios[current] ?? [], index: index, delta: delta, count: ids.count, in: workArea, gap: Config.gapsIn)
        layout()
    }

    private func toggleFullscreen() {
        guard let id = focusedId, tiled.contains(id) else { return }
        if fullscreen.remove(id) == nil { fullscreen.insert(id) }
        layout()
        windows[id]?.focus()
    }

    private func closeAllButFocused() {
        let focused = focusedId
        for id in workspaces[current] where id != focused {
            guard let button: AXUIElement = windows[id]?.ax.get(kAXCloseButtonAttribute) else { continue }
            AXUIElementPerformAction(button, kAXPressAction as CFString)
        }
    }

    private func switchTo(_ ws: Int, focusing target: CGWindowID? = nil) {
        guard ws != current, workspaces.indices.contains(ws) else { return }
        let slide: CGFloat = ws > current ? 1 : -1
        previous = current
        current = ws
        layout(slide: slide)
        focus(target ?? lastFocus[ws] ?? workspaces[ws].first)
    }

    /// With nothing to focus, aether takes focus itself so keys don't go to a parked window.
    private func focus(_ id: CGWindowID?) {
        if let window = id.flatMap({ windows[$0] }) {
            window.focus()
        } else {
            NSApp.activate()
        }
    }

    private func moveFocused(to ws: Int) {
        guard let id = focusedId, let from = workspace(of: id), from != ws, workspaces.indices.contains(ws) else { return }
        workspaces[from].removeAll { $0 == id }
        workspaces[ws].append(id)
        lastFocus[ws] = id
        layout()
        focus(lastFocus[current].flatMap { workspaces[current].contains($0) ? $0 : nil } ?? workspaces[current].first)
    }

    private func toggleFloating() {
        guard let id = focusedId, let window = windows[id], workspace(of: id) == current else { return }
        if floating.remove(id) == nil {
            floating.insert(id)
            let screen = screenRect
            animator.animate(window, to: screen.insetBy(dx: screen.width * 0.2, dy: screen.height * 0.2))
        }
        layout()
    }

    /// Bring every parked window back on screen so nothing is stranded in the corner after we exit.
    func restoreAll() {
        let screen = screenRect
        for id in parked {
            guard let window = windows[id], let frame = window.frame else { continue }
            if let saved = floatingFrames[id] {
                window.setPosition(saved.origin)
            } else {
                window.setPosition(CGPoint(x: screen.midX - frame.width / 2, y: screen.midY - frame.height / 2))
            }
        }
        parked.removeAll()
    }
}
