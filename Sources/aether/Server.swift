import AetherCore
import Foundation

private let maxRequestBytes = 64 * 1024

/// Serves the command line client. Accepting and answering happen on the main queue because all
/// window manager state lives there, so every connection gets a short timeout.
final class Server {
    static let shared = Server()

    private var source: DispatchSourceRead?

    /// Returns why the server could not start, e.g. another aether already owns the socket.
    func start() -> String? {
        if let fd = connectToServer() {
            close(fd)
            return "aether is already running (\(socketPath))"
        }
        // Nobody answered, so a leftover file is stale.
        unlink(socketPath)
        let fd = makeSocket()
        // Only the owner may send commands, since `exec-and-forget` runs shell commands.
        guard bindSocket(fd), chmod(socketPath, 0o600) == 0, listen(fd, 8) == 0 else {
            let reason = String(cString: strerror(errno))
            close(fd)
            return "cannot listen on \(socketPath): \(reason)"
        }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [unowned self] in accept(fd) }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
        return nil
    }

    func stop() {
        source?.cancel()
        unlink(socketPath)
    }

    private func accept(_ listener: Int32) {
        let client = Darwin.accept(listener, nil, nil)
        guard client >= 0 else { return }
        // BSD sockets can inherit O_NONBLOCK from the listener, which would defeat the timeout.
        _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
        setTimeout(client, seconds: 1)
        serve(client)
    }

    private func serve(_ client: Int32) {
        let request = receive(client, limit: maxRequestBytes) { $0.contains(UInt8(ascii: "\n")) }
        guard request.count < maxRequestBytes else { return finish(client, code: 1, "request too large\n") }
        // A timed-out partial line could be a truncated `exec-and-forget` command, so never run it.
        guard request.contains(UInt8(ascii: "\n")) else { return finish(client, code: 1, "incomplete request\n") }
        let line = String(decoding: request.prefix { $0 != UInt8(ascii: "\n") }, as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)

        let wm = WindowManager.shared
        if let query = parseQuery(line) {
            if let output = wm.answer(query) {
                finish(client, code: 0, output)
            } else {
                finish(client, code: 1, "unknown workspace in '\(line)'\n")
            }
        } else if let action = parseCommand(line) {
            // Reply first: `quit` exits the process.
            finish(client, code: 0, "")
            wm.execute(action)
        } else {
            finish(client, code: 1, "unknown command '\(line)'. Try aether --help.\n")
        }
    }

    private func finish(_ client: Int32, code: Int, _ output: String) {
        send(client, "\(code)\n\(output)")
        close(client)
    }
}
