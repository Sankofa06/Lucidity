// EndpointArchitectureTests.swift
// Tests endpoint URL construction and local-only config decoding.
//
// The fixtures use fake hosts to ensure private machine data never enters the
// committed test suite.

import Foundation
import Testing
@testable import Mira

struct EndpointArchitectureTests {
    @Test func buildsEndpointURLFromComponents() throws {
        let url = try EndpointURLBuilder.url(
            host: "example-gpu.tailnet.example",
            port: 8188,
            path: "/system_stats"
        )

        #expect(url.absoluteString == "http://example-gpu.tailnet.example:8188/system_stats")
    }

    @Test func decodesLocalMachineConfigShape() throws {
        let json = """
        {
          "machines": [
            {
              "name": "Example GPU",
              "host": "example-gpu.tailnet.example",
              "expectedPorts": [1234, 7860, 8188]
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(LocalMachineConfig.self, from: data)

        #expect(config.machines.count == 1)
        #expect(config.machines[0].expectedPorts.contains(8188))
    }
}
