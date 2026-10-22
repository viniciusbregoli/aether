import AetherCore
import Carbon

/// Global hotkeys through Carbon's RegisterEventHotKey, the same API AeroSpace uses (via soffes/HotKey).
/// Only the active mode's keys are registered, so service-mode keys like `esc` stay free otherwise.
final class Hotkeys {
    static let shared = Hotkeys()
    private var modes: [String: [String: () -> Void]] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            Hotkeys.shared.actions[hotKey.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// Drops every binding, for a config reload.
    func reset() {
        activate("")
        modes.removeAll()
    }

    func bind(_ mode: String, _ binding: String, _ action: @escaping () -> Void) {
        modes[mode, default: [:]][binding] = action
    }

    func activate(_ mode: String) {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
        for (binding, action) in modes[mode] ?? [:] {
            guard let (keyCode, modifiers) = parseBinding(binding) else {
                print("aether: can't parse binding '\(binding)'")
                continue
            }
            let id = UInt32(actions.count + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: OSType(0x6165_7468), id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            guard status == noErr, let ref else {
                print("aether: '\(binding)' is taken (status \(status)); is AeroSpace still running?")
                continue
            }
            actions[id] = action
            refs.append(ref)
        }
    }
}
