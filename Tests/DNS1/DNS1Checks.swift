import Foundation
import CryptoKit
import Darwin

@main struct DNS1Checks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ message: String) { precondition(value, message); count += 1 }
        func rejects(_ operation: () throws -> Void) { do { try operation(); fatalError("应拒绝非法数据") } catch { count += 1 } }
        func records(_ text: String, first: Int = 1) -> [String] {
            var bytes = Array(text.utf8); bytes.append(0)
            while bytes.count % 14 != 0 { bytes.append(0) }
            return stride(from: 0, to: bytes.count, by: 14).map { start in
                let index = first + start / 14
                let block = [UInt8(index >> 8), UInt8(index & 255)] + Array(bytes[start..<(start + 14)])
                return stride(from: 0, to: 16, by: 2).map { String(Int(block[$0]) * 256 + Int(block[$0 + 1]), radix: 16) }.joined(separator: ":")
            }
        }
        let tcp = "node.example:2028,node2.example:10028"
        let payload = try DNS1Payload.decode(tcp, requireJSON: false)
        check(payload.tcp.count == 2 && payload.http.isEmpty, "纯 TCP CSV 可用")
        let fragments = records(tcp)
        check(try DNS1Payload.records(fragments.reversed() + [fragments[0]]) == payload, "乱序和重复分片")
        check(try DNS1Payload.records(records(tcp, first: 0)) == payload, "序号从0兼容")
        rejects { _ = try DNS1Payload.records(Array(fragments.dropFirst())) }
        rejects { _ = try DNS1Payload.records([fragments.first!, fragments.last!]) }
        rejects { _ = try DNS1Payload.records([fragments[0], records("bad.example:1")[0]]) }
        rejects { _ = try DNS1Payload.records(["bad IPv6"]) }
        rejects { _ = try DNS1Payload.decode("{bad,host:2028", requireJSON: false) }
        rejects { _ = try DNS1Payload.decode("{\"http\":[\"https://web.example\"]}", requireJSON: false) }
        for bad in ["wss://a.example:443/ws", "a:0", "a:65536", "a:-1", "u@a:1", "a:1/path", "::1:123", "a:1?x", "a:1#x", "-a:12"] {
            check(DNS1TCPNode(bad) == nil, "拒绝非法TCP: " + bad)
        }
        check(DNS1TCPNode("[::1]:123")?.host == "::1", "原生 IPv6")
        for bad in ["", "../1000", "a b", "邀请码", String(repeating: "a", count: 63)] {
            rejects { _ = try DNS1Payload.license(bad) }
        }
        let json = "{\"tcp\":[\"node.example:2028\"],\"http\":[\"http://files.example/base\",\"wss://bad.example/ws\"]}"
        let parsed = try DNS1Payload.decode(json, requireJSON: true)
        check(parsed.http.map(\.absoluteString) == ["http://files.example/base"], "HTTP 可选且保留协议和路径")
        let secret = Insecure.MD5.hash(data: Data("Ab1000".utf8)).map { String(format: "%02x", $0) }.joined()
        let cipher = AesEncryptUtils.encryptBytes(Data(json.utf8), secret: secret)!
        check(try DNS1Payload.bin(cipher, license: "Ab1000") == parsed, "原始 AES BIN")
        check(try DNS1Payload.bin(Data(cipher.base64EncodedString().utf8), license: "Ab1000") == parsed, "Base64 AES BIN")
        rejects { _ = try DNS1Payload.bin(cipher, license: "ab1000") }
        rejects { _ = try DNS1Payload.bin(Data(json.utf8), license: "Ab1000") }
        let sources = try DNS1SourceRace.sources(license: "Ab1000", main: "main.example", backup: "backup.example", binTemplate: "https://bin.example/nav_%s/npoint.bin")
        check(sources.map(\.address) == ["tab1000.main.example", "tab1000.backup.example", "https://bin.example/nav_Ab1000/npoint.bin"], "只用t，BIN保留原大小写")
        var calls: [DNS1Source.Kind] = []
        var probes = 0
        let winner = try await DNS1SourceRace.run(sources: sources, load: { source in
            calls.append(source.kind)
            if source.kind == .main { return payload }
            if source.kind == .backup { throw DNS1Error.unavailable }
            return parsed
        }, probe: { _ in probes += 1; return calls.last == .bin })
        check(calls == [.main, .backup, .bin] && winner.source.kind == .bin && probes == 3, "主域全部TCP不可用后继续备域和BIN")
        calls = []
        let cached = try await DNS1SourceRace.run(sources: sources, cached: parsed, load: { source in calls.append(source.kind); return payload }, probe: { _ in true })
        check(cached.source.kind == .cache && calls.isEmpty, "缓存命中不请求DNS")
        calls = []; probes = 0
        _ = try await DNS1SourceRace.run(sources: sources, cached: parsed, load: { source in calls.append(source.kind); return payload }, probe: { _ in probes += 1; return !calls.isEmpty })
        check(calls == [.main], "缓存失败后走新主域")
        let late = DNS1CallbackWaiter<Bool>()
        let task = Task { try await late.run(seconds: 10, start: {}) }
        await Task.yield(); task.cancel()
        do { _ = try await task.value; fatalError("取消必须失败") } catch is CancellationError { count += 1 }
        late.finish(.success(true)); late.finish(.success(false))
        let timeout = DNS1CallbackWaiter<Bool>()
        do { _ = try await timeout.run(seconds: 0.01, start: {}); fatalError("超时必须失败") } catch { count += 1 }
        timeout.finish(.success(true))
        let synchronous = DNS1CallbackWaiter<Bool>()
        check(try await synchronous.run(seconds: 1, start: { synchronous.finish(.success(true)) }), "同步回调只结束一次")
        calls = []
        let cancelled = Task {
            try await DNS1SourceRace.run(sources: sources, load: { source in
                calls.append(source.kind); try await Task.sleep(nanoseconds: 1_000_000_000); return payload
            }, probe: { _ in true })
        }
        while calls.isEmpty { await Task.yield() }
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("来源取消必须失败") } catch is CancellationError { count += 1 }
        check(calls == [.main], "取消不能启动备域或BIN")
        let mainOnly = try DNS1SourceRace.sources(license: "Ab1000", main: "main.example", backup: "", binTemplate: "https://bin.example/%s")
        check(mainOnly.map(\.kind) == [.main, .bin], "未配置备域直接进入BIN")
        calls = []
        let backupWinner = try await DNS1SourceRace.run(sources: sources, load: { source in
            calls.append(source.kind)
            if source.kind == .main { throw DNS1Error.unavailable }
            return parsed
        }, probe: { _ in true })
        check(backupWinner.source.kind == .backup && calls == [.main, .backup], "备域成功不请求BIN")
        calls = []
        do {
            _ = try await DNS1SourceRace.run(sources: sources, load: { source in
                calls.append(source.kind); throw DNS1Error.unavailable
            }, probe: { _ in fatalError("没有节点不能探测") })
            fatalError("来源耗尽必须失败")
        } catch DNS1Error.unavailable { count += 1 }
        check(calls == [.main, .backup, .bin], "来源耗尽后结束，不调用旧导航")
        print("DNS1 checks: \(count) passed")
    }
}
