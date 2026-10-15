//
//  SDKChatMediaClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import UniformTypeIdentifiers

/// Minio现有签名与分片合同；第三方云路由由独立provider扩展。
@MainActor final class SDKChatMediaClient: ChatMediaClient {
    private var session: URLSession?
    private var generation = UUID()
    private var cloudClient: (any ChatMediaClient)?
    private var previewTransfer: SDKChatMediaClient?

    /// 视频封面独立上传后填入封面URI，原视频URI保持真实资源身份。
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        let primary = try await uploadSingle(attachment, context: context, progress: progress)
        let run = generation
        if let preview = attachment.previewFile {
            let bytes = Int64(try preview.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            let child = SDKChatMediaClient(); previewTransfer = child
            defer { previewTransfer = nil }
            let uploaded = try await child.upload(ChatAttachment(file: preview, type: 1, name: preview.lastPathComponent, bytes: bytes), context: context, progress: { _ in })
            try validate(run, context: context)
            return ChatUploadedAttachment(resource: primary.resource, thumbnail: uploaded.resource)
        }
        return primary
    }

    /// 上传全程绑定认证身份，字节上传完成不代表聊天ACK。
    private func uploadSingle(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        cancel(); let run = generation
        guard ChatRuntime.shared.isCurrent(context), let plan = OSSConnectionBootstrap.shared.current,
              plan.lastLiceseId == context.tenantID,
              let config = SystemConfigStore.shared.load(apiHost: plan.apiHost) else { throw ChatClientError.sessionExpired }
        if config.ossConfigType != "0" {
            let cloud = SDKCloudChatMediaClient(); cloudClient = cloud
            defer { cloudClient = nil }
            let result = try await cloud.upload(attachment, context: context, progress: progress)
            try validate(run, context: context)
            return result
        }
        try checkPermission(attachment)
        let encodedFile = try await Task.detached { try LegacyChatMediaCodec.prepareUpload(file: attachment.file, type: attachment.type) }.value
        defer { if encodedFile != attachment.file { try? FileManager.default.removeItem(at: encodedFile) } }
        let uploadAttachment = ChatAttachment(file: encodedFile, type: attachment.type, name: attachment.name, bytes: Int64(try encodedFile.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0), duration: attachment.duration, width: attachment.width, height: attachment.height)
        let delegate = ChatTransferSessionDelegate(origin: plan.uploadFileHost)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.session = session
        defer { if generation == run { self.session = nil; session.finishTasksAndInvalidate() } }
        let fileName = UUID().uuidString + "-" + attachment.name.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\"", with: "")
        let keyRequest = try request(path: NetworkPath.chatUploadPublicKey, plan: plan, tenantCode: config.tenantCode, context: context)
        let (keyData, keyResponse) = try await session.data(for: keyRequest)
        try validate(run, context: context)
        guard let publicKey = try decode(keyData, response: keyResponse, tenantCode: config.tenantCode) as? String, !publicKey.isEmpty else { throw ChatClientError.invalidResponse }
        let bucket = bucketName(type: attachment.type)
        let result: Any
        if uploadAttachment.bytes > 100 * 1024 * 1024 {
            result = try await multipart(uploadAttachment, name: fileName, key: publicKey, bucket: bucket, plan: plan, config: config, context: context, run: run, session: session, progress: progress)
        } else {
            let boundary = UUID().uuidString
            let spool = try await Task.detached { try Self.spool(file: encodedFile, name: fileName, boundary: boundary) }.value
            defer { try? FileManager.default.removeItem(at: spool) }
            var req = try request(path: NetworkPath.chatUploadFile, query: ["bucketName": bucket], plan: plan, tenantCode: config.tenantCode, context: context, fileName: fileName, publicKey: publicKey)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let (data, response) = try await session.upload(for: req, fromFile: spool, delegate: ChatUploadProgressDelegate(progress: progress))
            try validate(run, context: context)
            result = try decode(data, response: response, tenantCode: config.tenantCode)
        }
        try validate(run, context: context); try checkPermission(attachment)
        guard let json = result as? [String: Any], let uri = json["uri"] as? String, !uri.isEmpty else { throw ChatClientError.invalidResponse }
        progress(1)
        return ChatUploadedAttachment(resource: uri, thumbnail: json["thumbnailUri"] as? String ?? "")
    }

    /// 分片顺序上送50MiB且最终合并确认，失败不伪造最终资源地址。
    private func multipart(_ attachment: ChatAttachment, name: String, key: String, bucket: String, plan: OSSConnectionPlan, config: SystemConfigRecord, context: ChatContext, run: UUID, session: URLSession, progress: @escaping @MainActor (Double) -> Void) async throws -> Any {
        let initRequest = try request(path: NetworkPath.chatUploadMultipartID, query: ["bucketName": bucket, "fileUri": name], plan: plan, tenantCode: config.tenantCode, context: context, fileName: name, publicKey: key)
        let (idData, idResponse) = try await session.data(for: initRequest)
        try validate(run, context: context)
        guard let uploadID = try decode(idData, response: idResponse, tenantCode: config.tenantCode) as? String, !uploadID.isEmpty else { throw ChatClientError.invalidResponse }
        let handle = try FileHandle(forReadingFrom: attachment.file); defer { try? handle.close() }
        var sent: Int64 = 0; var part = 1; var tags: [[String: Any]] = []
        while sent < attachment.bytes {
            try validate(run, context: context)
            guard let bytes = try handle.read(upToCount: 50 * 1024 * 1024), !bytes.isEmpty else { throw ChatClientError.unavailable("附件读取失败，请重新选择") }
            let chunk = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try bytes.write(to: chunk); defer { try? FileManager.default.removeItem(at: chunk) }
            let boundary = UUID().uuidString
            let spool = try await Task.detached { try Self.spool(file: chunk, name: name, boundary: boundary) }.value
            defer { try? FileManager.default.removeItem(at: spool) }
            var req = try request(path: NetworkPath.chatUploadMultipartPart, query: ["bucketName": bucket, "key": name, "partNumber": String(part), "uploadId": uploadID], plan: plan, tenantCode: config.tenantCode, context: context, fileName: name, publicKey: key)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let (data, response) = try await session.upload(for: req, fromFile: spool)
            try validate(run, context: context)
            guard let result = try decode(data, response: response, tenantCode: config.tenantCode) as? [String: Any], let tag = result["etag"] as? String else { throw ChatClientError.invalidResponse }
            tags.append(["partNumber": part, "tag": tag]); sent += Int64(bytes.count); part += 1
            progress(Double(sent) / Double(attachment.bytes) * 0.99)
        }
        var complete = try request(path: NetworkPath.chatUploadMultipartComplete, plan: plan, tenantCode: config.tenantCode, context: context, fileName: name, publicKey: key)
        complete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        complete.httpBody = try JSONSerialization.data(withJSONObject: ["bucketName": bucket, "eTagList": tags, "fileUri": name, "uploadId": uploadID])
        let (data, response) = try await session.data(for: complete)
        try validate(run, context: context)
        return try decode(data, response: response, tenantCode: config.tenantCode)
    }

    /// 保存multipart到临时文件并以1MiB读取，避免整个附件留在内存。
    nonisolated private static func spool(file: URL, name: String, boundary: String) throws -> URL {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let writer = try FileHandle(forWritingTo: output); defer { try? writer.close() }
        let reader = try FileHandle(forReadingFrom: file); defer { try? reader.close() }
        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        try writer.write(contentsOf: Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: \(mime)\r\n\r\n".utf8))
        while let bytes = try reader.read(upToCount: 1024 * 1024), !bytes.isEmpty { try writer.write(contentsOf: bytes) }
        try writer.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
        return output
    }

    /// 文件与图片视频分别读取角色配额，单位MB，语音按录制上限校验。
    private func checkPermission(_ attachment: ChatAttachment) throws {
        guard FileManager.default.fileExists(atPath: attachment.file.path) else { throw ChatClientError.unavailable("附件已不存在，请重新选择") }
        // 证据图不是聊天发送；只允许已认证的投诉客户端经通用目录上传。
        if attachment.type == ChatAttachment.complaintEvidenceType {
            guard attachment.bytes > 0 else { throw ChatClientError.unavailable("证据图片为空") }
            return
        }
        guard let role = UserRoleAuthorityStore.shared.current else { throw ChatClientError.permission("账号上传权限尚未就绪") }
        guard ![4, 101].contains(attachment.type) else { return }
        let key = attachment.type == 5 ? "upFile" : "upImageVideoFile"
        guard role.allows(key) else { throw ChatClientError.permission("当前账号不允许上传此附件") }
        let maxMB = Int64(role.configurationData[key] ?? "") ?? 0
        guard ChatAttachmentPolicy.allowedBytes(attachment.bytes, maximumMB: maxMB) else { throw ChatClientError.permission("附件超过当前账号允许的大小，请选择较小文件") }
    }

    /// 所有HTTP请求使用旧Minio真实签名、UID及上传公钥令牌。
    private func request(path: String, query: [String: String] = [:], plan: OSSConnectionPlan, tenantCode: String, context: ChatContext, fileName: String? = nil, publicKey: String? = nil) throws -> URLRequest {
        var components = URLComponents(url: plan.uploadFileHost.appendingPathComponent(String(path.dropFirst())), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw ChatClientError.invalidResponse }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        let timestamp = Int64(Date().timeIntervalSince1970)
        let signature: String
        #if targetEnvironment(simulator)
        throw SystemConfigCryptoError.unavailableOnSimulator
        #else
        let uri = path.replacingOccurrences(of: "/biz/", with: "").replacingOccurrences(of: "/auth/", with: "").replacingOccurrences(of: "/zim-file/", with: "").replacingOccurrences(of: "/file/", with: "")
        guard let signed = LXChatEncrypt.method5(tenantCode, uri: uri, timestamp: timestamp) else { throw SystemConfigCryptoError.signatureFailed }; signature = signed
        #endif
        var headers = BusinessRequestHeaders.make(timestamp: timestamp, signature: signature)
        headers["token"] = context.userUID
        if let fileName, let publicKey {
            #if !targetEnvironment(simulator)
            guard let token = LXChatEncrypt.method4(publicKey + fileName) else { throw SystemConfigCryptoError.signatureFailed }
            headers["osToken"] = token; headers["osFileName"] = fileName
            #endif
        }
        request.allHTTPHeaderFields = headers
        return request
    }

    /// 明文JSON先解析，密文仅按当前tenantCode解密；业务码必须10000。
    private func decode(_ data: Data, response: URLResponse, tenantCode: String) throws -> Any {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["code"] as? NSNumber)?.intValue == 10000, let payload = json["data"] else { throw ChatClientError.invalidResponse }
        guard let string = payload as? String else { return payload }
        if let plain = string.data(using: .utf8), let decoded = try? JSONSerialization.jsonObject(with: plain) { return decoded }
        #if targetEnvironment(simulator)
        throw SystemConfigCryptoError.unavailableOnSimulator
        #else
        guard let decrypted = LXChatEncrypt.method7(tenantCode, encryptData: string), !decrypted.isEmpty else { throw SystemConfigCryptoError.decryptionFailed }
        if let bytes = decrypted.data(using: .utf8), let decoded = try? JSONSerialization.jsonObject(with: bytes) { return decoded }
        return decrypted
        #endif
    }

    /// 存储桶路径沿旧服务日期和类型约定，避免云端收到错类型附件。
    private func bucketName(type: Int) -> String {
        if type == ChatAttachment.complaintEvidenceType { return "/zim/universal/" }
        if type == 101 { return "/zim/avatar_group/" }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd"
        let date = formatter.string(from: Date())
        let typePath = type == 2 ? "shortvideo" : type == 4 ? "voice/mp3" : type == 5 ? "file" : "image"
        return "/zim/\(date)/\(typePath)/"
    }

    /// 上传任一await返回后校验轮次及根认证所有权。
    private func validate(_ run: UUID, context: ChatContext) throws {
        try Task.checkCancellation()
        guard generation == run, ChatRuntime.shared.isCurrent(context) else { throw ChatClientError.sessionExpired }
    }

    /// 用户取消同时终止HTTP任务，旧回执不再交给消息队列。
    func cancel() { generation = UUID(); session?.invalidateAndCancel(); session = nil; cloudClient?.cancel(); cloudClient = nil; previewTransfer?.cancel(); previewTransfer = nil }
}
