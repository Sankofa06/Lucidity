// LocalMachineConfig.swift
// Decodable local-only machine configuration for endpoint smoke testing.
//
// The app never hardcodes private machines. Developers can pass ignored config
// files into tests or tools when local endpoint smoke checks are needed.

import Foundation

struct LocalMachineConfig: Decodable, Hashable {
    var machines: [LocalMachine]
}

struct LocalMachine: Decodable, Hashable {
    var name: String
    var host: String
    var expectedPorts: [Int]
}

enum LocalMachineConfigLoader {
    static func load(from url: URL) throws -> LocalMachineConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LocalMachineConfig.self, from: data)
    }
}
