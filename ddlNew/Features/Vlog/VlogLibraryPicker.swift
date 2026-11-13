import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Copies the provider URL during its callback, before the provider removes it.
struct VlogLibraryPicker: UIViewControllerRepresentable {
    let onLoading: () -> Void
    let onResult: (Result<VlogPrepared, Error>) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .any(of: [.images, .videos])
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VlogLibraryPicker
        init(_ parent: VlogLibraryPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let item = results.first?.itemProvider else { parent.dismiss(); return }
            let kind: VlogKind = item.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ? .video : .photo
            parent.onLoading(); parent.dismiss()
            item.loadFileRepresentation(forTypeIdentifier: kind == .video ? UTType.movie.identifier : UTType.image.identifier) { [parent] url, error in
                do {
                    guard let url else { throw error ?? VlogError.invalidMedia }
                    let folder = try VlogMediaPreparation.makeDirectory()
                    let owned = folder.appendingPathComponent("source").appendingPathExtension(url.pathExtension)
                    do { try FileManager.default.copyItem(at: url, to: owned) }
                    catch { try? FileManager.default.removeItem(at: folder); throw error }
                    Task.detached {
                        defer { try? FileManager.default.removeItem(at: folder) }
                        let result: Result<VlogPrepared, Error>
                        do { result = .success(try await VlogMediaPreparation.prepare(file: owned, kind: kind)) }
                        catch { result = .failure(error) }
                        await MainActor.run { parent.onResult(result) }
                    }
                } catch { Task { @MainActor in parent.onResult(.failure(error)) } }
            }
        }
    }
}
