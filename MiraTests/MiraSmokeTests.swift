// MiraSmokeTests.swift
// First-build smoke tests for Mira's app-level domain fixtures.
//
// Tests consume the same public-safe mock data as the UI shell and verify that
// the project starts with selectable chat routes.

import Testing
@testable import Mira

struct MiraSmokeTests {
    @Test func mockInventoryHasRoutes() {
        #expect(MockMiraData.inventory.routes.isEmpty == false)
    }

    @Test func defaultAdvisorRequiresConfirmation() {
        #expect(MockMiraData.advisor.requiresConfirmation)
    }
}
