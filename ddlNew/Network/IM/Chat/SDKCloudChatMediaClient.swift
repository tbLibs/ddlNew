// Created by taobo on 2026/10/13.
import Foundation
import NoaChatCore
import ObjectMapper
import UniformTypeIdentifiers

/// 阿里云、AWS、腾讯和华为使用旧端STS与对象目录，上传和聊天ACK独立确认。
@MainActor final class SDKCloudChatMediaClient: ChatMediaClient {
    private var session: URLSession?
    private var generation = UUID()

    /// 每次取得临时凭据并流式上送，任何await后均核验用户、租户与认证轮次。
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        cancel(); let run = generation
        try validate(run, context: context)
        guard let plan = OSSConnectionBootstrap.shared.current, plan.lastLiceseId == context.tenantID,
              let provider = CloudStorageProvider(rawValue: LocalMediaSettings.ossConfigType) else { throw ChatClientError.invalidResponse }
        try checkPermission(attachment)
        let credentials = try await temporaryCredentials(provider: provider, context: context, run: run)
        try validate(run, context: context)
        let prepare = Task.detached { try LegacyChatMediaCodec.prepareUpload(file: attachment.file, type: attachment.type) }
        let prepared = try await withTaskCancellationHandler { try await prepare.value } onCancel: { prepare.cancel() }
        defer { if prepared != attachment.file { try? FileManager.default.removeItem(at: prepared) } }
        try validate(run, context: context)
        let day = DateFormatter(); day.locale = Locale(identifier: "en_US_POSIX"); day.dateFormat = "yyyyMMdd"
        let directory: String
        switch attachment.type { case 1: directory = "image"; case 2: directory = "shortvideo"; case 4: directory = "voice/mp3"; default: directory = "file" }
        let filename = UUID().uuidString + "-" + (attachment.name as NSString).lastPathComponent
            .components(separatedBy: .controlCharacters).joined()
        // 头像沿用旧端独立目录，不能写入聊天附件目录或套用聊天发送配额。
        let key = attachment.type == ChatAttachment.complaintEvidenceType ? "universal/\(filename)" : attachment.type == 101 ? "avatar_group/\(filename)" : attachment.type == ChatAttachment.userAvatarType ? "avatar/\(filename)" : "chat/\(day.string(from: Date()))/\(directory)/\(filename)"
        let bucket = provider == .huawei ? LocalMediaSettings.ossOBSBucketName : LocalMediaSettings.ossConfigBucketName
        let endpoint = provider == .huawei ? LocalMediaSettings.ossOBSEndPoint : LocalMediaSettings.ossConfigEndPoint
        let uploadURL = try objectURL(endpoint: provider == .huawei && !LocalMediaSettings.ossOBSUploadDomain.isEmpty ? LocalMediaSettings.ossOBSUploadDomain : endpoint,
            bucket: bucket, key: key, customDomain: provider == .huawei && !LocalMediaSettings.ossOBSUploadDomain.isEmpty)
        let downloadURL = try objectURL(endpoint: provider == .huawei && !LocalMediaSettings.ossOBSDownloadDomain.isEmpty ? LocalMediaSettings.ossOBSDownloadDomain : endpoint,
            bucket: bucket, key: key, customDomain: provider == .huawei && !LocalMediaSettings.ossOBSDownloadDomain.isEmpty)
        let hashTask = Task.detached { try CloudRequestSigner.fileHash(prepared) }
        let hash = try await withTaskCancellationHandler { try await hashTask.value } onCancel: { hashTask.cancel() }
        try validate(run, context: context); try checkPermission(attachment)
        var request = URLRequest(url: uploadURL); request.httpMethod = "PUT"
        request.setValue(UTType(filenameExtension: attachment.file.pathExtension)?.preferredMIMEType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
        let size = (try prepared.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
        request.setValue(String(size), forHTTPHeaderField: "Content-Length")
        request = try CloudRequestSigner.sign(request, provider: provider, credentials: credentials, bucket: bucket,
            objectKey: key, region: LocalMediaSettings.ossConfigRegionID, payloadHash: hash)
        let delegate = CloudUploadSessionDelegate { [weak self] value in
            guard let self, self.generation == run, ChatRuntime.shared.isCurrent(context) else { return }
            progress(value)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60; configuration.timeoutIntervalForResource = 900
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.session = session
        defer { session.finishTasksAndInvalidate(); if generation == run { self.session = nil } }
        let (_, response) = try await session.upload(for: request, fromFile: prepared)
        try validate(run, context: context); try checkPermission(attachment)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ChatClientError.unavailable("文件存储服务未接受上传，请稍后重试")
        }
        progress(1)
        return ChatUploadedAttachment(resource: downloadURL.absoluteString, thumbnail: "")
    }

    /// 根退出及页面取消令旧上传失效，同时停止在途网络请求。
    func cancel() { generation = UUID(); session?.invalidateAndCancel(); session = nil }

    /// STS走现有SDK的签名与解密，临时凭据不参与任何本地配置缓存。
    private func temporaryCredentials(provider: CloudStorageProvider, context: ChatContext, run: UUID) async throws -> CloudMediaCredentials {
        let waiter = SDKChatRequestWaiter<String>()
        let json = try await waiter.run {
            NoaIMSDKManager.sharedTool().userGetFileUploadTokenWith(onSuccess: { data, _ in
                let bytes = (data as? [String: Any]).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                let json = bytes.flatMap { String(data: $0, encoding: .utf8) }
                Task { @MainActor in
                    if let json { waiter.finish(.success(json)) } else { waiter.finish(.failure(ChatClientError.invalidResponse)) }
                }
            }, onFailure: { code, _, _ in
                Task { @MainActor in waiter.finish(.failure(ChatClientError.unavailable("获取临时上传资格失败（\(code)），请重试"))) }
            })
        }
        try validate(run, context: context)
        guard let payload = Mapper<CloudMediaCredentialPayload>().map(JSONString: json), let credentials = payload.credentials(for: provider) else {
            throw ChatClientError.unavailable("临时上传资格缺失或已过期，请稍后重试")
        }
        return credentials
    }

    /// 按普通桶域名或OBS独立域名生成对象地址，避免重复桶前缀和用户信息URL。
    private func objectURL(endpoint: String, bucket: String, key: String, customDomain: Bool) throws -> URL {
        guard !bucket.isEmpty, var components = URLComponents(string: endpoint.contains("://") ? endpoint : "https://" + endpoint),
              components.scheme == "https" || components.scheme == "http", let host = components.host,
              components.user == nil, components.password == nil, components.query == nil, components.fragment == nil else {
            throw ChatClientError.unavailable("文件存储节点配置无效")
        }
        if !customDomain && !host.hasPrefix(bucket + ".") { components.host = bucket + "." + host }
        // 云供应商使用系统验证的HTTPS，不能把临时STS资格通过明文HTTP发送。
        if components.scheme == "http" { components.scheme = "https"; if components.port == 80 { components.port = nil } }
        guard let base = components.url else { throw ChatClientError.invalidResponse }
        return base.appendingPathComponent(key)
    }

    /// 上传配额在准备、签名和最终提交前各校验一次，计算采用溢出检查。
    private func checkPermission(_ attachment: ChatAttachment) throws {
        guard attachment.bytes > 0 else { throw ChatClientError.permission("上传文件为空") }
        if attachment.type == ChatAttachment.userAvatarType {
            guard attachment.bytes <= 50 * 1024 else { throw ChatClientError.permission("头像图片过大") }
            return
        }
        // 101仅由群设置使用，调用方在上传前后校验实时群管理员权限。
        if attachment.type == 101 || attachment.type == ChatAttachment.complaintEvidenceType { return }
        guard let role = UserRoleAuthorityStore.shared.current else { throw ChatClientError.permission("当前没有附件发送权限") }
        if attachment.type == 4 { guard attachment.duration > 0, attachment.duration <= 60 else { throw ChatClientError.permission("语音最长60秒") }; return }
        let key = attachment.type == 5 ? "upFile" : "upImageVideoFile"
        guard role.allows(key) else { throw ChatClientError.permission("当前账号不允许发送此类附件") }
        if let raw = role.configurationData[key], !raw.isEmpty {
            guard let limit = Int64(raw), limit > 0 else { throw ChatClientError.permission("附件发送额度不可用") }
            let bytes = limit.multipliedReportingOverflow(by: 1024 * 1024)
            guard !bytes.overflow, attachment.bytes <= bytes.partialValue else { throw ChatClientError.permission("附件超过当前账号发送额度") }
        }
    }

    /// 同UID重新登录也使用不同认证轮次，不可继续消费原来的临时凭据。
    private func validate(_ run: UUID, context: ChatContext) throws {
        try Task<Never, Never>.checkCancellation()
        guard generation == run, ChatRuntime.shared.isCurrent(context),
              OSSConnectionBootstrap.shared.current?.lastLiceseId == context.tenantID else { throw CancellationError() }
    }
}
