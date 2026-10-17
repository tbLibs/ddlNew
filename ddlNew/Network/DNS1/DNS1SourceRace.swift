//
//  DNS1SourceRace.swift
//  ddlNew
//
//  Created by taobo on 2026/10/17.
//

import Foundation

nonisolated struct DNS1Source: Sendable, Equatable {
    enum Kind: String, Sendable { case cache, main, backup, bin }
    let kind: Kind
    let address: String
}

nonisolated struct DNS1Selection: Sendable {
    let source: DNS1Source
    let payload: DNS1Payload
    let node: DNS1TCPNode
}

/// 来源按顺序推进；某来源的数据虽合法但全部 ECDH 失败时仍需继续备域/BIN。
@MainActor enum DNS1SourceRace {
    static func sources(license: String, main: String, backup: String, binTemplate: String) throws -> [DNS1Source] {
        _ = try DNS1Payload.license(license)
        var sources: [DNS1Source] = []
        for (kind, domain) in [(DNS1Source.Kind.main, main), (.backup, backup)] where !domain.isEmpty {
            let name = "t" + license.lowercased() + "." + domain
            if !sources.contains(where: { $0.address == name }) { sources.append(DNS1Source(kind: kind, address: name)) }
        }
        // BIN 大小写沿用输入，只有 DNS 企业号转小写。
        sources.append(DNS1Source(kind: .bin, address: binTemplate.replacingOccurrences(of: "%s", with: license)))
        return sources
    }

    static func run(sources: [DNS1Source], cached: DNS1Payload? = nil,
                    load: @escaping @MainActor (DNS1Source) async throws -> DNS1Payload,
                    probe: @escaping @MainActor (DNS1TCPNode) async throws -> Bool) async throws -> DNS1Selection {
        var all = sources
        if cached != nil { all.insert(DNS1Source(kind: .cache, address: "cache"), at: 0) }
        for source in all {
            try Task.checkCancellation()
            do {
                let payload: DNS1Payload
                if source.kind == .cache, let cached { payload = cached }
                else { payload = try await load(source) }
                let node = try await withThrowingTaskGroup(of: DNS1TCPNode?.self) { group in
                    for node in payload.tcp {
                        group.addTask {
                            do { return try await probe(node) ? node : nil }
                            catch is CancellationError { throw CancellationError() }
                            catch { return nil }
                        }
                    }
                    defer { group.cancelAll() }
                    for try await result in group { if let result { return result } }
                    throw DNS1Error.unavailable
                }
                try Task.checkCancellation()
                return DNS1Selection(source: source, payload: payload, node: node)
            } catch is CancellationError { throw CancellationError() }
            catch { try Task.checkCancellation() }
        }
        throw DNS1Error.unavailable
    }
}
