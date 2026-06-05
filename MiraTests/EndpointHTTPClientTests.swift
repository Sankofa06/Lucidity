// EndpointHTTPClientTests.swift
// Mock-network tests for Mira's read-only endpoint HTTP clients.
//
// Tests use fake hosts and URLProtocol stubs so private endpoint data never
// enters the committed suite.

import Foundation
import Testing
@testable import Mira

struct EndpointHTTPClientTests {
    @Test func lmStudioClientNormalizesModelList() async throws {
        let session = URLSession.miraMocking(jsonByPath: [
            "/api/v0/models": #"{"data":[{"id":"example-model","type":"llm","state":"loaded","max_context_length":4096}]}"#
        ])
        let client = LMStudioHTTPClient(session: session)

        let models = try await client.listModels(at: EndpointAddress(host: "example.test", port: 1234))

        #expect(models.count == 1)
        #expect(models[0].id == "example-model")
        #expect(models[0].state == "loaded")
    }

    @Test func automatic1111ClientReadsInventory() async throws {
        let session = URLSession.miraMocking(jsonByPath: [
            "/sdapi/v1/sd-models": #"[{"model_name":"example-checkpoint"}]"#,
            "/sdapi/v1/loras": #"[{"name":"example-lora"}]"#,
            "/sdapi/v1/sd-vae": #"[]"#,
            "/sdapi/v1/samplers": #"[{"name":"Euler"}]"#,
            "/sdapi/v1/schedulers": #"[{"name":"karras"}]"#,
            "/sdapi/v1/extensions": #"[{"name":"controlnet"}]"#
        ])
        let client = Automatic1111HTTPClient(session: session)

        let inventory = try await client.readInventory(at: EndpointAddress(host: "example.test", port: 7860))

        #expect(inventory.checkpoints == ["example-checkpoint"])
        #expect(inventory.loras == ["example-lora"])
        #expect(inventory.samplers == ["Euler"])
        #expect(inventory.extensions == ["controlnet"])
    }

    @Test func comfyUIClientReadsSystemSummary() async throws {
        let session = URLSession.miraMocking(jsonByPath: [
            "/system_stats": #"{"system":{"os":"darwin","comfyui_version":"0.1"},"devices":[{"name":"Example GPU"}]}"#,
            "/object_info": #"{"SaveImage":{},"LoadCheckpoint":{}}"#,
            "/queue": #"{"queue_running":[{}],"queue_pending":[{},{}]}"#
        ])
        let client = ComfyUIHTTPClient(session: session)

        let summary = try await client.readSystem(at: EndpointAddress(host: "example.test", port: 8188))

        #expect(summary.operatingSystem == "darwin")
        #expect(summary.nodeCount == 2)
        #expect(summary.queueRunning == 1)
        #expect(summary.queuePending == 2)
    }
}

private extension URLSession {
    static func miraMocking(jsonByPath: [String: String]) -> URLSession {
        MiraMockURLProtocol.jsonByPath = jsonByPath
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MiraMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MiraMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var jsonByPath: [String: String] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? "/"
        let json = Self.jsonByPath[path] ?? "{}"
        let data = Data(json.utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
