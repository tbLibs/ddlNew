import SwiftUI

extension Color {
    /// App 调色板使用六位 RGB，固定按 sRGB 转换。
    init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255,
                  opacity: 1)
    }
}
