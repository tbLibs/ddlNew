//
//  OSSNavigationRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import ObjectMapper

/// 按旧项目 NoaSsoInfoModel 的顶层结构保存邀请码和竞速节点。
nonisolated struct OSSNavigationRecord: Mappable {
    private var schemaVersion = 3
    var liceseId = ""
    var lastLiceseId = ""
    var ossRacingModel = OSSNetRacingRecord()
    var ipDomainPortStr = ""
    var lastIPDomainPortStr = ""
    /// 旧 SSO 模型没有的兜底地址、服务端配置和缓存时间放在导航扩展中。
    private var navigation = OSSNavigationPayloadRecord()

    init(appID: String, source: DNSHostSource, ossNode: DNSResolvedHost,
         savedAt: Date, body: IMServerListResponseBody,
         previous: OSSNavigationRecord? = nil) throws {
        let result = try OSSAuthResponseDecoder.navigation(from: body)
        liceseId = appID
        lastLiceseId = previous?.lastLiceseId ?? ""
        ipDomainPortStr = previous?.ipDomainPortStr ?? ""
        lastIPDomainPortStr = previous?.lastIPDomainPortStr ?? ""
        ossRacingModel = OSSNetRacingRecord(appID: appID, body: body, result: result)
        navigation = OSSNavigationPayloadRecord(
            source: source,
            ossNode: ossNode,
            savedAt: savedAt,
            body: body
        )
    }

    init?(map: Map) {
        guard map.JSON["schemaVersion"] as? Int == 3 else { return nil }
    }

    mutating func mapping(map: Map) {
        schemaVersion <- map["schemaVersion"]
        liceseId <- map["liceseId"]
        lastLiceseId <- map["lastLiceseId"]
        ossRacingModel <- map["ossRacingModel"]
        ipDomainPortStr <- map["ipDomainPortStr"]
        lastIPDomainPortStr <- map["lastIPDomainPortStr"]
        navigation <- map["navigation"]
    }

    /// 校验旧模型节点列表与导航响应一致，避免缓存两份地址发生分歧。
    func snapshot(for requestedAppID: String) throws -> OSSNavigationSnapshot {
        guard schemaVersion == 3, liceseId == requestedAppID else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        let snapshot = try navigation.snapshot(for: requestedAppID)
        guard ossRacingModel.matches(snapshot) else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        return snapshot
    }
}

/// 旧模型的 ossRacingModel：当前 OSS Auth 路径填充扁平 HTTP/TCP 列表。
nonisolated struct OSSNetRacingRecord: Mappable {
    var version = ""
    var appKey = ""
    var endpoints: OSSNetRacingEndpointsRecord?
    var isMergeVersion = false
    var pingIntervalSecond = 0
    var oldHttpNodeArr: [String] = []
    var httpNodeArr: [String] = []
    var httpArr: [OSSNetRacingItemRecord] = []
    var tcpArr: [OSSNetRacingItemRecord] = []

    init() {}

    init(appID: String, body: IMServerListResponseBody, result: OSSNavigationResult) {
        version = body.hasMeta ? body.meta.navVersion : ""
        appKey = appID
        httpArr = result.httpEndpoints.map { endpoint in
            let address = endpoint.ip.filter { $0 == ":" }.count > 1 && !endpoint.ip.hasPrefix("[")
                ? "[\(endpoint.ip)]:\(endpoint.port)"
                : "\(endpoint.ip):\(endpoint.port)"
            return OSSNetRacingItemRecord(ip: address, sort: Int(endpoint.port))
        }
        tcpArr = result.tcpEndpoints.map {
            OSSNetRacingItemRecord(ip: $0.ip, sort: Int($0.port))
        }
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        version <- map["version"]
        appKey <- map["appKey"]
        endpoints <- map["endpoints"]
        isMergeVersion <- map["is_merge_version"]
        pingIntervalSecond <- map["ping_interval_second"]
        oldHttpNodeArr <- map["oldHttpNodeArr"]
        httpNodeArr <- map["httpNodeArr"]
        httpArr <- map["httpArr"]
        tcpArr <- map["tcpArr"]
        // 当前 OSS Auth 不返回证书或私钥，不能把这些敏感字段写进 AppStorage。
    }

    func matches(_ snapshot: OSSNavigationSnapshot) -> Bool {
        let expected = OSSNetRacingRecord(
            appID: snapshot.appID,
            body: snapshot.body,
            result: OSSNavigationResult(
                body: snapshot.body,
                tcpEndpoints: snapshot.tcpEndpoints,
                httpEndpoints: snapshot.httpEndpoints
            )
        )
        return appKey == expected.appKey &&
            httpArr == expected.httpArr && tcpArr == expected.tcpArr
    }
}

/// 保留老模型 endpoints.http/tcp 的形状；当前 Protobuf 路径没有这组旧版 DNS/IP 分类。
nonisolated struct OSSNetRacingEndpointsRecord: Mappable {
    var http: OSSNetRacingProtocolRecord?
    var tcp: OSSNetRacingProtocolRecord?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        http <- map["http"]
        tcp <- map["tcp"]
    }
}

nonisolated struct OSSNetRacingProtocolRecord: Mappable {
    var dnsList: [OSSNetRacingItemRecord] = []
    var ipList: [OSSNetRacingItemRecord] = []

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        dnsList <- map["dnsList"]
        ipList <- map["ipList"]
    }
}

/// 与旧 NoaNetRacingItemModel 的 ip/sort 字段一致。
nonisolated struct OSSNetRacingItemRecord: Mappable, Equatable {
    var ip = ""
    var sort = 0

    init(ip: String, sort: Int) {
        self.ip = ip
        self.sort = sort
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        ip <- map["ip"]
        sort <- map["sort"]
    }
}

/// 新协议的附加导航信息，不与旧 SSO 顶层字段混在一起。
nonisolated private struct OSSNavigationPayloadRecord: Mappable {
    var source = ""
    var ossAddress = ""
    var ossType = ""
    var savedAt: Double = 0
    var body = OSSNavigationBodyRecord()

    init() {}

    init(source: DNSHostSource, ossNode: DNSResolvedHost,
         savedAt: Date, body: IMServerListResponseBody) {
        self.source = source.rawValue
        ossAddress = ossNode.urlString
        ossType = ossNode.type
        self.savedAt = savedAt.timeIntervalSince1970
        self.body = OSSNavigationBodyRecord(body)
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        source <- map["source"]
        ossAddress <- map["ossAddress"]
        ossType <- map["ossType"]
        savedAt <- map["savedAt"]
        body <- map["body"]
    }

    /// 缓存恢复后重新筛选端点，不把损坏数据交给连接层。
    func snapshot(for requestedAppID: String) throws -> OSSNavigationSnapshot {
        guard let source = DNSHostSource(rawValue: source),
              !ossAddress.isEmpty,
              savedAt.isFinite, savedAt > 0 else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        let responseBody = try body.makeResponseBody()
        let navigation = try OSSAuthResponseDecoder.navigation(from: responseBody)
        return OSSNavigationSnapshot(
            appID: requestedAppID,
            source: source,
            ossNode: DNSResolvedHost(urlString: ossAddress, type: ossType),
            savedAt: Date(timeIntervalSince1970: savedAt),
            body: responseBody,
            tcpEndpoints: navigation.tcpEndpoints,
            httpEndpoints: navigation.httpEndpoints
        )
    }
}

/// 读取上一版 v2 缓存后转成 SSO 结构，避免已保存的导航节点失效。
nonisolated struct OSSLegacyNavigationRecord: Mappable {
    private var version = 2
    private var appID = ""
    private var source = ""
    private var ossAddress = ""
    private var ossType = ""
    private var savedAt: Double = 0
    private var body = OSSNavigationBodyRecord()

    init?(map: Map) {
        guard map.JSON["version"] as? Int == 2 else { return nil }
    }

    mutating func mapping(map: Map) {
        version <- map["version"]
        appID <- map["appID"]
        source <- map["source"]
        ossAddress <- map["ossAddress"]
        ossType <- map["ossType"]
        savedAt <- map["savedAt"]
        body <- map["body"]
    }

    func snapshot(for requestedAppID: String) throws -> OSSNavigationSnapshot {
        guard version == 2, appID == requestedAppID,
              let source = DNSHostSource(rawValue: source),
              !ossAddress.isEmpty, savedAt.isFinite, savedAt > 0 else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        let responseBody = try body.makeResponseBody()
        let navigation = try OSSAuthResponseDecoder.navigation(from: responseBody)
        return OSSNavigationSnapshot(
            appID: appID,
            source: source,
            ossNode: DNSResolvedHost(urlString: ossAddress, type: ossType),
            savedAt: Date(timeIntervalSince1970: savedAt),
            body: responseBody,
            tcpEndpoints: navigation.tcpEndpoints,
            httpEndpoints: navigation.httpEndpoints
        )
    }
}

/// 响应体只映射已定义字段，重新构造 Protobuf 后沿用同一套端点校验。
nonisolated private struct OSSNavigationBodyRecord: Mappable {
    var endpoints: [OSSNavigationEndpointRecord] = []
    var meta: OSSNavigationMetaRecord?
    var fallback: OSSNavigationFallbackRecord?
    var cacheTTL: Int64 = 0

    init() {}

    init(_ body: IMServerListResponseBody) {
        endpoints = body.imEndpoints.map(OSSNavigationEndpointRecord.init)
        if body.hasMeta { meta = OSSNavigationMetaRecord(body.meta) }
        if body.hasFallbackEndpoints {
            fallback = OSSNavigationFallbackRecord(body.fallbackEndpoints)
        }
        cacheTTL = body.cacheTtl
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        endpoints <- map["endpoints"]
        meta <- map["meta"]
        fallback <- map["fallback"]
        cacheTTL <- map["cacheTTL"]
    }

    func makeResponseBody() throws -> IMServerListResponseBody {
        var body = IMServerListResponseBody()
        body.imEndpoints = try endpoints.map { try $0.makeEndpoint() }
        if let meta { body.meta = try meta.makeMeta() }
        if let fallback { body.fallbackEndpoints = fallback.makeFallback() }
        body.cacheTtl = cacheTTL
        return body
    }
}

/// 保留节点的连接地址、协议及竞速可能使用的权重等元数据。
nonisolated private struct OSSNavigationEndpointRecord: Mappable {
    var ip = ""
    var port = 0
    var weight = 0
    var region = ""
    var status = ""
    var latency: Int64 = 0
    var serverID = ""
    var clusterID = ""
    var load = 0
    var protocols: [String] = []

    init(_ endpoint: IMServerEndpoint) {
        ip = endpoint.ip
        port = Int(endpoint.port)
        weight = Int(endpoint.weight)
        region = endpoint.region
        status = endpoint.status
        latency = endpoint.latency
        serverID = endpoint.serverID
        clusterID = endpoint.clusterID
        load = Int(endpoint.load)
        protocols = endpoint.protocols
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        ip <- map["ip"]
        port <- map["port"]
        weight <- map["weight"]
        region <- map["region"]
        status <- map["status"]
        latency <- map["latency"]
        serverID <- map["serverID"]
        clusterID <- map["clusterID"]
        load <- map["load"]
        protocols <- map["protocols"]
    }

    func makeEndpoint() throws -> IMServerEndpoint {
        guard let port = Int32(exactly: port),
              let weight = Int32(exactly: weight),
              let load = Int32(exactly: load) else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        var endpoint = IMServerEndpoint()
        endpoint.ip = ip
        endpoint.port = port
        endpoint.weight = weight
        endpoint.region = region
        endpoint.status = status
        endpoint.latency = latency
        endpoint.serverID = serverID
        endpoint.clusterID = clusterID
        endpoint.load = load
        endpoint.protocols = protocols
        return endpoint
    }
}

/// 元数据与可选配置保持原协议的存在性。
nonisolated private struct OSSNavigationMetaRecord: Mappable {
    var navVersion = ""
    var config: OSSNavigationConfigRecord?
    var nextUpdateTime: Int64 = 0
    var traceID = ""

    init(_ meta: NavigationMeta) {
        navVersion = meta.navVersion
        if meta.hasConfig { config = OSSNavigationConfigRecord(meta.config) }
        nextUpdateTime = meta.nextUpdateTime
        traceID = meta.traceID
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        navVersion <- map["navVersion"]
        config <- map["config"]
        nextUpdateTime <- map["nextUpdateTime"]
        traceID <- map["traceID"]
    }

    func makeMeta() throws -> NavigationMeta {
        var meta = NavigationMeta()
        meta.navVersion = navVersion
        if let config { meta.config = try config.makeConfig() }
        meta.nextUpdateTime = nextUpdateTime
        meta.traceID = traceID
        return meta
    }
}

/// 服务端配置供后续连接超时、重试及网络探测使用。
nonisolated private struct OSSNavigationConfigRecord: Mappable {
    var connectTimeout = 0
    var readTimeout = 0
    var maxRetryCount = 0
    var raceTimeout = 0
    var cacheDuration = 0
    var enableNetworkDetect = false
    var sentryUrls: [String] = []
    var loganUrls: [String] = []

    init(_ config: NavigationConfig) {
        connectTimeout = Int(config.connectTimeout)
        readTimeout = Int(config.readTimeout)
        maxRetryCount = Int(config.maxRetryCount)
        raceTimeout = Int(config.raceTimeout)
        cacheDuration = Int(config.cacheDuration)
        enableNetworkDetect = config.enableNetworkDetect
        sentryUrls = config.sentryUrls
        loganUrls = config.loganUrls
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        connectTimeout <- map["connectTimeout"]
        readTimeout <- map["readTimeout"]
        maxRetryCount <- map["maxRetryCount"]
        raceTimeout <- map["raceTimeout"]
        cacheDuration <- map["cacheDuration"]
        enableNetworkDetect <- map["enableNetworkDetect"]
        sentryUrls <- map["sentryUrls"]
        loganUrls <- map["loganUrls"]
    }

    func makeConfig() throws -> NavigationConfig {
        guard let connectTimeout = Int32(exactly: connectTimeout),
              let readTimeout = Int32(exactly: readTimeout),
              let maxRetryCount = Int32(exactly: maxRetryCount),
              let raceTimeout = Int32(exactly: raceTimeout),
              let cacheDuration = Int32(exactly: cacheDuration) else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        var config = NavigationConfig()
        config.connectTimeout = connectTimeout
        config.readTimeout = readTimeout
        config.maxRetryCount = maxRetryCount
        config.raceTimeout = raceTimeout
        config.cacheDuration = cacheDuration
        config.enableNetworkDetect = enableNetworkDetect
        config.sentryUrls = sentryUrls
        config.loganUrls = loganUrls
        return config
    }
}

/// 国内与海外兜底导航地址分别映射，避免空数组覆盖旧的非空地址。
nonisolated private struct OSSNavigationFallbackRecord: Mappable {
    var domestic: [String] = []
    var overseas: [String] = []

    init(_ fallback: FallbackEndpoints) {
        domestic = fallback.domestic
        overseas = fallback.overseas
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        domestic <- map["domestic"]
        overseas <- map["overseas"]
    }

    func makeFallback() -> FallbackEndpoints {
        var fallback = FallbackEndpoints()
        fallback.domestic = domestic
        fallback.overseas = overseas
        return fallback
    }
}
