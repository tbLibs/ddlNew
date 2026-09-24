//
//  DNSUDPResolver.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import CocoaAsyncSocket

/// 向旧项目指定的 DNS 服务器发送 UDP A 记录查询。
enum DNSUDPResolver {
    /// 使用 CocoaAsyncSocket 收发 UDP 报文，并将代理回调转成 async 结果。
    static func resolveA(domain: String, server: String) async -> [String] {
        if Task<Never, Never>.isCancelled { return [] }
        let transactionID = UInt16.random(in: UInt16.min...UInt16.max)
        guard let packet = makeQuery(domain: domain, transactionID: transactionID) else {
            return []
        }

        let query = DNSUDPQuery(server: server, packet: Data(packet), transactionID: transactionID)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                query.start(continuation: continuation)
            }
        } onCancel: {
            DispatchQueue.main.async {
                query.cancel()
            }
        }
    }

    private static func makeQuery(domain: String, transactionID: UInt16) -> [UInt8]? {
        let labels = domain.lowercased().split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty, domain.utf8.count <= 253 else { return nil }
        // DNS 报文头：递归查询 RD=1，问题数 QDCOUNT=1。
        var query: [UInt8] = [
            UInt8(truncatingIfNeeded: transactionID >> 8),
            UInt8(truncatingIfNeeded: transactionID),
            0x01, 0x00, 0x00, 0x01, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]
        for label in labels {
            let bytes = Array(label.utf8)
            guard !bytes.isEmpty, bytes.count <= 63 else { return nil }
            query.append(UInt8(bytes.count))
            query.append(contentsOf: bytes)
        }
        // QNAME 以 0 结束，随后写入 QTYPE=A、QCLASS=IN。
        query.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x01])
        return query
    }

    fileprivate static func parseResponse(_ bytes: [UInt8], transactionID: UInt16) -> [String] {
        // 校验事务 ID、响应标志和 RCODE，避免误收其他 UDP 报文。
        guard bytes.count >= 12,
              readUInt16(bytes, at: 0) == transactionID,
              bytes[2] & 0x80 != 0,
              bytes[3] & 0x0F == 0 else { return [] }

        let questionCount = Int(readUInt16(bytes, at: 4))
        let answerCount = Int(readUInt16(bytes, at: 6))
        var index = 12
        for _ in 0..<questionCount {
            guard skipName(bytes, index: &index), index + 4 <= bytes.count else { return [] }
            index += 4
        }

        // 跳过非 A/IN 记录，只提取长度为 4 字节的 IPv4 地址。
        var addresses: [String] = []
        for _ in 0..<answerCount {
            guard skipName(bytes, index: &index), index + 10 <= bytes.count else { break }
            let recordType = readUInt16(bytes, at: index)
            let recordClass = readUInt16(bytes, at: index + 2)
            let length = Int(readUInt16(bytes, at: index + 8))
            index += 10
            guard index + length <= bytes.count else { break }
            if recordType == 1, recordClass == 1, length == 4 {
                addresses.append("\(bytes[index]).\(bytes[index + 1]).\(bytes[index + 2]).\(bytes[index + 3])")
            }
            index += length
        }
        return addresses
    }

    private static func skipName(_ bytes: [UInt8], index: inout Int) -> Bool {
        while index < bytes.count {
            let length = bytes[index]
            if length == 0 {
                index += 1
                return true
            }
            if length & 0xC0 == 0xC0 {
                // DNS 名称压缩指针占两个字节，无须沿指针解析即可跳到后续字段。
                index += 2
                return index <= bytes.count
            }
            guard length & 0xC0 == 0 else { return false }
            index += 1 + Int(length)
        }
        return false
    }

    private static func readUInt16(_ bytes: [UInt8], at index: Int) -> UInt16 {
        (UInt16(bytes[index]) << 8) | UInt16(bytes[index + 1])
    }
}

/// 每次查询独占一个 UDP Socket，所有状态都在主队列串行处理。
@MainActor
private final class DNSUDPQuery: NSObject, GCDAsyncUdpSocketDelegate {
    private let server: String
    private let packet: Data
    private let transactionID: UInt16
    private var socket: GCDAsyncUdpSocket?
    private var continuation: CheckedContinuation<[String], Never>?
    private var isCancelled = false

    init(server: String, packet: Data, transactionID: UInt16) {
        self.server = server
        self.packet = packet
        self.transactionID = transactionID
    }

    func start(continuation: CheckedContinuation<[String], Never>) {
        self.continuation = continuation
        guard !isCancelled else {
            finish([])
            return
        }

        let socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: .main)
        self.socket = socket
        do {
            // 先绑定临时端口并开始接收，避免 DNS 回复早于接收启动。
            try socket.bind(toPort: 0)
            try socket.beginReceiving()
            socket.send(packet, toHost: server, port: 53, withTimeout: 0.5, tag: 0)
        } catch {
            finish([])
            return
        }

        // UDP 没有响应时也必须恢复 continuation，避免调用方一直等待。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.finish([])
        }
    }

    func cancel() {
        isCancelled = true
        finish([])
    }

    private func finish(_ addresses: [String]) {
        guard let continuation else { return }
        self.continuation = nil
        socket?.close()
        socket = nil
        continuation.resume(returning: addresses)
    }

    @objc(udpSocket:didReceiveData:fromAddress:withFilterContext:)
    func udpSocket(
        _ sock: GCDAsyncUdpSocket,
        didReceive data: Data,
        fromAddress address: Data,
        withFilterContext filterContext: Any?
    ) {
        let bytes = Array(data)
        guard bytes.count >= 2,
              (UInt16(bytes[0]) << 8) | UInt16(bytes[1]) == transactionID else { return }
        finish(DNSUDPResolver.parseResponse(bytes, transactionID: transactionID))
    }

    @objc(udpSocket:didNotSendDataWithTag:dueToError:)
    func udpSocket(
        _ sock: GCDAsyncUdpSocket,
        didNotSendDataWithTag tag: Int,
        dueToError error: Error?
    ) {
        finish([])
    }

    @objc(udpSocketDidClose:withError:)
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        finish([])
    }
}
