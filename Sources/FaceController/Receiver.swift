import Foundation
import Network

/// Receives Live Link Face packets on a UDP port and keeps the latest frame.
final class Receiver {
    private(set) var latest: FaceFrame?
    private(set) var latestAt = Date.distantPast
    private(set) var packets = 0
    /// Called with each raw packet (for `FaceController raw`).
    var onPacket: ((Data) -> Void)?

    private var listener: NWListener?

    func start(port: UInt16) throws {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            self?.receive(on: connection)
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    /// The latest frame if it arrived recently enough to act on.
    var fresh: FaceFrame? { Date().timeIntervalSince(latestAt) < 0.5 ? latest : nil }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data {
                packets += 1
                onPacket?(data)
                if let frame = LiveLink.parse(data) {
                    latest = frame
                    latestAt = Date()
                }
            }
            if error == nil { receive(on: connection) }
        }
    }

    /// The Mac's address on the local network, for the iPhone app's target.
    static var localIP: String {
        var address = "this Mac's IP"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return address }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard ifa.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                  String(cString: ifa.ifa_name).hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len), &host, socklen_t(host.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                address = String(cString: host)
                break
            }
        }
        return address
    }
}
