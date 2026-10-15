//
//  ComplaintChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor private final class ComplaintMock: ComplaintClient {
    var uploaded = 0
    var submitted: [[String: String]] = []
    var error: Error?
    var failAtUpload: Int?
    var submitError: Error?
    var pending: CheckedContinuation<String, Error>?
    var delay = false
    /// 上传替身仅返回受控资源，提交顺序由生产Store决定。
    func upload(_ file: URL, context: ChatContext) async throws -> String {
        uploaded += 1
        if let error { throw error }
        if failAtUpload == uploaded { throw URLError(.networkConnectionLost) }
        if delay { return try await withCheckedThrowingContinuation { pending = $0 } }
        return "/zim/universal/evidence-\(uploaded).jpg"
    }
    func submit(_ parameters: [String: String], context: ChatContext) async throws { if let submitError { throw submitError }; submitted.append(parameters) }
    func cancel() {}
}

@main struct ComplaintChecks {
    /// 校验旧协议字段和上传失败、取消、重复及会话关闭，不提交真实举报。
    @MainActor static func main() async throws {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let prepared = try ComplaintImagePreparation.prepare(png)
        defer { try? FileManager.default.removeItem(at: prepared) }
        let preparedSource = CGImageSourceCreateWithURL(prepared as CFURL, nil)!
        precondition(CGImageSourceGetType(preparedSource) as String? == UTType.jpeg.identifier, "证据准备必须生成真实JPEG")
        do { _ = try ComplaintImagePreparation.prepare(Data("invalid".utf8)); preconditionFailure("不可解码图片不得上传") } catch {}
        let file = URL(fileURLWithPath: "/tmp/anonymous-evidence.jpg")
        let context = ChatContext(userUID: "A", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "B", kind: .single, title: "", avatarURL: ""))
        let draft = ComplaintDraft(reason: .fraud, content: "说明🙂", email: " user@example.technology ", images: [file])
        let parameters = try draft.parameters(target: .user("B"), userUID: "A", nickname: "甲", account: "tester", uploaded: ["/zim/universal/evidence.jpg"])
        precondition(parameters["ufbToType"] == "0" && parameters["ufbToUserId"] == "B" && parameters["ufbContentGroup"] == "8")
        precondition(parameters["ufbUserEmail"] == "user@example.technology" && parameters["ufbImages"] == "/zim/universal/evidence.jpg")
        precondition(parameters["ufbToGroupId"] == nil && parameters["productCode"] == nil && parameters["ufbTo"] == nil)
        let group = try draft.parameters(target: .group("g"), userUID: "A", nickname: "甲", account: "tester", uploaded: ["one"])
        precondition(group["ufbToType"] == "1" && group["ufbToGroupId"] == "g" && group["ufbToUserId"] == nil)
        let general = try draft.parameters(target: .general, userUID: "A", nickname: "甲", account: "tester", uploaded: ["one"])
        precondition(general["ufbToType"] == "3" && general["ufbToUserId"] == nil && general["ufbToGroupId"] == nil)
        for invalid in [ComplaintDraft(reason: .other, content: "", email: "invalid", images: [file]), ComplaintDraft(reason: .other, content: "", email: "a@b.com", images: []), ComplaintDraft(reason: .other, content: String(repeating: "字", count: 201), email: "a@b.com", images: [file]), ComplaintDraft(reason: .other, content: "", email: "a@b.com", images: Array(repeating: file, count: 10))] {
            precondition(invalid.validationMessage != nil)
        }
        do { _ = try draft.parameters(target: .user(""), userUID: "A", nickname: "", account: "", uploaded: ["one"]); preconditionFailure("空目标不得降级为通用投诉") } catch {}
        do { _ = try draft.parameters(target: .user("B"), userUID: "A", nickname: "", account: "", uploaded: []); preconditionFailure("部分上传不得提交") } catch {}
        let client = ComplaintMock(), store = ComplaintStore(client: ComplaintMock())
        let subject = ComplaintStore(client: client)
        let partialClient = ComplaintMock(); partialClient.failAtUpload = 2
        let partialStore = ComplaintStore(client: partialClient)
        var twoPhotos = draft; twoPhotos.images = [file, file]
        let partial = await partialStore.submit(twoPhotos, target: .group("g"), context: context, nickname: "甲", account: "tester")
        precondition(!partial && partialClient.submitted.isEmpty && !partialStore.submitted, "部分证据上传失败不得提交投诉")
        client.error = URLError(.notConnectedToInternet)
        let failed = await subject.submit(draft, target: .user("B"), context: context, nickname: "甲", account: "tester")
        precondition(!failed && client.submitted.isEmpty && subject.errorMessage != nil)
        client.error = nil; client.delay = true
        let task = Task { await subject.submit(draft, target: .user("B"), context: context, nickname: "甲", account: "tester") }
        while client.pending == nil { await Task.yield() }
        let duplicate = await subject.submit(draft, target: .user("B"), context: context, nickname: "甲", account: "tester")
        precondition(!duplicate)
        subject.close(); client.pending?.resume(returning: "late")
        let cancelled = await task.value
        precondition(!cancelled && client.submitted.isEmpty && !subject.isSubmitting)
        client.delay = false
        client.submitError = ComplaintError.invalidInput("服务器未受理")
        let refused = await subject.submit(draft, target: .user("B"), context: context, nickname: "甲", account: "tester")
        precondition(!refused && !subject.submitted && subject.errorMessage != nil, "上传成功不代表投诉被受理")
        client.submitError = nil
        let retry = await subject.submit(draft, target: .user("B"), context: context, nickname: "甲", account: "tester")
        precondition(retry && client.submitted.count == 1 && subject.submitted)
        let repeated = await subject.submit(draft, target: .user("B"), context: context, nickname: "甲", account: "tester")
        precondition(!repeated && client.submitted.count == 1)
        store.close()
        print("Complaint validation, request and lifecycle checks passed")
    }
}
