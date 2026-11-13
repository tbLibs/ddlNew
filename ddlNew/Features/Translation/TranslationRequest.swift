import Foundation

struct TranslationRequest: Equatable {
    let id: UUID
    let text: String
    let source: String
    let target: String
}
