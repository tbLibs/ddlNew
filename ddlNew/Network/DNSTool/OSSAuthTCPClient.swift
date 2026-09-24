//
//  OSSAuthTCPClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import CocoaAsyncSocket
import Foundation
import SwiftProtobuf

enum OSSAuthTCPError: Error {
    case invalidAddress
    case invalidPort
    case invalidTimeout
    case emptyRequest
    case requestTooLarge
    case malformedResponseLength
    case responseTooLarge
    case timeout
    case connectionClosed
}

/// 单节点直连：只处理 TCP 和 Protobuf 帧，不判断导航业务状态，也不解密响应体。
enum OSSAuthTCPClient {
    private static let defaultPort: UInt16 = 8087
    private static let maxMessageLength = 1_048_576

    static func request(
        _ message: NavMessage,
        to node: DNSResolvedHost,
        timeout: TimeInterval = 2.5
    ) async throws -> NavMessage {
        guard timeout.isFinite, timeout > 0 else { throw OSSAuthTCPError.invalidTimeout }
        let endpoint = try parseEndpoint(node.urlString)
        let body = try message.serializedData()
        guard !body.isEmpty else { throw OSSAuthTCPError.emptyRequest }
        guard body.count <= maxMessageLength else { throw OSSAuthTCPError.requestTooLarge }

        // 旧协议在 Protobuf 消息前加 varint32 长度；TCP 本身没有消息边界。
        var length = UInt32(body.count)
        var packet = Data()
        repeat {
            var byte = UInt8(length & 0x7F)
            length >>= 7
            if length != 0 { byte |= 0x80 }
            packet.append(byte)
        } while length != 0
        packet.append(body)

        let connection = OSSAuthTCPConnection(
            endpoint: endpoint,
            packet: packet,
            timeout: timeout,
            maxMessageLength: maxMessageLength
        )
        return try await connection.run()
    }

    private static func parseEndpoint(_ address: String) throws -> OSSAuthTCPEndpoint {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("/"), !value.contains(" ") else {
            throw OSSAuthTCPError.invalidAddress
        }

        let host: String
        let port: UInt16
        if value.hasPrefix("[") {
            guard let closing = value.firstIndex(of: "]") else {
                throw OSSAuthTCPError.invalidAddress
            }
            host = String(value[value.index(after: value.startIndex)..<closing])
            let suffix = value[value.index(after: closing)...]
            if suffix.isEmpty {
                port = defaultPort
            } else {
                guard suffix.first == ":", let parsed = UInt16(suffix.dropFirst()), parsed > 0 else {
                    throw OSSAuthTCPError.invalidPort
                }
                port = parsed
            }
        } else if value.filter({ $0 == ":" }).count == 1 {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, let parsed = UInt16(parts[1]), parsed > 0 else {
                throw OSSAuthTCPError.invalidPort
            }
            host = String(parts[0])
            port = parsed
        } else {
            // 裸 IPv6 或无端口的域名沿用旧项目的 8087 默认端口。
            host = value
            port = defaultPort
        }

        guard !host.isEmpty else { throw OSSAuthTCPError.invalidAddress }
        return OSSAuthTCPEndpoint(host: host, port: port)
    }
}

private struct OSSAuthTCPEndpoint: Sendable {
    let host: String
    let port: UInt16
}

/// 每次请求独占一个 Socket；可变状态只在 delegateQueue 上读写。
private final class OSSAuthTCPConnection: NSObject, GCDAsyncSocketDelegate {
    private enum Tag {
        static let packet = 1
        static let lengthByte = 2
        static let responseBody = 3
    }

    private let endpoint: OSSAuthTCPEndpoint
    private let packet: Data
    private let timeout: TimeInterval
    private let maxMessageLength: Int
    private let delegateQueue = DispatchQueue(label: "ddlNew.ossAuthTCP", qos: .utility)
    private var socket: GCDAsyncSocket?
    private var timer: DispatchSourceTimer?
    private var continuation: CheckedContinuation<NavMessage, Error>?
    private var cancellationRequested = false
    private var responseLength: UInt32 = 0
    private var lengthByteCount = 0

    init(endpoint: OSSAuthTCPEndpoint, packet: Data, timeout: TimeInterval, maxMessageLength: Int) {
        self.endpoint = endpoint
        self.packet = packet
        self.timeout = timeout
        self.maxMessageLength = maxMessageLength
    }

    func run() async throws -> NavMessage {
        try Task<Never, Never>.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegateQueue.async {
                    self.start(continuation: continuation)
                }
            }
        } onCancel: {
            delegateQueue.async {
                self.cancellationRequested = true
                self.finish(.failure(CancellationError()))
            }
        }
    }

    private func start(continuation: CheckedContinuation<NavMessage, Error>) {
        self.continuation = continuation
        guard !cancellationRequested else {
            finish(.failure(CancellationError()))
            return
        }

        // 连接、发送和完整接收共用一个总时限，避免单节点长期占用竞速名额。
        let timer = DispatchSource.makeTimerSource(queue: delegateQueue)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [weak self] in
            self?.finish(.failure(OSSAuthTCPError.timeout))
        }
        self.timer = timer
        timer.resume()

        let socket = GCDAsyncSocket(delegate: self, delegateQueue: delegateQueue)
        self.socket = socket
        do {
            try socket.connect(toHost: endpoint.host, onPort: endpoint.port, withTimeout: timeout)
        } catch {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<NavMessage, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timer?.cancel()
        timer = nil
        socket?.disconnect()
        socket = nil
        continuation.resume(with: result)
    }

    @objc(socket:didConnectToHost:port:)
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        guard continuation != nil else { return }
        sock.write(packet, withTimeout: timeout, tag: Tag.packet)
        sock.readData(toLength: 1, withTimeout: timeout, tag: Tag.lengthByte)
    }

    @objc(socket:didReadData:withTag:)
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        guard continuation != nil else { return }
        switch tag {
        case Tag.lengthByte:
            readLengthByte(data, from: sock)
        case Tag.responseBody:
            guard data.count == Int(responseLength) else {
                finish(.failure(OSSAuthTCPError.malformedResponseLength))
                return
            }
            do {
                finish(.success(try NavMessage(serializedBytes: data)))
            } catch {
                finish(.failure(error))
            }
        default:
            finish(.failure(OSSAuthTCPError.malformedResponseLength))
        }
    }

    private func readLengthByte(_ data: Data, from sock: GCDAsyncSocket) {
        guard data.count == 1, let byte = data.first else {
            finish(.failure(OSSAuthTCPError.malformedResponseLength))
            return
        }
        // uint32 最多 5 字节；第 5 字节只能使用低 4 位。
        guard lengthByteCount < 5,
              lengthByteCount < 4 || byte & 0xF0 == 0 else {
            finish(.failure(OSSAuthTCPError.malformedResponseLength))
            return
        }
        responseLength |= UInt32(byte & 0x7F) << (lengthByteCount * 7)
        lengthByteCount += 1

        if byte & 0x80 != 0 {
            guard lengthByteCount < 5 else {
                finish(.failure(OSSAuthTCPError.malformedResponseLength))
                return
            }
            sock.readData(toLength: 1, withTimeout: timeout, tag: Tag.lengthByte)
            return
        }

        guard responseLength > 0 else {
            finish(.failure(OSSAuthTCPError.malformedResponseLength))
            return
        }
        guard Int(responseLength) <= maxMessageLength else {
            finish(.failure(OSSAuthTCPError.responseTooLarge))
            return
        }
        sock.readData(toLength: UInt(responseLength), withTimeout: timeout, tag: Tag.responseBody)
    }

    @objc(socketDidDisconnect:withError:)
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError error: Error?) {
        finish(.failure(error ?? OSSAuthTCPError.connectionClosed))
    }
}
