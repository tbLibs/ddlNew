import Foundation

@main struct AddressChecks {
    static func main() {
        let cases: [(String, String)] = [
            ("203.0.113.17:10443", "203.***.***.17:10443"),
            ("203.0.113.17", "203.***.***.17"),
            ("[2001:db8:1234::5678]:10443", "[2001:****]:10443"),
            ("[::1]:443", "[****]:443"),
            ("gateway.example.invalid:10443", "g***y.e***e.i***d:10443"),
            ("tTENANT.primary.example.invalid", "t***T.p***y.e***e.i***d"),
            ("https://user:secret@bin.example.invalid:8443/TENANT/nav.bin?token=secret#secret", "https://b***n.e***e.i***d:8443/***"),
            ("https://ipinfo.io/json", "https://i***o.***/***"),
            ("https://[2001:db8::1]/secret", "https://[2001:****]/***"),
            ("a.io", "***.***"),
            ("not a node secret", "***"),
            ("https://", "***"),
            ("file:///private/secret", "***"),
            ("https://example.invalid?token=secret", "https://e***e.i***d"),
            ("", "***")
        ]
        for (input, expected) in cases {
            precondition(NetworkDiagnosticAddress.masked(input) == expected, "Address redaction case failed")
        }
        print("PASS address redaction: IPv4, IPv6, domains, URLs, short hosts and invalid input")
    }
}
