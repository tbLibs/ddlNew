"""只读检查真实 HTTPDNS/BIN；不登录、不保存凭据，不替代设备上的 SDK/ECDH 验收。"""
from pathlib import Path
import hashlib, json, re, subprocess, tempfile, time, urllib.parse, urllib.request

root = Path(__file__).resolve().parents[2]
constants = (root / 'ddlNew/Configuration/Const.swift').read_text()
def setting(name):
    return re.search(r'let ' + name + r' = "([^"]*)"', constants).group(1)
license = '1000'
name = 't' + license.lower() + '.' + setting('dns1MainDomain')
uid, ak, secret = [setting(key) for key in ['dns1AccountId', 'dns1AccessKey', 'dns1AccessKeySecret']]
ts = str(int(time.time()))
signature = hashlib.sha256((uid + secret + ts + name + ak).encode()).hexdigest()
params = urllib.parse.urlencode(dict(name=name, type='28', uid=uid, ak=ak, key=signature, ts=ts))
try:
    with urllib.request.urlopen('https://223.5.5.5/resolve?' + params, timeout=6) as response:
        dns = json.load(response)
    records = [answer['data'] for answer in dns.get('Answer', []) if answer.get('type') == 28]
    assert dns.get('Status') == 0 and records, 'HTTPDNS returned no AAAA'
    with urllib.request.urlopen(setting('dns1BinURLTemplate').replace('%s', license), timeout=6) as response:
        encrypted = response.read(1048577)
    assert len(encrypted) <= 1048576
except Exception as error:
    raise SystemExit('Live endpoint check failed: ' + type(error).__name__)
with tempfile.TemporaryDirectory(prefix='ddlNew-dns1-live-') as directory:
    temp = Path(directory)
    (temp/'records.json').write_text(json.dumps(records))
    (temp/'npoint.bin').write_bytes(encrypted)
    (temp/'Main.swift').write_text('''import Foundation
@main struct LiveCheck {
 static func main() throws {
  let args = CommandLine.arguments
  let records = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[1]))) as! [String]
  let dns = try DNS1Payload.records(records)
  let bin = try DNS1Payload.bin(Data(contentsOf: URL(fileURLWithPath: args[2])), license: "1000")
  precondition(Set(dns.tcp.map(\\.address)) == Set(bin.tcp.map(\\.address)), "DNS和BIN的TCP节点不一致")
  print("Live DNS1: AAAA=\\(records.count), DNS TCP=\\(dns.tcp.count), DNS HTTP=\\(dns.http.count), BIN TCP=\\(bin.tcp.count), BIN HTTP=\\(bin.http.count)")
 }
}
''')
    subprocess.run(['xcrun','swiftc','-parse-as-library',str(root/'ddlNew/Common/Crypto/AesEncryptUtils.swift'),str(root/'ddlNew/Network/DNS1/DNS1Payload.swift'),str(temp/'Main.swift'),'-o',str(temp/'check')],check=True)
    subprocess.run([str(temp/'check'),str(temp/'records.json'),str(temp/'npoint.bin')],check=True)
