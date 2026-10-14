"""执行生产日志表达式，防止正文、凭据、密钥和完整资源位置重新进入输出。"""
from pathlib import Path
import os
import re
import subprocess
import sys

root, target = map(Path, sys.argv[1:])
sdk = root / "NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule"


def calls(source):
    """按字符串边界读取完整日志调用，跳过已注释的调试示例。"""
    result = []
    for match in re.finditer(r"(?:CIMLog|NSLog)\s*\(|\[NoaLocalLogger\s+", source):
        if "//" in source[source.rfind("\n", 0, match.start()) + 1:match.start()]:
            continue
        cursor, quoted, escaped = match.start(), False, False
        while cursor < len(source):
            char = source[cursor]
            if escaped:
                escaped = False
            elif quoted and char == "\\":
                escaped = True
            elif char == '"':
                quoted = not quoted
            elif char == ";" and not quoted:
                result.append(source[match.start():cursor + 1])
                break
            cursor += 1
    return result


def method(source, signature):
    """提取实际生产方法，保留字典构造和NSNotification投递边界。"""
    start = source.index(signature)
    cursor = source.index("{", start) + 1
    depth = 1
    while depth:
        depth += (source[cursor] == "{") - (source[cursor] == "}")
        cursor += 1
    return source[start:cursor]


# 退回任意整包、凭据、密钥字节或资源错误原文时，这些输出断言必须失败。
cases = [
    ("Socket/TcpManager/NoaIMSocketManagerTool.m", "接收到消息类消息内容", ["data_type=", "msg_id=", "ack_msg_id=", "s_msg_id=", "send_time="]),
    ("Socket/TcpManager/NoaIMSocketManager.m", "设置了用户", ["hasToken="]),
    ("Socket/TcpManager/NoaIMSocketManager.m", "用户id、用户token出现差异", ["hasToken="]),
    ("Socket/TcpManager/NoaIMSocketManager.m", "发送消息中", ["data_type=", "msg_id=", "ack_msg_id=", "s_msg_id=", "send_time="]),
    ("DeCryptorManager/NovDecryptorManager.m", "共享密钥", ["length="]),
    ("DeCryptorManager/ZIMKeyExchange.m", "🔍 共享密钥", ["length="]),
    ("DeCryptorManager/ZIMKeyExchange.m", "🔍 派生AES密钥", ["length="]),
    ("DeCryptorManager/ZIMMessageDecoder.m", "🔍 AES密钥", ["length="]),
    ("DeCryptorManager/ZIMMessageDecoder.m", "🔍 AES消息体", ["length="]),
    ("DeCryptorManager/ZIMMessageDecoder.m", "期望HMAC", ["length="]),
    ("DeCryptorManager/ZIMMessageDecoder.m", "接收HMAC", ["length="]),
    ("DeCryptorManager/ECDHKeyManager.m", "🔐 共享密钥", ["length="]),
    ("DeCryptorManager/ECDHClientProtocolHandler.m", "会话密钥派生成功", ["length="]),
    ("DeCryptorManager/ECDHClientProtocolHandler.m", "共享密钥计算成功", ["length="]),
    ("DeCryptorManager/ECDHClientProtocolHandler.m", "🔐 [ECDH客户端] 会话密钥", ["length="]),
    ("HttpToTcpRequest/LingIMTcpRequestModel.m", "收到匹配响应", ["status:", "body_length="]),
    ("HttpToTcpRequest/LingIMTcpRequestModel.m", "发送请求 -", ["requestId:", "body_length="]),
    ("HttpToTcpRequest/LingIMTcpRequestModel+HandleReceiveMessage.m", "获取到token返回消息", ["hasData="]),
    ("HttpToTcpRequest/LingIMTcpRequestModel+HandleReceiveMessage.m", "消息解析成功", ["hasData="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+HandleReceiveTcpReplaceHttpMessage.m", "接收到ResponseMessage", ["status:", "body_length="]),
    ("HttpRequest/NoaIMHttpManager.m", "TOKEN", ["hasToken="]),
    ("HttpRequest/NoaIMHttpManager.m", "token自动更新完成", ["hasToken="]),
    ("HttpRequest/NoaIMHttpManager.m", "开始加密", ["hasData="]),
    ("DeCryptorManager/ECDHKeyManager.m", "X.509 hex", ["length="]),
    ("DeCryptorManager/ECDHKeyManager.m", "数据hex", ["length="]),
    ("DeCryptorManager/ECDHKeyManager.m", "原始公钥hex", ["length="]),
    ("DeCryptorManager/ZIMKeyExchange.m", "公钥数据预览", ["length="]),
    ("DeCryptorManager/ZIMKeyExchange.m", "原始数据预览", ["length="]),
    ("DeCryptorManager/NovDecryptorManager.m", "- 帧头标识", ["length="]),
    ("DeCryptorManager/NovDecryptorManager.m", "- 期望:", ["length="]),
    ("DeCryptorManager/NovDecryptorManager.m", "- 实际:", ["length="]),
    ("DeCryptorManager/ECDHClientProtocolHandler.m", "服务端返回错误", ["length="]),
    ("DeCryptorManager/ECDHClientProtocolHandler.m", "客户端公钥字节数组", ["length="]),
    ("DeCryptorManager/ECDHClientProtocolHandler.m", "服务端公钥字节数组", ["length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "当前socket未连接，当前是token请求", ["request_id=", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "未连接，请求进入", ["request_id=", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "ecdh交换还未成功", ["request_id=", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "isTokenExpired=", ["request_id=", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "当前请求是获取token，直接发送", ["request_id=", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "请求进入 pending", ["request_id=", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "Token有效，请求直接发送", ["request_id=", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "发送完成，延时20ms", ["requestId:", "url_length="]),
    ("HttpToTcpRequest/NoaIMSocketManagerTool+LingImTcpReplaceHttp.m", "token更新失败", ["code", "traceId"]),
    ("Socket/TcpManager/NoaIMSocketManager+EchoEncryption.m", "ECDH密钥交换失败", ["domain=", "code="]),
    ("Socket/TcpManager/NoaIMSocketManager+EchoEncryption.m", "ℹ️ [ECDH协商]", ["stage=", "length="]),
]
def production_source(path):
    """可只读提取指定Git版本证明回归先红，不覆盖当前工作区或写出认证常量。"""
    revision = os.environ.get("DDL_LOG_REDACTION_SOURCE_REV")
    if revision:
        relative = (sdk / path).relative_to(root)
        return subprocess.check_output(["git", "show", f"{revision}:{relative}"], cwd=root, text=True)
    return (sdk / path).read_text()


sources = {path: production_source(path) for path, _, _ in cases}
extracted = {path: calls(source) for path, source in sources.items()}
blocks = []
for index, (path, marker, required) in enumerate(cases):
    statements = [value for value in extracted[path] if marker in value]
    if not statements:
        raise SystemExit(f"Missing production log boundary: {path} / {marker}")
    for number, statement in enumerate(statements):
        # 只选择密钥诊断，计算失败和长度不足的状态日志由错误用例覆盖。
        if marker == "共享密钥" and "hex" not in statement and "length=" not in statement:
            continue
        expect = ", ".join('@"' + value + '"' for value in required)
        blocks.append(f"{{ {statement} Check(@\"case-{index}-{number}\", @[{expect}]); }}")

# 错误对象可能含NSURLErrorFailingURLStringErrorKey和本地路径；原样执行自有输出调用。
for path, source in sources.items():
    for number, statement in enumerate(calls(source)):
        if not re.search(r"localizedDescription|error\.description|,\s*(?:err|error|exception)\s*[\]\)]|CFBridgingRelease\(error|domain=.*code=|exception_name=", statement):
            continue
        preamble = ""
        for variable in re.findall(r"CFBridgingRelease\((\w+)\)", statement):
            preamble += f"CFErrorRef {variable} = (CFErrorRef)CFRetain((__bridge CFTypeRef)fixtureError);"
        required = "exception_name=" if "exception" in statement else "code="
        blocks.append(f"{{ {preamble} {statement} Check(@\"error-{path}-{number}\", @[@\"{required}\"]); }}")

http_source = sources["HttpRequest/NoaIMHttpManager.m"]
http_methods = method(http_source, "- (void)loganConfigWith:(NSString *)url param:")
http_methods += "\n" + method(http_source, "- (void)sentryUploadWithDictionary:")
socket_source = sources["Socket/TcpManager/NoaIMSocketManager.m"]
socket_method = method(socket_source, "- (void)sentryUploadWithEventObj:")
socket_blocks = []
for match in re.finditer(r"\[self sentryUploadWithEventObj:@\{", socket_source):
    end = socket_source.index('} errorCode:@"" ];', match.start()) if '} errorCode:@"" ];' in socket_source[match.start():] else socket_source.index('} errorCode:@""];', match.start())
    statement = socket_source[match.start():end + len('} errorCode:@""];')]
    if '使用参数连接失败' in statement or 'socketDidDisconnect回调' in statement:
        socket_blocks.append(statement + '\nCheck(@"socket-sentry-error-boundary", @[@"domain=", @"code="]);')
if len(socket_blocks) != 2:
    raise SystemExit("Expected two production socket error telemetry boundaries")
# 裸%@的refresh参数调用也原样执行，避免仅靠名称匹配漏掉Token。
refresh = method(http_source, "- (void)authRefreshTokenOnSuccess:")
for value in calls(refresh):
    if "params" in value:
        blocks.append(f"{{ {value} Check(@\"refresh-parameters\", @[@\"hasToken=\"]); }}")

harness = (root / "Tests/MigrationAcceptance/LogRedactionFixtures.m").read_text()
harness = harness.replace("/* PRODUCTION_HTTP_METHODS */", http_methods)
harness = harness.replace("/* PRODUCTION_SOCKET_METHOD */", socket_method)
harness = harness.replace("/* PRODUCTION_LOG_CALLS */", "\n".join(blocks))
harness = harness.replace("/* PRODUCTION_SOCKET_CALLS */", "\n".join(socket_blocks))
receive_log = next(value for value in extracted["Socket/TcpManager/NoaIMSocketManagerTool.m"] if "接收到消息类消息内容" in value)
send_log = next(value for value in extracted["Socket/TcpManager/NoaIMSocketManager.m"] if "发送消息中" in value)
identity_blocks = []
for value in (receive_log, send_log):
    identity_blocks.append('fixture.dataType = 2; ' + value + '\nCheck(@"chat-identity", @[@"data_type=2", @"msg_id=chat-local", @"s_msg_id=chat-server", @"send_time=1700000000100"]);')
    identity_blocks.append('fixture.dataType = 3; ' + value + '\nCheck(@"ack-identity", @[@"data_type=3", @"msg_id=ack-envelope", @"ack_msg_id=chat-local", @"s_msg_id=chat-server", @"send_time=1700000000200"]);')
    identity_blocks.append('fixture.dataType = 4; ' + value + '\nCheck(@"receipt-identity", @[@"data_type=4", @"msg_id=receipt-envelope", @"ack_msg_id=chat-local", @"s_msg_id=chat-server"]);')
harness = harness.replace("/* ACK_IDENTITY_CHECK */", "\n".join(identity_blocks))
(target / "LogRedactionChecks.m").write_text(harness)
print(f"Extracted {len(blocks)} production log boundaries, 2 HTTP and 1 socket logging methods")
