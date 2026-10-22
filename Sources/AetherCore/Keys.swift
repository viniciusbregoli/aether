import Carbon.HIToolbox

/// Parses AeroSpace-style binding strings such as "alt-shift-h" into a Carbon key code and
/// modifier mask, so aether's bindings read the same as ~/.aerospace.toml.
public func parseBinding(_ binding: String) -> (keyCode: Int, modifiers: Int)? {
    let parts = binding.split(separator: "-").map(String.init)
    guard let key = parts.last, let keyCode = keyCodes[key] else { return nil }
    var modifiers = 0
    for part in parts.dropLast() {
        guard let modifier = modifierMasks[part] else { return nil }
        modifiers |= modifier
    }
    return (keyCode, modifiers)
}

private let modifierMasks = ["alt": optionKey, "shift": shiftKey, "cmd": cmdKey, "ctrl": controlKey]

private let keyCodes: [String: Int] = [
    "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
    "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
    "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
    "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
    "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
    "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
    "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    "slash": kVK_ANSI_Slash, "comma": kVK_ANSI_Comma, "minus": kVK_ANSI_Minus, "equal": kVK_ANSI_Equal,
    "semicolon": kVK_ANSI_Semicolon, "tab": kVK_Tab, "esc": kVK_Escape, "backspace": kVK_Delete,
    "space": kVK_Space, "enter": kVK_Return,
    "left": kVK_LeftArrow, "right": kVK_RightArrow, "up": kVK_UpArrow, "down": kVK_DownArrow,
]
