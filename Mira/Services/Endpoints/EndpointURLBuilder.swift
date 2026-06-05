// EndpointURLBuilder.swift
// URL construction helper for user-configured endpoint hosts and ports.
//
// Endpoint clients use this helper to avoid ad hoc string assembly and to keep
// private host values outside source constants.

import Foundation

enum EndpointURLBuilder {
    static func url(host: String, port: Int, path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/" + path

        guard let url = components.url else {
            throw EndpointURLError.invalidComponents
        }

        return url
    }
}

enum EndpointURLError: Error {
    case invalidComponents
}
