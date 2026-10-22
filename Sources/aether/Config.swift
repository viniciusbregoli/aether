import AetherCore
import Foundation

/// The active settings, from ~/.config/aether/config.toml.
var config = loadConfig() ?? (try! Settings.parse(defaultConfig))

let configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/aether/config.toml")

/// Reads the config file, writing the defaults there first if it doesn't exist yet.
/// Returns nil (after printing why) when the file is invalid, so callers keep what they have.
func loadConfig() -> Settings? {
    if !FileManager.default.fileExists(atPath: configURL.path) {
        try? FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? defaultConfig.write(to: configURL, atomically: true, encoding: .utf8)
    }
    do {
        return try Settings.parse(String(contentsOf: configURL, encoding: .utf8))
    } catch {
        print("aether: \(configURL.path): \(error)")
        return nil
    }
}
