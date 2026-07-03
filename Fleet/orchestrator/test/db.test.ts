// Fleet/orchestrator/test/db.test.ts
//
// What: Unit tests for SQLite persistence.
// Does: Round-trips sessions and messages, exercises upsert semantics
//       (part-array replacement), ordering, and cascade delete.
// Touches: db.ts against a temp database file.
// Touched by: vitest.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import type { SessionRecord } from "@lucidity/shared";
import { FleetDb } from "../src/db.js";

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "lucidity-db-"));
const db = new FleetDb(tmp);
afterAll(() => {
    db.close();
    fs.rmSync(tmp, { recursive: true, force: true });
});

function session(id: string, over: Partial<SessionRecord> = {}): SessionRecord {
    return {
        id,
        machineId: "m4-mini",
        opencodeSessionId: id,
        title: "test",
        archived: false,
        createdAt: 1000,
        updatedAt: 1000,
        ...over,
    };
}

describe("FleetDb sessions", () => {
    it("round-trips and updates on conflict", () => {
        db.upsertSession(session("ses_1", { title: "first" }));
        db.upsertSession(session("ses_1", { title: "renamed", updatedAt: 2000 }));
        const got = db.getSession("ses_1");
        expect(got?.title).toBe("renamed");
        expect(got?.machineId).toBe("m4-mini");
        expect(got?.updatedAt).toBe(2000);
    });

    it("lists newest-first and respects archived filter", () => {
        db.upsertSession(session("ses_old", { updatedAt: 1 }));
        db.upsertSession(session("ses_new", { updatedAt: 9999 }));
        db.upsertSession(session("ses_arch", { archived: true }));
        const ids = db.listSessions().map((s) => s.id);
        expect(ids[0]).toBe("ses_new");
        expect(ids).not.toContain("ses_arch");
        expect(db.listSessions(true).map((s) => s.id)).toContain("ses_arch");
    });

    it("touchSession merges partial fields", () => {
        db.upsertSession(session("ses_touch"));
        db.touchSession("ses_touch", { lastProviderID: "lmstudio", lastModelID: "qwen" });
        const got = db.getSession("ses_touch");
        expect(got?.lastProviderID).toBe("lmstudio");
        expect(got?.updatedAt).toBeGreaterThan(1000);
    });
});

describe("FleetDb messages", () => {
    it("round-trips parts JSON and replaces on upsert", () => {
        db.upsertSession(session("ses_m"));
        db.upsertMessage({
            id: "msg_1",
            sessionId: "ses_m",
            role: "assistant",
            parts: [{ type: "text", text: "partial" }],
            createdAt: 10,
        });
        db.upsertMessage({
            id: "msg_1",
            sessionId: "ses_m",
            role: "assistant",
            parts: [{ type: "text", text: "complete" }, { type: "tool", tool: "bash" }],
            createdAt: 10,
            completedAt: 20,
        });
        const got = db.getMessage("msg_1");
        expect(got?.parts).toHaveLength(2);
        expect((got?.parts[0] as { text: string }).text).toBe("complete");
        expect(got?.completedAt).toBe(20);
    });

    it("orders by created_at and deletes with the session", () => {
        db.upsertMessage({ id: "msg_b", sessionId: "ses_m", role: "user", parts: [], createdAt: 300 });
        db.upsertMessage({ id: "msg_a", sessionId: "ses_m", role: "user", parts: [], createdAt: 100 });
        expect(db.listMessages("ses_m").map((m) => m.id)).toEqual(["msg_1", "msg_a", "msg_b"]);
        db.deleteSession("ses_m");
        expect(db.listMessages("ses_m")).toHaveLength(0);
        expect(db.getSession("ses_m")).toBeUndefined();
    });
});
