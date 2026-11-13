import SwiftUI
import UniformTypeIdentifiers

struct VlogCapturePicker: UIViewControllerRepresentable {
    let video: Bool
    let onLoading: () -> Void
    let onResult: (Result<VlogPrepared, Error>) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [video ? UTType.movie.identifier : UTType.image.identifier]
        picker.cameraCaptureMode = video ? .video : .photo
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VlogCapturePicker
        private var job: Task<Void, Never>?
        init(_ parent: VlogCapturePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onLoading()
            picker.view.isUserInteractionEnabled = false
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white; spinner.backgroundColor = .black.withAlphaComponent(0.7)
            spinner.layer.cornerRadius = 16
            spinner.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
            spinner.center = picker.view.center
            spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            picker.view.addSubview(spinner); spinner.startAnimating()
            let operation: Task<VlogPrepared, Error>
            if let video = info[.mediaURL] as? URL {
                operation = Task.detached { try await VlogMediaPreparation.prepare(file: video, kind: .video) }
            } else if let image = info[.originalImage] as? UIImage {
                operation = Task.detached { try VlogMediaPreparation.image(image) }
            } else {
                parent.onResult(.failure(VlogError.invalidMedia)); parent.dismiss(); return
            }
            // Keep the picker alive until its temporary video is copied to our staging folder.
            job = Task {
                let result: Result<VlogPrepared, Error>
                do {
                    let prepared = try await withTaskCancellationHandler(operation: { try await operation.value }, onCancel: { operation.cancel() })
                    if Task.isCancelled { prepared.discard(); return }
                    result = .success(prepared)
                } catch { result = .failure(error) }
                parent.onResult(result); parent.dismiss()
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { job?.cancel(); parent.dismiss() }
        deinit { job?.cancel() }
    }
}
