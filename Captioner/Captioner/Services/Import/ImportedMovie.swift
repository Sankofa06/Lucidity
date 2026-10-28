// ImportedMovie.swift
// Transferable wrapper that copies a picked video into app-owned storage.
//
// PhotosPicker hands over a temporary file that is deleted once the transfer
// finishes, so the importing closure copies it into the app's temporary
// directory first. Used by `PhotosMovieImporter`; touches the file system.

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ImportedMovie: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("import-\(UUID().uuidString)")
                .appendingPathExtension(fileExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImportedMovie(url: destination)
        }
    }
}
