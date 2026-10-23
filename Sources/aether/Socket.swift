import Foundation

let socketPath = "/tmp/aether-\(NSUserName()).sock"

/// Stream socket that reports a closed peer as an error instead of raising SIGPIPE.
func makeSocket() -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    var on: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    return fd
}

func setTimeout(_ fd: Int32, seconds: Int) {
    var timeout = timeval(tv_sec: seconds, tv_usec: 0)
    for option in [SO_RCVTIMEO, SO_SNDTIMEO] {
        setsockopt(fd, SOL_SOCKET, option, &timeout, socklen_t(MemoryLayout<timeval>.size))
    }
}

private func withSocketAddress<T>(_ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
        let path = Array(socketPath.utf8.prefix(buffer.count - 1))
        buffer.copyBytes(from: path)
    }
    return withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
}

func bindSocket(_ fd: Int32) -> Bool {
    withSocketAddress { bind(fd, $0, $1) == 0 }
}

/// A connected client socket, or nil when nobody is listening on `socketPath`.
func connectToServer() -> Int32? {
    let fd = makeSocket()
    if withSocketAddress({ connect(fd, $0, $1) == 0 }) { return fd }
    close(fd)
    return nil
}

func send(_ fd: Int32, _ text: String) {
    var bytes = Array(text.utf8)[...]
    while !bytes.isEmpty {
        let written = bytes.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        if written <= 0 { return }
        bytes = bytes.dropFirst(written)
    }
}

/// Reads until `stop` returns true for the bytes so far, EOF, a timeout, or `limit` bytes.
func receive(_ fd: Int32, limit: Int = .max, until stop: ([UInt8]) -> Bool = { _ in false }) -> [UInt8] {
    var data: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 4096)
    while data.count < limit, !stop(data) {
        let count = read(fd, &chunk, chunk.count)
        if count <= 0 { break }
        data += chunk[..<count]
    }
    return data
}
