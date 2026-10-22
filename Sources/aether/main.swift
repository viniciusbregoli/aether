import AppKit

let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(options) else {
    print("aether: grant Accessibility access to the app running this binary (System Settings > Privacy & Security > Accessibility), then start it again.")
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let wm = WindowManager.shared
for (mode, bindings) in Config.modes {
    for (binding, actions) in bindings {
        Hotkeys.shared.bind(mode, binding) { actions.forEach(wm.execute) }
    }
}
Hotkeys.shared.activate("main")

// Ctrl-C or kill must not leave windows stranded in the corner.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { wm.execute(.quit) }
    source.resume()
    signalSources.append(source)
}

wm.start()
print("aether running with the bindings ported from ~/.aerospace.toml. alt-shift-semicolon then q quits.")
app.run()
