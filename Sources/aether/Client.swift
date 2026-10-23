import Foundation

private let usage = """
usage: aether                      run the window manager
       aether <command>            send a command to the running aether

commands:
  workspace <name>                 switch workspace
  move-node-to-workspace <name>    move the focused window
  move left|right|up|down          swap with the neighbour
  layout dwindle|accordion|floating
  reload-config, quit, ...         any command the config accepts
  list-workspaces [--focused|--occupied]
  list-windows [--focused|--workspace <name>]
"""

/// Sends `words` to the running aether, prints its reply and exits with its status.
func runClient(_ words: [String]) -> Never {
    if words.first == "--help" || words.first == "-h" {
        print(usage)
        exit(0)
    }
    guard let fd = connectToServer() else {
        FileHandle.standardError.write(Data("aether: not running (nothing is listening on \(socketPath))\n".utf8))
        exit(1)
    }
    setTimeout(fd, seconds: 5)
    send(fd, words.joined(separator: " ") + "\n")
    let reply = String(decoding: receive(fd), as: UTF8.self)
    close(fd)

    guard let newline = reply.firstIndex(of: "\n"), let code = Int32(reply[..<newline]) else {
        FileHandle.standardError.write(Data("aether: no reply from the running instance\n".utf8))
        exit(1)
    }
    let output = Data(reply[reply.index(after: newline)...].utf8)
    (code == 0 ? FileHandle.standardOutput : FileHandle.standardError).write(output)
    exit(code)
}
