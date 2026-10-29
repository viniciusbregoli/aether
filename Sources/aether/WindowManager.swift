import AetherCore
import AppKit

/// Workspaces work like AeroSpace's: they only exist in memory, each monitor shows one of them,
/// and windows of hidden workspaces are parked in a screen corner (macOS keeps a 1px sliver visible).
// shortcut: all AX calls on the main thread with a 0.5s messaging timeout, so a hung app can stall
// aether briefly. Upgrade to AeroSpace's per-app AX threads when that starts to hurt.
final class WindowManager {
    static let shared = WindowManager()

    private var windows: [CGWindowID: Window] = [:]
    /// Window order per workspace is the dwindle order.
    private var workspaces = Array(repeating: [CGWindowID](), count: config.workspaces.count)
    /// The focused workspace, which is always shown on some monitor.
    private var current = 0
    private var previous: Int?
    /// Monitors left to right, and the workspace each one shows.
    private var monitors: [Monitor] = []
    private var shown: [CGDirectDisplayID: Int] = [:]
    /// Where a workspace was last shown, so its windows park in that monitor's corner.
    private var lastMonitor: [Int: CGDirectDisplayID] = [:]
    /// What a monitor last showed, so one that comes back (after sleep, say) shows it again.
    private var lastShown: [CGDirectDisplayID: Int] = [:]
    /// A mouse button went up: the focused window may have been dragged to another monitor.
    private var dragEnded = false
    private var layouts: [Int: Layout] = [:]
    /// Dwindle split ratios, or a single master ratio or scrolling column width for those layouts.
    private var ratios: [Int: [CGFloat]] = [:]
    private var scrollOffsets: [Int: CGFloat] = [:]
    private var fullscreen: Set<CGWindowID> = []
    /// Windows on a native fullscreen Space. Like AeroSpace and rift, they stay in their workspace
    /// so they can't be lost or reassigned on the way out; layout just leaves them alone. Focusing
    /// one brings its Space back, which is how switching to its workspace returns to it.
    private var nativeFullscreen: Set<CGWindowID> = []
    /// Windows that just left native fullscreen: macOS still moves and focuses them for a moment.
    private var leftFullscreen = FocusHold()
    private var floating: Set<CGWindowID> = []
    private var parked: Set<CGWindowID> = []
    private var floatingFrames: [CGWindowID: CGRect] = [:]
    private var lastFocus: [Int: CGWindowID] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    /// App notifications refused while the app was starting up, asked for again on each scan.
    private var refusedNotifications: [pid_t: Set<String>] = [:]
    private var refreshScheduled = false
    /// Apps with windows that couldn't be read yet, and how many quick rescans they have had.
    private var unsettledApps: Set<String> = []
    private var unsettledRetries = 0
    private var followFocusOnRefresh = false
    /// App activated through Dock, Spotlight or Cmd-Tab since the last refresh.
    private var activatedPid: pid_t?
    /// cmd-N sent to this app for this workspace, until its window shows up or the fallback runs.
    private var pendingNewWindow: (pid: pid_t, workspace: Int)?
    private var mode = "main"
    private var pendingRestore: SavedState?
    /// Saved entries (indices into the saved list) still waiting on apps that haven't answered.
    private var restoreWaiting: [Int]?
    private var restoreWaitingApps: Set<String> = []
    private var restoreRank: [CGWindowID: Int] = [:]
    /// When restoring started, measured in time because quick rescans make the count of scans unreliable.
    private var restoreStarted: CFTimeInterval?
    private var lastSaved: Data?
    private let animator = Animator()
    private let border = Border()
    private let dimmer = Dimmer()
    private let tray = Tray()
    private let anchor = Anchor()
    /// Cached so per-frame border updates don't cost AX round trips.
    private var borderTarget: CGWindowID?
    /// Last frame the animator reported per window, so overlays of moving windows need no AX reads.
    private var reportedFrames: [CGWindowID: CGRect] = [:]
    private var mouseMonitor: Any?
    private var pointerCheckScheduled = false

    private init() {
        animator.onFrame = { [unowned self] id, frame in
            if id == borderTarget { border.show(around: frame, within: screenRect, above: id, reorder: false) }
            if config.dimInactive > 0 {
                reportedFrames[id] = frame
                dimmer.move(id, to: frame)
            }
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
        // A launching app answers AX late and may show its first window before it sends any
        // notification we could hear, so look again a few times while it starts up.
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [unowned self] _ in
            for delay in [0.05, 0.3, 0.8, 1.6, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in scheduleRefresh() }
            }
        }
        // Entering and leaving native fullscreen switch Spaces, often without any AX notification.
        for name in [NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [unowned self] _ in scheduleRefresh() }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [unowned self] _ in resumeAfterUnlock() }
        }
        // Unlocking does not always wake the display or switch the user session.
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                                                            object: nil, queue: .main) { [unowned self] _ in resumeAfterUnlock() }
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"),
                                                            object: nil, queue: .main) { [unowned self] _ in
            activatedPid = nil
            pendingNewWindow = nil
            border.hide()
            dimmer.hideAll()
        }
        // AeroSpace's backstop: destroy notifications are unreliable, and a mouse-up after the user
        // drags a tiled window should snap it back into place.
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [unowned self] _ in
            dragEnded = true
            scheduleRefresh()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                               queue: .main) { [unowned self] _ in
            updateMonitors()
            // Unlocking refreshes, which lays out on the monitors found here.
            if !isScreenLocked { layout() }
        }
        updateMonitors()
        updateMouseMonitor()
        pendingRestore = try? JSONDecoder().decode(SavedState.self, from: Data(contentsOf: stateURL))
        refresh(followFocus: false)
    }

    fileprivate func handle(_ notification: String, _ element: AXUIElement) {
        switch notification {
        case kAXMovedNotification, kAXResizedNotification:
            guard let id = element.windowId, !animator.isAnimating(id) else { return }
            if id == borderTarget { updateBorder() }
            // macOS puts a window back at its old frame once the fullscreen exit animation ends,
            // which can be after aether parked it because the user switched workspaces meanwhile.
            if nativeFullscreen.contains(id) || leftFullscreen.isHeld(id, at: ProcessInfo.processInfo.systemUptime) {
                scheduleRefresh()
            }
        case kAXFocusedWindowChangedNotification:
            scheduleRefresh(followFocus: true)
        case kAXUIElementDestroyedNotification:
            // A closed window stays on its Space through its close animation (about 0.3s), so the
            // scan right away still keeps it and its tile stays empty. Look again once it is gone.
            scheduleRefresh()
            for delay in [0.45, 1.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in scheduleRefresh() }
            }
        default:
            scheduleRefresh()
        }
    }

    private func scheduleRefresh(followFocus: Bool = false, after delay: TimeInterval = 0.05) {
        followFocusOnRefresh = followFocusOnRefresh || followFocus
        guard !refreshScheduled else { return }
        refreshScheduled = true
        // A short delay lets new windows finish setting their subrole before we classify them.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            refreshScheduled = false
            let follow = followFocusOnRefresh
            followFocusOnRefresh = false
            refresh(followFocus: follow)
        }
    }

    private func updateMouseMonitor() {
        if config.focusFollowsMouse, mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [unowned self] _ in schedulePointerCheck() }
        } else if !config.focusFollowsMouse, let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    /// Mouse moves arrive at display rate; one check per 30 ms, reading the pointer when it runs,
    /// keeps the window list queries cheap and still lands on where the pointer stopped.
    private func schedulePointerCheck() {
        guard !pointerCheckScheduled else { return }
        pointerCheckScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [self] in
            pointerCheckScheduled = false
            focusWindowUnderPointer()
        }
    }

    private func focusWindowUnderPointer() {
        guard config.focusFollowsMouse, NSEvent.pressedMouseButtons == 0, !isScreenLocked,
              let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else { return }
        let mouse = NSEvent.mouseLocation
        let point = CGPoint(x: mouse.x, y: (NSScreen.screens.first?.frame.height ?? 0) - mouse.y)
        let stack = info.compactMap { entry -> ScreenWindow? in
            guard let id = entry[kCGWindowNumber as String] as? UInt32, let pid = entry[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return ScreenWindow(id: id, pid: pid, layer: entry[kCGWindowLayer as String] as? Int ?? 0,
                                alpha: entry[kCGWindowAlpha as String] as? Double ?? 1, bounds: rect)
        }
        // Every shown workspace, so hovering a window on another monitor focuses it and refresh
        // makes that monitor's workspace current.
        let focusable = Set(shown.values.flatMap { workspaces[$0] }.filter {
            !parked.contains($0) && !nativeFullscreen.contains($0) && !animator.isAnimating($0)
        })
        // borderTarget usually answers "already focused" without an AX round trip; smart-border
        // hides it on a lone window, so confirm with focusedId before focusing again.
        guard let id = windowUnderPointer(point, in: stack, ownPid: getpid(), focusable: focusable, focused: borderTarget),
              id != focusedId else { return }
        windows[id]?.focus()
    }

    private func resumeAfterUnlock() {
        activatedPid = nil
        pendingNewWindow = nil
        // Unlock can precede AX availability. Retry briefly without forgetting unreadable windows.
        for delay in [0.05, 0.25, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in scheduleRefresh() }
        }
    }

    // MARK: Model

    private func refresh(followFocus: Bool) {
        guard !isScreenLocked else { return }
        var alive: [CGWindowID: Window] = [:]
        var running: Set<pid_t> = []
        var incompleteApps: Set<String> = []
        var excludedAll: Set<CGWindowID> = []
        var exitedFullscreen: Set<CGWindowID> = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != getpid() {
            let pid = app.processIdentifier
            running.insert(pid)
            let axApp = AXUIElementCreateApplication(pid)
            observe(pid, axApp)
            let elements: [AXUIElement]? = axApp.get(kAXWindowsAttribute)
            var discovered: [CGWindowID: Window] = [:]
            var excluded: Set<CGWindowID> = []
            var complete = elements != nil
            for element in elements ?? [] {
                guard let id = element.windowId, let manageable = isManageable(element) else {
                    complete = false
                    continue
                }
                guard manageable else {
                    excluded.insert(id)
                    continue
                }
                if (element.get("AXFullScreen") as Bool?) == true {
                    nativeFullscreen.insert(id)
                    // A glide still running would keep writing frames to the fullscreen window.
                    animator.cancel(id)
                } else if nativeFullscreen.remove(id) != nil {
                    exitedFullscreen.insert(id)
                }
                discovered[id] = windows[id] ?? register(Window(id: id, pid: pid, bundleId: app.bundleIdentifier ?? "", ax: element))
            }
            let snapshot = reconcileWindowSnapshot(previous: windows.filter { $0.value.pid == pid },
                                                   discovered: discovered, isComplete: complete, excluding: excluded)
            alive.merge(snapshot) { _, fresh in fresh }
            excludedAll.formUnion(excluded)
            if !complete { incompleteApps.insert(app.bundleIdentifier ?? "") }
        }
        // AX only lists windows of the Spaces on screen, and on the way out of a native fullscreen
        // Space it briefly lists none. A missing window that still sits on some Space is out of
        // sight, not closed.
        let missing = windows.filter { alive[$0.key] == nil && running.contains($0.value.pid) && !excludedAll.contains($0.key) }
        alive.merge(missing.filter { id, window in
            // A missing window may be on a fullscreen Space no scan has seen it enter yet.
            let isFullscreen = window.ax.get("AXFullScreen") as Bool?
            let onSomeSpace = isOnSomeSpace(id)
            if onSomeSpace, isFullscreen == false {
                if nativeFullscreen.remove(id) != nil { exitedFullscreen.insert(id) }
                return true
            }
            guard keepsMissingWindow(onSomeSpace: onSomeSpace, inNativeFullscreen: nativeFullscreen.contains(id) || isFullscreen == true,
                                     elementAlive: (window.ax.get(kAXRoleAttribute) as String?) != nil) else { return false }
            if isFullscreen == true, nativeFullscreen.insert(id).inserted { animator.cancel(id) }
            return true
        }) { fresh, _ in fresh }
        // Locking may have started while an app was answering the AX requests above.
        guard !isScreenLocked else { return }
        retryUnsettled(incompleteApps)
        for pid in observers.keys where !running.contains(pid) {
            observers[pid] = nil
            refusedNotifications[pid] = nil
        }

        let gone = Set(windows.keys).subtracting(alive.keys)
        for i in workspaces.indices { workspaces[i].removeAll(where: gone.contains) }
        parked.subtract(gone)
        floating.subtract(gone)
        fullscreen.subtract(gone)
        nativeFullscreen.subtract(gone)
        for id in gone {
            animator.cancel(id)
            reportedFrames[id] = nil
        }
        let now = ProcessInfo.processInfo.systemUptime
        for id in exitedFullscreen { leftFullscreen.hold(id, until: now + 1.5) }

        if let saved = pendingRestore {
            let started = restoreStarted ?? CACurrentMediaTime()
            restoreStarted = started
            // Restore what's readable now. Apps that never answer stop being waited on after ~10s.
            if restore(saved, from: alive, deferring: CACurrentMediaTime() - started < 10 ? incompleteApps : []) {
                scheduleRefresh(after: 0.5)
            } else {
                pendingRestore = nil
                restoreWaiting = nil
                restoreWaitingApps = []
                restoreRank = [:]
            }
        }

        let focused = focusedId
        // New windows a rule sent to another workspace, and windows back from native fullscreen on
        // a hidden one: focus must not drag the user there.
        var ruleMoved: Set<CGWindowID> = []
        if let focused, let ws = workspace(of: focused), !shown.values.contains(ws), leftFullscreen.isHeld(focused, at: now) {
            ruleMoved.insert(focused)
        }
        // Windows of an app still being restored wait for their saved slot instead of landing here.
        for id in alive.keys.sorted() where workspace(of: id) == nil && !restoreWaitingApps.contains(alive[id]!.bundleId) {
            let window = alive[id]!
            let (isFloating, target) = classify(window)
            if target == current {
                // Like Hyprland's dwindle, a new window goes right after the focused one.
                let ws = workspaces[current]
                let index = focused.flatMap(ws.firstIndex(of:)).map { $0 + 1 } ?? ws.count
                workspaces[current].insert(id, at: index)
            } else {
                workspaces[target].append(id)
                ruleMoved.insert(id)
            }
            if pendingNewWindow?.pid == window.pid { pendingNewWindow = nil }
            if isFloating { floating.insert(id) }
        }
        windows = alive

        let activated = activatedPid
        activatedPid = nil
        if dragEnded {
            dragEnded = false
            if let focused { adoptDragged(focused) }
        }
        if followFocus, let focused, !ruleMoved.contains(focused), let ws = workspace(of: focused), ws != current {
            let pid = windows[focused]?.pid
            if let pending = pendingNewWindow, pending.pid == pid, pending.workspace == current {
                // The app refocused its old window while we wait for the one we asked for: stay here.
            } else if let pid, pid == activated, !shown.values.contains(ws), !config.reuseWindowApps.contains(windows[focused]?.bundleId ?? ""),
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
        // The app focused its new window, which is now parked.
        if let focused, ruleMoved.contains(focused) { focus(windowToFocus(in: workspaces[current], remembered: lastFocus[current])) }
    }

    /// A window that is still being set up (no subrole yet, say) is skipped by a scan, and nothing
    /// may announce it again, so scans with unreadable windows repeat a few times. An app that never
    /// answers stops being retried until the set of such apps changes.
    private func retryUnsettled(_ apps: Set<String>) {
        if apps != unsettledApps {
            unsettledApps = apps
            unsettledRetries = 0
        }
        guard !apps.isEmpty, unsettledRetries < 10 else { return }
        unsettledRetries += 1
        scheduleRefresh(after: 0.2)
    }

    /// Applies `floating-apps`, then the window rules, to a window that just appeared. Returns
    /// whether it floats and the workspace index it lands on.
    private func classify(_ window: Window) -> (floating: Bool, workspace: Int) {
        var isFloating = config.floatingApps.contains(window.bundleId)
        var target = current
        if !config.windowRules.isEmpty {
            let facts = WindowFacts(appId: window.bundleId,
                                    appName: NSRunningApplication(processIdentifier: window.pid)?.localizedName ?? "",
                                    title: window.ax.get(kAXTitleAttribute) ?? "")
            let outcome = evaluateRules(config.windowRules, for: facts, workspace: config.workspaces[current], floating: isFloating)
            isFloating = outcome.floating
            target = config.workspaces.firstIndex(of: outcome.workspace) ?? current
        }
        return (isFloating || !window.ax.isSettable(kAXSizeAttribute), target)
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
        if let observer = observers[pid] {
            for n in refusedNotifications[pid] ?? [] where AXObserverAddNotification(observer, axApp, n as CFString, nil) != .cannotComplete {
                refusedNotifications[pid]?.remove(n)
            }
            return
        }
        var observer: AXObserver?
        guard AXObserverCreate(pid, { _, element, notification, _ in
            WindowManager.shared.handle(notification as String, element)
        }, &observer) == .success, let observer else { return }
        let refused = [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification].filter {
            AXObserverAddNotification(observer, axApp, $0 as CFString, nil) == .cannotComplete
        }
        // An app that just launched can refuse these until it is ready. Without window-created its
        // windows would go unannounced for good, so the observer is dropped and the next scan starts
        // over; any other refused one is asked for again on later scans.
        guard !refused.contains(kAXWindowCreatedNotification) else { return }
        if !refused.isEmpty { refusedNotifications[pid] = Set(refused) }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        for window in windows.values where window.pid == pid { _ = register(window) }
    }

    private func isManageable(_ element: AXUIElement) -> Bool? {
        guard let subrole: String = element.get(kAXSubroleAttribute) else { return nil }
        guard subrole == kAXStandardWindowSubrole else { return false }
        guard let minimized: Bool = element.get(kAXMinimizedAttribute, ifUnsupported: false) else { return nil }
        return !minimized
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

    /// A window dropped on another monitor joins the workspace shown there, and focus follows it.
    private func adoptDragged(_ id: CGWindowID) {
        guard let from = workspace(of: id), shown.values.contains(from), !animator.isAnimating(id), !nativeFullscreen.contains(id),
              let frame = windows[id]?.frame,
              let target = monitors.first(where: { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }),
              let to = shown[target.id], to != from else { return }
        workspaces[from].removeAll { $0 == id }
        workspaces[to].append(id)
        if lastFocus[from] == id { lastFocus[from] = nil }
        if current != to {
            previous = current
            current = to
        }
    }

    // MARK: Monitors

    private func displayId(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// Reads the monitors again and gives each one a workspace. `keep` holds on to what each
    /// monitor showed and gives returning monitors what they showed last; restoring passes the
    /// saved assignments as `preferred` instead.
    private func updateMonitors(preferred: [CGDirectDisplayID: Int]? = nil, keep: Bool = true) {
        let fresh = NSScreen.screens.compactMap { screen in
            displayId(screen).map { Monitor(id: $0, name: screen.localizedName, frame: flip(screen.frame), visible: flip(screen.visibleFrame)) }
        }.sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
        // Closing the lid can briefly report no screens; keep the old ones until real ones show up.
        guard !fresh.isEmpty else { return }
        let ids = fresh.map(\.id)
        let main = NSScreen.screens.first.flatMap(displayId) ?? ids[0]
        let kept = keep ? shown.filter { ids.contains($0.key) } : [:]
        let wasFocused = keep ? shown.first { $0.value == current }?.key : nil
        monitors = fresh
        if let wasFocused, !ids.contains(wasFocused), forcedMonitor(of: current) == nil, let ws = kept[main] ?? kept.values.first {
            // The focused monitor went away: focus moves to one that is left, and the workspace it
            // showed stays hidden until it comes back. A pinned one that still matches a monitor
            // moves there and keeps focus.
            previous = current
            current = ws
        }
        let forced = Dictionary(uniqueKeysWithValues: workspaces.indices.compactMap { ws in forcedMonitor(of: ws).map { (ws, $0) } })
        shown = assignWorkspaces(monitors: ids, kept: kept, preferred: preferred ?? lastShown, focused: current,
                                 focusedMonitor: wasFocused.flatMap { ids.contains($0) ? $0 : nil } ?? main,
                                 count: workspaces.count, occupied: Set(workspaces.indices.filter { !workspaces[$0].isEmpty }),
                                 forced: forced)
    }

    private var mainMonitorId: CGDirectDisplayID? { NSScreen.screens.first.flatMap(displayId) ?? monitors.first?.id }

    /// The connected monitor `workspace-to-monitor-force-assignment` puts `ws` on, if any.
    private func forcedMonitor(of ws: Int) -> CGDirectDisplayID? {
        guard let patterns = config.workspaceMonitors[config.workspaces[ws]], let main = mainMonitorId else { return nil }
        return AetherCore.forcedMonitor(patterns, monitors: monitors.map { ($0.id, $0.name) }, main: main)
    }

    private func targetMonitor(_ target: MonitorTarget) -> Int? {
        guard let focused = focusedMonitor, let index = monitors.firstIndex(where: { $0.id == focused.id }),
              let next = AetherCore.monitor(target, from: index, in: monitors.map(\.frame)) else { return nil }
        return shown[monitors[next].id]
    }

    // MARK: Layout

    private func monitor(showing ws: Int) -> Monitor? {
        shown.first { $0.value == ws }.flatMap { entry in monitors.first { $0.id == entry.key } }
    }

    private var focusedMonitor: Monitor? { monitor(showing: current) ?? monitors.first }

    /// The visible frame of the monitor showing `ws`; hidden workspaces measure on the focused one.
    private func screen(_ ws: Int) -> CGRect {
        (monitor(showing: ws) ?? focusedMonitor)?.visible ?? .zero
    }

    private var screenRect: CGRect { screen(current) }

    private func tiled(in ws: Int) -> [CGWindowID] {
        workspaces[ws].filter { !floating.contains($0) && !nativeFullscreen.contains($0) }
    }

    private var tiled: [CGWindowID] { tiled(in: current) }

    private func workArea(of ws: Int) -> CGRect {
        let gap = config.smartGaps && tiled(in: ws).count == 1 ? 0 : config.gapsOuter(in: config.workspaces[ws])
        return screen(ws).insetBy(dx: gap, dy: gap)
    }

    private var workArea: CGRect { workArea(of: current) }

    private func tiledFrames(of ws: Int) -> [CGRect] {
        let ids = tiled(in: ws)
        let name = config.workspaces[ws]
        switch layoutKind(of: ws) {
        case .dwindle:
            return dwindle(count: ids.count, in: workArea(of: ws), gap: config.gapsInner(in: name), ratios: ratios[ws] ?? [], defaultRatio: config.dwindleSplitRatio)
        case .accordion:
            let focused = lastFocus[ws].flatMap(ids.firstIndex(of:)) ?? 0
            return accordion(count: ids.count, focused: focused, in: workArea(of: ws), padding: config.accordionPadding)
        case .master:
            return master(count: ids.count, in: workArea(of: ws), gap: config.gapsInner(in: name), ratio: ratios[ws]?.first ?? config.masterRatio)
        case .scrolling:
            // The view only moves when the focused column is not fully visible, so the offset is kept
            // between layouts. A focused floating window leaves it alone.
            // shortcut: columns beyond the screen edge get off-screen frames, and macOS may clamp a
            // window that can't be fully off-screen. Upgrade to parking them if that ever shows.
            let strip = scrolling(count: ids.count, focused: lastFocus[ws].flatMap(ids.firstIndex(of:)),
                                  offset: scrollOffsets[ws] ?? 0,
                                  columnWidth: ratios[ws]?.first ?? config.scrollingColumnWidth,
                                  in: workArea(of: ws), gap: config.gapsInner(in: name))
            scrollOffsets[ws] = strip.offset
            return strip.frames
        }
    }

    private var tiledFrames: [CGRect] { tiledFrames(of: current) }

    private func layoutKind(of ws: Int) -> Layout { layouts[ws] ?? config.defaultLayout(in: config.workspaces[ws]) }

    private var currentLayout: Layout { layoutKind(of: current) }

    private var currentName: String { config.workspaces[current] }

    /// `slide` is -1/+1 when the focused monitor switches workspaces: incoming windows slide in
    /// from that side and outgoing ones leave through the other, Hyprland style, using only
    /// position writes. Every monitor lays out the workspace it shows; the rest are parked.
    private func layout(slide: CGFloat = 0) {
        var distance = CGSize.zero
        if slide != 0, let focused = focusedMonitor {
            let d = slideDistance(for: focused.visible, others: monitors.filter { $0.id != focused.id }.map(\.frame))
            distance = CGSize(width: d.width * slide, height: d.height * slide)
        }
        for (monitorId, ws) in shown {
            lastMonitor[ws] = monitorId
            lastShown[monitorId] = ws
            let offset = ws == current ? distance : .zero
            let area = workArea(of: ws)
            for (id, frame) in zip(tiled(in: ws), tiledFrames(of: ws)) { place(id, fullscreen.contains(id) ? area : frame, offset) }
            for id in workspaces[ws] where floating.contains(id) && parked.contains(id) {
                if let frame = floatingFrames[id] { place(id, fitted(frame, in: screen(ws)), offset) }
            }
        }

        let screens = monitors.map(\.visible)
        for (i, ws) in workspaces.enumerated() where !shown.values.contains(i) {
            let home = monitors.first { $0.id == lastMonitor[i] } ?? focusedMonitor
            // A window on a fullscreen Space is out of sight already, and moving it would undo its fullscreen.
            for id in ws where !nativeFullscreen.contains(id) {
                guard let window = windows[id] else { continue }
                if parked.contains(id) {
                    let frame = window.frame
                    if needsParking(frame: frame, monitors: screens, isAnimating: animator.isAnimating(id)), let frame, let home {
                        window.setPosition(parkingSpot(for: frame.size, on: home))
                    }
                    continue
                }
                let frame = window.frame
                if floating.contains(id) { floatingFrames[id] = frame }
                parked.insert(id)
                guard let home else { continue }
                let spot = parkingSpot(for: frame?.size ?? .zero, on: home)
                if distance != .zero, let frame {
                    animator.animate(window, to: frame.offsetBy(dx: -distance.width, dy: -distance.height)) { window.setPosition(spot) }
                } else {
                    animator.cancel(id)
                    window.setPosition(spot)
                }
            }
        }
        updateBorder()
        updateDim()
        updateTray()
        save()
    }

    private func parkingSpot(for size: CGSize, on monitor: Monitor) -> CGPoint {
        AetherCore.parkingSpot(size: size, monitor: monitor.visible, others: monitors.filter { $0.id != monitor.id }.map(\.frame))
    }

    /// A floating window keeps its frame on its monitor; on another one it is centered there.
    private func fitted(_ frame: CGRect, in screen: CGRect) -> CGRect {
        screen.contains(CGPoint(x: frame.midX, y: frame.midY)) ? frame : CGRect(origin: centered(frame.size, in: screen), size: frame.size)
    }

    private func centered(_ size: CGSize, in screen: CGRect) -> CGPoint {
        CGPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
    }

    private func updateTray() {
        let occupied = config.workspaces.indices.filter { !workspaces[$0].isEmpty || $0 == current }.map { config.workspaces[$0] }
        tray.update(current: config.workspaces[current], occupied: occupied, mode: mode,
                    switchTo: { [unowned self] in execute(.workspace($0)) }, quit: { [unowned self] in execute(.quit) })
    }

    private func place(_ id: CGWindowID, _ frame: CGRect, _ offset: CGSize) {
        guard let window = windows[id] else { return }
        let wasParked = parked.remove(id) != nil
        let from = wasParked ? frame.offsetBy(dx: offset.width, dy: offset.height) : nil
        if let from { reportedFrames[id] = from }
        animator.animate(window, from: from, to: frame)
    }

    private func updateBorder() {
        guard let id = focusedId, workspace(of: id) == current, !parked.contains(id), !nativeFullscreen.contains(id),
              !(config.smartBorder && tiled == [id]), let frame = windows[id]?.frame else {
            borderTarget = nil
            return border.hide()
        }
        borderTarget = id
        border.show(around: frame, within: screenRect, above: id)
    }

    /// The focused window is `borderTarget`: it is already known to be on this workspace and visible.
    private func updateDim() {
        guard config.dimInactive > 0, !isScreenLocked else { return dimmer.hideAll() }
        var frames: [CGWindowID: CGRect] = [:]
        for id in dimTargets(in: shown.values.flatMap { workspaces[$0] }, focused: borderTarget, parked: parked.union(nativeFullscreen)) {
            let frame = animator.isAnimating(id) ? reportedFrames[id] : windows[id]?.frame
            if let frame { frames[id] = frame }
        }
        dimmer.show(frames)
    }

    // MARK: Commands

    func execute(_ action: Action) {
        switch action {
        case .workspace(let name):
            if let ws = config.workspaces.firstIndex(of: name) {
                switchTo(workspaceToActivate(requested: ws, current: current, previous: previous,
                                             autoBackAndForth: config.workspaceAutoBackAndForth))
            }
        case .moveToWorkspace(let name): config.workspaces.firstIndex(of: name).map(moveFocused(to:))
        case .focusMonitor(let target): targetMonitor(target).map { switchTo($0) }
        case .moveToMonitor(let target): targetMonitor(target).map(moveFocused(to:))
        case .move(let direction): swap(direction)
        case .resize(let delta): resize(by: delta)
        case .layout(let layout):
            // Dwindle ratios mean nothing to master and scrolling, and the other way around.
            if layout != currentLayout, ![layout, currentLayout].allSatisfy({ $0 == .dwindle || $0 == .accordion }) {
                ratios[current] = nil
            }
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
            scrollOffsets[current] = nil
            fullscreen.subtract(workspaces[current])
            layout()
        case .closeAllButCurrent: closeAllButFocused()
        case .reload: reloadConfig()
        case .quit:
            Server.shared.stop()
            restoreAll()
            exit(0)
        }
    }

    /// Answers a command line query, or nil when it names a workspace that doesn't exist.
    func answer(_ query: Query) -> String? {
        let names = config.workspaces
        switch query {
        case .workspaces: return lines(names)
        case .focusedWorkspace: return lines([names[current]])
        case .occupiedWorkspaces:
            return lines(names.indices.filter { $0 == current || !workspaces[$0].isEmpty }.map { names[$0] })
        case .windows: return lines(names.indices.flatMap(windowLines(in:)))
        case .focusedWindows: return lines(windowLines(in: current))
        case .windowsIn(let name): return names.firstIndex(of: name).map { lines(windowLines(in: $0)) }
        }
    }

    private func lines(_ items: [String]) -> String {
        items.map { $0 + "\n" }.joined()
    }

    private func windowLines(in workspace: Int) -> [String] {
        workspaces[workspace].compactMap { id in
            guard let window = windows[id] else { return nil }
            let app = NSRunningApplication(processIdentifier: window.pid)?.localizedName ?? window.bundleId
            let title: String = window.ax.get(kAXTitleAttribute) ?? ""
            return "\(id) | \(config.workspaces[workspace]) | \(app) | \(title.replacingOccurrences(of: "\n", with: " "))"
        }
    }

    /// AeroSpace's `move`: in dwindle that means swapping places with the neighbour on that side.
    private func swap(_ direction: Direction) {
        let ids = tiled
        guard let focused = focusedId, let index = ids.firstIndex(of: focused) else { return }
        let next: Int?
        // Scrolling columns have no vertical neighbours.
        if currentLayout == .scrolling && (direction == .up || direction == .down) { return }
        if currentLayout == .accordion || currentLayout == .scrolling {
            // Accordion frames overlap and scrolling ones can be off-screen, so geometry can't find a neighbour; use list order.
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
        guard let focused = focusedId, let index = ids.firstIndex(of: focused) else { return }
        switch currentLayout {
        case .dwindle:
            ratios[current] = resized(ratios[current] ?? [], index: index, delta: delta, count: ids.count, in: workArea, gap: config.gapsInner(in: currentName), defaultRatio: config.dwindleSplitRatio)
        case .master where ids.count > 1:
            let ratio = ratios[current]?.first ?? config.masterRatio
            ratios[current] = [resizedMasterRatio(ratio, index: index, delta: delta, count: ids.count, in: workArea, gap: config.gapsInner(in: currentName))]
        case .scrolling:
            // One width for every column of the workspace, so it survives windows closing and moving.
            ratios[current] = [resizedColumnWidth(ratios[current]?.first ?? config.scrollingColumnWidth, delta: delta, in: workArea)]
        default:
            return
        }
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

    /// A workspace shown on another monitor just takes focus there; a hidden one replaces the
    /// workspace on its pinned monitor, else on the main one, and focus moves there. Where it was
    /// last shown doesn't count: a workspace once opened on the laptop screen would keep going there.
    private func switchTo(_ ws: Int, focusing target: CGWindowID? = nil) {
        guard ws != current, workspaces.indices.contains(ws) else { return }
        let slide: CGFloat = ws > current ? 1 : -1
        let visible = shown.values.contains(ws)
        if !visible, let main = mainMonitorId {
            shown[forcedMonitor(of: ws) ?? main] = ws
        }
        previous = current
        current = ws
        layout(slide: visible ? 0 : slide)
        focus(windowToFocus(in: workspaces[ws], preferred: target, remembered: lastFocus[ws]))
    }

    /// With nothing to focus, aether takes focus itself so keys don't go to a parked window, and
    /// macOS leaves a native fullscreen Space for the desktop.
    private func focus(_ id: CGWindowID?) {
        if let window = id.flatMap({ windows[$0] }) {
            window.focus()
        } else {
            anchor.focus()
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
        for id in parked {
            guard let window = windows[id], let frame = window.frame, let ws = workspace(of: id) else { continue }
            let screen = (monitors.first { $0.id == lastMonitor[ws] } ?? focusedMonitor)?.visible ?? screenRect
            window.setPosition(floatingFrames[id].map { fitted($0, in: screen).origin } ?? centered(frame.size, in: screen))
        }
        parked.removeAll()
        // Scrolling can leave columns of shown workspaces off screen too.
        for ws in shown.values {
            let screen = screen(ws)
            for id in workspaces[ws] {
                guard let window = windows[id], let frame = window.frame, !screen.contains(frame.origin) else { continue }
                window.setPosition(centered(frame.size, in: screen))
            }
        }
    }

    // MARK: Config

    func bindHotkeys() {
        Hotkeys.shared.reset()
        for (mode, bindings) in config.modes {
            for (binding, actions) in bindings {
                Hotkeys.shared.bind(mode, binding) { [unowned self] in actions.forEach(execute) }
            }
        }
        mode = "main"
        Hotkeys.shared.activate(mode)
    }

    private func reloadConfig() {
        guard var new = loadConfig() else { return }
        // Workspace slots are allocated at startup, so a changed list waits for a restart.
        new.workspaces = config.workspaces
        config = new
        if !config.animationsEnabled || config.animationDuration == 0 { animator.finishAll() }
        bindHotkeys()
        updateMouseMonitor()
        border.applyStyle()
        dimmer.applyStyle()
        // Force assignments may have changed: workspaces shown on the wrong monitor move.
        updateMonitors()
        refresh(followFocus: false)
    }

    // MARK: Persistence

    private var stateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/aether/state.json")
    }

    /// Written after every layout so a crash loses nothing; skipped when nothing changed.
    private func save() {
        guard pendingRestore == nil else { return }
        let names = config.workspaces
        var state = SavedState(current: names[current], workspaces: [:], layouts: [:], ratios: [:],
                               monitors: Dictionary(uniqueKeysWithValues: shown.map { (String($0.key), names[$0.value]) }))
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

    /// Places the saved windows that can be matched now. Returns true while some saved windows are
    /// still waiting on apps whose scan was incomplete.
    private func restore(_ state: SavedState, from alive: [CGWindowID: Window], deferring incompleteApps: Set<String>) -> Bool {
        let names = config.workspaces
        let entries = names.flatMap { name in (state.workspaces[name] ?? []).map { (name, $0) } }
        let first = restoreWaiting == nil
        let waiting = restoreWaiting ?? Array(entries.indices)
        let placed = Set(workspaces.joined())
        let live = alive.keys.sorted().filter { !placed.contains($0) }.compactMap { alive[$0]?.key }
        let (matched, deferred) = matchIncrementally(saved: waiting.map { entries[$0].1.key }, alive: live, deferring: incompleteApps)
        var touched: Set<Int> = []
        for (k, id) in matched {
            let (name, saved) = entries[waiting[k]]
            guard let ws = names.firstIndex(of: name) else { continue }
            workspaces[ws].append(id)
            restoreRank[id] = waiting[k]
            touched.insert(ws)
            if saved.floating { floating.insert(id) }
            if saved.fullscreen { fullscreen.insert(id) }
        }
        // Back in saved order; windows that arrived meanwhile keep their order after them.
        for ws in touched {
            workspaces[ws] = workspaces[ws].enumerated()
                .sorted { (restoreRank[$0.element] ?? .max, $0.offset) < (restoreRank[$1.element] ?? .max, $1.offset) }
                .map(\.element)
        }
        if first {
            for (name, layout) in state.layouts { names.firstIndex(of: name).map { layouts[$0] = layout } }
            for (name, r) in state.ratios { names.firstIndex(of: name).map { ratios[$0] = r } }
            current = names.firstIndex(of: state.current) ?? 0
            var preferred: [CGDirectDisplayID: Int] = [:]
            for (display, name) in state.monitors ?? [:] {
                if let id = CGDirectDisplayID(display), let ws = names.firstIndex(of: name) { preferred[id] = ws }
            }
            updateMonitors(preferred: preferred, keep: false)
        }
        restoreWaiting = deferred.map { waiting[$0] }
        restoreWaitingApps = Set(deferred.map { entries[waiting[$0]].1.key.bundleId })
        return !deferred.isEmpty
    }
}

private struct SavedState: Codable {
    var current: String
    var workspaces: [String: [SavedWindow]]
    var layouts: [String: Layout]
    var ratios: [String: [CGFloat]]
    /// Display id -> the workspace it showed; missing in state saved before multi-monitor support.
    var monitors: [String: String]?
}

/// A screen in AX (top-left origin) coordinates.
private struct Monitor {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let visible: CGRect
}

private struct SavedWindow: Codable {
    let key: WindowKey
    let floating: Bool
    let fullscreen: Bool
}
