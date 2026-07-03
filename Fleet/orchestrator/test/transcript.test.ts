// Fleet/orchestrator/test/transcript.test.ts
//
// What: Unit tests for continue-elsewhere transcript building.
// Does: Verifies role labeling, tool summarization, empty-message skipping,
//       and recency-preserving truncation under the char budget.
// Touches: sessions.ts (buildTranscript).
// Touched by: vitest.

import { describe, expect, it } from "vitest";
import type { MessageRecord } from "@lucidity/shared";
import { buildTranscript } from "../src/sessions.js";

function msg(role: "user" | "assistant", parts: unknown[], id = String(Math.random())): MessageRecord {
    return { id, sessionId: "s1", role, parts, createdAt: Date.now() };
}

describe("buildTranscript", () => {
    it("labels roles and summarizes tool use", () => {
        const transcript = buildTranscript([
            msg("user", [{ type: "text", text: "add a login screen" }]),
            msg("assistant", [
                { type: "tool", tool: "edit" },
                { type: "text", text: "Done — added LoginView." },
            ]),
        ]);
        expect(transcript).toContain("User:\nadd a login screen");
        expect(transcript).toContain("[used tool: edit]");
        expect(transcript).toContain("Assistant:");
        expect(transcript).toContain("Done — added LoginView.");
    });

    it("skips messages with no renderable parts", () => {
        const transcript = buildTranscript([
            msg("assistant", [{ type: "step-start" }]),
            msg("user", [{ type: "text", text: "hi" }]),
        ]);
        expect(transcript).toBe("User:\nhi");
    });

    it("truncates from the front, keeping the newest messages", () => {
        const messages = Array.from({ length: 40 }, (_, i) =>
            msg("user", [{ type: "text", text: `message ${i}: ${"x".repeat(1000)}` }], `m${i}`),
        );
        const transcript = buildTranscript(messages);
        expect(transcript.length).toBeLessThan(26_000);
        expect(transcript).toContain("[...earlier conversation truncated...]");
        expect(transcript).toContain("message 39");
        expect(transcript).not.toContain("message 0:");
    });
});
