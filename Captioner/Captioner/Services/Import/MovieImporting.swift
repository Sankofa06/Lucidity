// MovieImporting.swift
// Loads a video the user picked in the Photos picker.
//
// The editor view model calls `importMovie(from:)` with the picker's item and
// gets back a local file URL it owns. The concrete importer uses
// `ImportedMovie`'s Transferable representation; tests skip this service and
// call the view model's URL entry point directly.

import Foundation
import PhotosUI
import SwiftUI

@MainActor
protocol MovieImporting {
    func importMovie(from item: PhotosPickerItem) async throws -> URL
}

struct PhotosMovieImporter: MovieImporting {
    func importMovie(from item: PhotosPickerItem) async throws -> URL {
        guard let movie = try await item.loadTransferable(type: ImportedMovie.self) else {
            throw CaptionerError.importFailed
        }
        return movie.url
    }
}
