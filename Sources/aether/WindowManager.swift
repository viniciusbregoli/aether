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
    /// App activated through Dock, Spotlight or Cmd-Tab since the last refresh.
    private var activatedPid: pid_t?
    /// cmd-N sent to this app for this workspace, until its window shows up or the fallback runs.
    private var pendingNewWindow: (pid: pid_t, workspace: Int)?
    private var mode = "main"
    private var pendingRestore: SavedState?
    private var lastSaved: Data?
    private let animator = Animator()
    private let border = Border()
    private let tray = Tray()
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
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [unowned self] note in
            activatedPid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            scheduleRefresh(followFocus: true)
        }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [unowned self] _ in scheduleRefresh() }
        }
        // AeroSpace's backstop: destroy notifications are unreliable, and a mouse-up after the user
        // drags a tiled window should snap it back into place.
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [unowned self] _ in scheduleRefresh() }
        pendingRestore = try? JSONDecoder().decode(SavedState.self, from: Data(contentsOf: stateURL))
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
                alive[id] = windows[id] ?? register(Window(id: id, pid: pid, bundleId: app.bundleIdentifier ?? "", ax: element))
            }
        }
        for pid in observers.keys where !running.contains(pid) { observers[pid] = nil }

        let gone = Set(windows.keys).subtracting(alive.keys)
        for i in workspaces.indices { workspaces[i].removeAll(where: gone.contains) }
        parked.subtract(gone)
        floating.subtract(gone)
        fullscreen.subtract(gone)
        for id in gone { animator.cancel(id) }

        if let saved = pendingRestore {
            pendingRestore = nil
            restore(saved, from: alive)
        }

        let focused = focusedId
        for id in alive.keys.sorted() where windows[id] == nil && workspace(of: id) == nil {
            // Like Hyprland's dwindle, a new window goes right after the focused one.
            let ws = workspaces[current]
            let index = focused.flatMap(ws.firstIndex(of:)).map { $0 + 1 } ?? ws.count
            workspaces[current].insert(id, at: index)
            let window = alive[id]!
            if pendingNewWindow?.pid == window.pid { pendingNewWindow = nil }
            if Config.floatingApps.contains(window.bundleId) || !window.ax.isSettable(kAXSizeAttribute) { floating.insert(id) }
        }
        windows = alive

        let activated = activatedPid
        activatedPid = nil
        if followFocus, let focused, let ws = workspace(of: focused), ws != current {
            let pid = windows[focused]?.pid
            if let pending = pendingNewWindow, pending.pid == pid, pending.workspace == current {
                // The app refocused its old window while we wait for the one we asked for: stay here.
            } else if let pid, pid == activated, !Config.reuseWindowApps.contains(windows[focused]?.bundleId ?? ""),
               !workspaces[current].contains(where: { windows[$0]?.pid == pid }) {
                // Opening an app (Dock, Spotlight, Cmd-Tab) that only has windows elsewhere asks it
                // for a new window here. Apps that ignore cmd-N fall back to jumping to their window,
                // unless the user has already moved on.
                requestNewWindow(pid)
                let request = (pid: pid, workspace: current)
                pendingNewWindow = request
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                    guard let pending = pendingNewWindow, pending == request else { return }
                    pendingNewWindow = nil
                    if current == request.workspace, let ws = workspace(of: focused) {
                        switchTo(ws, focusing: focused)
                    }
                }
            } else {
                // Focus moved to a window on another workspace by other means (a link, a notification).
                switchTo(ws, focusing: focused)
                return
            }
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
        updateTray()
        save()
    }

    private func updateTray() {
        let occupied = Config.workspaces.indices.filter { !workspaces[$0].isEmpty || $0 == current }.map { Config.workspaces[$0] }
        tray.update(current: Config.workspaces[current], occupied: occupied, mode: mode,
                    switchTo: { [unowned self] in execute(.workspace($0)) }, quit: { [unowned self] in execute(.quit) })
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
        case .mode(let mode):
            self.mode = mode
            Hotkeys.shared.activate(mode)
            updateTray()
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
        focus(windowToFocus(in: workspaces[ws], preferred: target, remembered: lastFocus[ws]))
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
        if lastFocus[from] == id { lastFocus[from] = nil }
        lastFocus[ws] = id
        layout()
        focus(windowToFocus(in: workspaces[current], remembered: lastFocus[current]))
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

    // MARK: Persistence

    private var stateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/aether/state.json")
    }

    /// Written after every layout so a crash loses nothing; skipped when nothing changed.
    private func save() {
        guard pendingRestore == nil else { return }
        let names = Config.workspaces
        var state = SavedState(current: names[current], workspaces: [:], layouts: [:], ratios: [:])
        for (i, ids) in workspaces.enumerated() where !ids.isEmpty {
            state.workspaces[names[i]] = ids.compactMap { id in
                windows[id].map { SavedWindow(key: $0.key, floating: floating.contains(id), fullscreen: fullscreen.contains(id)) }
            }
        }
        for (i, layout) in layouts { state.layouts[names[i]] = layout }
        for (i, r) in ratios { state.ratios[names[i]] = r }
        guard let data = try? JSONEncoder().encode(state), data != lastSaved else { return }
        lastSaved = data
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateURL, options: .atomic)
    }

    private func restore(_ state: SavedState, from alive: [CGWindowID: Window]) {
        let names = Config.workspaces
        let entries = names.flatMap { name in (state.workspaces[name] ?? []).map { (name, $0) } }
        let live = alive.keys.sorted().compactMap { alive[$0]?.key }
        for (i, id) in match(saved: entries.map(\.1.key), alive: live) {
            let (name, saved) = entries[i]
            guard let ws = names.firstIndex(of: name) else { continue }
            workspaces[ws].append(id)
            if saved.floating { floating.insert(id) }
            if saved.fullscreen { fullscreen.insert(id) }
        }
        // match() returns a dictionary, so restore each workspace's saved order.
        for ws in workspaces.indices {
            let order = (state.workspaces[names[ws]] ?? []).map(\.key.id)
            workspaces[ws].sort { (order.firstIndex(of: $0) ?? .max, $0) < (order.firstIndex(of: $1) ?? .max, $1) }
        }
        for (name, layout) in state.layouts { names.firstIndex(of: name).map { layouts[$0] = layout } }
        for (name, r) in state.ratios { names.firstIndex(of: name).map { ratios[$0] = r } }
        current = names.firstIndex(of: state.current) ?? 0
    }
}

private struct SavedState: Codable {
    var current: String
    var workspaces: [String: [SavedWindow]]
    var layouts: [String: Layout]
    var ratios: [String: [CGFloat]]
}

private struct SavedWindow: Codable {
    let key: WindowKey
    let floating: Bool
    let fullscreen: Bool
}
