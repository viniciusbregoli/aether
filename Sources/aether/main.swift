import AppKit

let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(options) else {
    print("aether: grant Accessibility access to the app running this binary (System Settings > Privacy & Security > Accessibility), then start it again.")
    exit(1)
}

if let problem = Server.shared.start() {
    print("aether: \(problem)")
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let wm = WindowManager.shared
wm.bindHotkeys()

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
print("aether running with \(configURL.path). alt-shift-semicolon then q quits.")
app.run()
