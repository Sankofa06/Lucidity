// RouteValidationTests.swift
// Focused tests for Mira's route validation and media concurrency defaults.
//
// These tests protect the chat-first route requirements before real endpoints
// are wired in.

import Testing
@testable import Mira

struct RouteValidationTests {
    @Test func chatRequiresTextCapability() {
        let route = MockMiraData.inventory.routes.first { $0.capabilities.contains(.text) }

        #expect(RouteValidator.canSend(task: .chat(.free), route: route))
    }

    @Test func mediaRouteRequiresMediaCapability() {
        let chatRoute = MockMiraData.inventory.routes.first { $0.capabilities.contains(.text) }

        #expect(RouteValidator.canSend(task: .createMedia, route: chatRoute) == false)
    }

    @Test func defaultPolicyQueuesSameMachineMedia() {
        #expect(RunConcurrencyPolicy.defaultPolicy.allowsParallelText)
        #expect(RunConcurrencyPolicy.defaultPolicy.allowsParallelMediaOnSameMachine == false)
    }
}
