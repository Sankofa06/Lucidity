// ModelSourceProtocols.swift
// Search and metadata contracts for Hugging Face and CivitAI model sources.
//
// Settings and source shells can depend on these protocols while concrete API
// clients and Keychain-backed credentials arrive later.

import Foundation

protocol ModelSourceSearchClient: Sendable {
    func search(_ query: ModelSourceQuery) async throws -> [ModelSourceSearchResult]
}

struct ModelSourceQuery: Hashable, Sendable {
    var source: ModelSourceKind
    var text: String
    var limit: Int
}

struct ModelSourceSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    var source: ModelSourceKind
    var name: String
    var summary: String
    var license: String?
    var triggerWords: [String]
    var downloadCount: Int?
}
