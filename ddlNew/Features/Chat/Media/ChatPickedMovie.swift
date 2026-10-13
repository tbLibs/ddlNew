//
//  ChatPickedMovie.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct ChatPickedMovie: Transferable {
    let file: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.file) } importing: { received in
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ChatPickedMovie(file: destination)
        }
    }
}
