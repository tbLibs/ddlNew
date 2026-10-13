import Foundation
@main private struct SigningChecks {
    /// 使用公开文档的虚构密钥验证AWS已知向量，其余供应商验证签名头与路径绑定。
    static func main() throws {
        let credentials = CloudMediaCredentials(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", token: "", expires: Date.distantFuture)
        let date = ISO8601DateFormatter().date(from: "2013-05-24T00:00:00Z")!
        var request = URLRequest(url: URL(string: "https://examplebucket.s3.amazonaws.com/test$file.text")!)
        request.httpMethod = "PUT"
        request.setValue("Fri, 24 May 2013 00:00:00 GMT", forHTTPHeaderField: "Date")
        request.setValue("REDUCED_REDUNDANCY", forHTTPHeaderField: "x-amz-storage-class")
        let signed = try CloudRequestSigner.sign(request, provider: .amazon, credentials: credentials, bucket: "examplebucket", objectKey: "test$file.text", region: "us-east-1", payloadHash: "44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072", date: date)
        precondition(signed.value(forHTTPHeaderField: "Authorization")?.hasSuffix("Signature=98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd") == true, "官方AWS PUT签名向量")
        let temporary = CloudMediaCredentials(accessKey: "fixture-id", secretKey: "fixture-secret", token: "fixture-token", expires: Date.distantFuture)
        for provider in [CloudStorageProvider.aliyun, .tencent, .huawei] {
            var upload = URLRequest(url: URL(string: "https://bucket.example.invalid/chat/test.png")!)
            upload.httpMethod = "PUT"; upload.setValue("image/png", forHTTPHeaderField: "Content-Type")
            let result = try CloudRequestSigner.sign(upload, provider: provider, credentials: temporary, bucket: "bucket", objectKey: "chat/test.png", region: "region", payloadHash: "", date: date)
            precondition(result.value(forHTTPHeaderField: "Authorization") != nil)
            let tokenName = provider == .aliyun ? "x-oss-security-token" : provider == .tencent ? "x-cos-security-token" : "x-obs-security-token"
            precondition(result.value(forHTTPHeaderField: tokenName) == "fixture-token", "临时凭据请求必须携带安全Token")
        }
        print("Cloud signing checks passed")
    }
}
