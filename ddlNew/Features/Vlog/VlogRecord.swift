import Foundation

nonisolated struct VlogOwner: Codable, Equatable, Sendable {
    let tenantID: String
    let userUID: String
}

nonisolated enum VlogKind: String, Codable, Sendable { case photo, video }

nonisolated struct VlogRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let kind: VlogKind
    let filename: String
    let bytes: Int64
    let width: Double
    let height: Double
    let duration: Double

    var valid: Bool {
        ["media.jpg", "media.mov", "media.mp4", "media.m4v"].contains(filename)
            && bytes > 0 && width.isFinite && height.isFinite && width > 0 && height > 0
            && duration.isFinite && duration >= 0 && (kind != .video || duration > 0)
    }
}

/// Owns a private staging directory, never a photo provider's temporary URL.
nonisolated struct VlogPrepared: Sendable {
    let directory: URL
    let kind: VlogKind
    let filename: String
    let bytes: Int64
    let width: Double
    let height: Double
    let duration: Double
    func discard() { try? FileManager.default.removeItem(at: directory) }
}

nonisolated enum VlogError: Error { case invalidArchive, missing, invalidMedia }
