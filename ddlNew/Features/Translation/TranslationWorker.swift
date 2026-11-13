import SwiftUI
import Translation

/// Workers are created only for an explicit request and destroyed on cancel/close.
@available(iOS 18.0, *)
struct TranslationWorker: View {
    let request: TranslationRequest
    let completion: (Result<String, Error>) -> Void
    var body: some View {
        Color.clear.translationTask(source: request.source == "auto" ? nil : Locale.Language(identifier: request.source),
                                    target: Locale.Language(identifier: request.target)) { session in
            do {
                let response = try await session.translate(request.text)
                guard !Task.isCancelled else { return }
                completion(.success(response.targetText))
            } catch { if !Task.isCancelled { completion(.failure(error)) } }
        }
    }
}
