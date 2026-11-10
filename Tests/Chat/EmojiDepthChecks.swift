import Foundation

// Track the tree constructed by the actual production renderer, without resolving UI.
struct Text {
    var parts: [String]
    var depth: Int
    init(_ value: String) { parts = value.isEmpty ? [] : [value]; depth = 0 }
    init(verbatim value: String) { self.init(value) }
    init(_ image: Image) { self.init(image.value) }
    func baselineOffset(_ offset: Int) -> Text { self }
    static func + (lhs: Text, rhs: Text) -> Text {
        var result = Text("")
        result.parts = lhs.parts + rhs.parts
        result.depth = max(lhs.depth, rhs.depth) + 1
        return result
    }
}
struct Image { let value: String; init(uiImage: String) { value = uiImage } }
struct Emoji { let image: String }
struct Run { let text: String; let emoji: Emoji? }
enum ChatEmojiArtwork {
    static func image(_ name: String, size: Int) -> String? { name == "missing" ? nil : name }
}
enum ChatEmojiCatalog {
    static func runs(in value: String) -> [Run] {
        guard !value.isEmpty else { return [] }
        return value.split(separator: "|", omittingEmptySubsequences: false).enumerated().map {
            Run(text: String($0.element), emoji: $0.offset.isMultiple(of: 2) ? Emoji(image: String($0.element)) : nil)
        }
    }
}

@main struct EmojiDepthChecks {
    static func main() {
        for count in [1_000, 5_000, 10_000, 0, 1, 2, 3, 7] {
            let parts = (0..<count).map { $0 == 2 ? "missing" : "fragment-\($0)" }
            let result = Renderer(value: parts.joined(separator: "|")).rendered
            guard result.parts == parts else { fatalError("Fragment order or missing-image fallback changed") }
            let limit = count <= 1 ? 0 : Int(ceil(log2(Double(count))))
            guard result.depth <= limit else {
                print("FAIL: \(count) fragments create depth \(result.depth); maximum allowed \(limit)")
                exit(1)
            }
        }
        print("Emoji tree depth, order, empty and fallback: 8 passed")
    }
}
