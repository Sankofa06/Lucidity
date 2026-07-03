// Fleet/orchestrator/src/db.ts
//
// What: SQLite persistence for sessions and mirrored chat messages.
// Does: Opens/creates the database (WAL mode), owns the schema, and exposes
//       typed CRUD helpers. Sessions use the opencode session id as primary
//       key; messages store opencode's parts array verbatim as JSON.
// Touches: better-sqlite3 database file under config.dataDir.
// Touched by: sessions.ts (all reads/writes), api.ts (list/read paths).

import fs from "node:fs";
import path from "node:path";
import Database from "better-sqlite3";
import type { MessageRecord, SessionRecord } from "@lucidity/shared";

export class FleetDb {
    private db: Database.Database;

    constructor(dataDir: string, filename = "fleet.db") {
        fs.mkdirSync(dataDir, { recursive: true });
        this.db = new Database(path.join(dataDir, filename));
        this.db.pragma("journal_mode = WAL");
        this.db.pragma("foreign_keys = ON");
        this.migrate();
    }

    private migrate(): void {
        this.db.exec(`
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                machine_id TEXT NOT NULL,
                opencode_session_id TEXT NOT NULL,
                title TEXT NOT NULL DEFAULT '',
                directory TEXT,
                continued_from TEXT,
                last_provider_id TEXT,
                last_model_id TEXT,
                archived INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                parts TEXT NOT NULL DEFAULT '[]',
                error TEXT,
                created_at INTEGER NOT NULL,
                completed_at INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_messages_session
                ON messages(session_id, created_at);
        `);
    }

    close(): void {
        this.db.close();
    }

    // ---- sessions -----------------------------------------------------------

    upsertSession(record: SessionRecord): void {
        this.db
            .prepare(
                `INSERT INTO sessions (id, machine_id, opencode_session_id, title, directory,
                    continued_from, last_provider_id, last_model_id, archived, created_at, updated_at)
                 VALUES (@id, @machineId, @opencodeSessionId, @title, @directory,
                    @continuedFrom, @lastProviderID, @lastModelID, @archived, @createdAt, @updatedAt)
                 ON CONFLICT(id) DO UPDATE SET
                    title = excluded.title,
                    directory = COALESCE(excluded.directory, sessions.directory),
                    last_provider_id = COALESCE(excluded.last_provider_id, sessions.last_provider_id),
                    last_model_id = COALESCE(excluded.last_model_id, sessions.last_model_id),
                    archived = excluded.archived,
                    updated_at = excluded.updated_at`,
            )
            .run({
                id: record.id,
                machineId: record.machineId,
                opencodeSessionId: record.opencodeSessionId,
                title: record.title,
                directory: record.directory ?? null,
                continuedFrom: record.continuedFromSessionId ?? null,
                lastProviderID: record.lastProviderID ?? null,
                lastModelID: record.lastModelID ?? null,
                archived: record.archived ? 1 : 0,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
            });
    }

    getSession(id: string): SessionRecord | undefined {
        const row = this.db.prepare("SELECT * FROM sessions WHERE id = ?").get(id);
        return row ? rowToSession(row as SessionRow) : undefined;
    }

    listSessions(includeArchived = false): SessionRecord[] {
        const rows = this.db
            .prepare(
                `SELECT * FROM sessions ${includeArchived ? "" : "WHERE archived = 0"}
                 ORDER BY updated_at DESC`,
            )
            .all() as SessionRow[];
        return rows.map(rowToSession);
    }

    touchSession(id: string, fields: Partial<SessionRecord> = {}): void {
        const existing = this.getSession(id);
        if (!existing) return;
        this.upsertSession({ ...existing, ...fields, updatedAt: Date.now() });
    }

    deleteSession(id: string): void {
        this.db.prepare("DELETE FROM messages WHERE session_id = ?").run(id);
        this.db.prepare("DELETE FROM sessions WHERE id = ?").run(id);
    }

    // ---- messages -----------------------------------------------------------

    upsertMessage(record: MessageRecord): void {
        this.db
            .prepare(
                `INSERT INTO messages (id, session_id, role, parts, error, created_at, completed_at)
                 VALUES (@id, @sessionId, @role, @parts, @error, @createdAt, @completedAt)
                 ON CONFLICT(id) DO UPDATE SET
                    parts = excluded.parts,
                    error = excluded.error,
                    completed_at = excluded.completed_at`,
            )
            .run({
                id: record.id,
                sessionId: record.sessionId,
                role: record.role,
                parts: JSON.stringify(record.parts),
                error: record.error === undefined ? null : JSON.stringify(record.error),
                createdAt: record.createdAt,
                completedAt: record.completedAt ?? null,
            });
    }

    getMessage(id: string): MessageRecord | undefined {
        const row = this.db.prepare("SELECT * FROM messages WHERE id = ?").get(id);
        return row ? rowToMessage(row as MessageRow) : undefined;
    }

    listMessages(sessionId: string): MessageRecord[] {
        const rows = this.db
            .prepare("SELECT * FROM messages WHERE session_id = ? ORDER BY created_at ASC, id ASC")
            .all(sessionId) as MessageRow[];
        return rows.map(rowToMessage);
    }
}

// ---- row mapping -------------------------------------------------------------

interface SessionRow {
    id: string;
    machine_id: string;
    opencode_session_id: string;
    title: string;
    directory: string | null;
    continued_from: string | null;
    last_provider_id: string | null;
    last_model_id: string | null;
    archived: number;
    created_at: number;
    updated_at: number;
}

interface MessageRow {
    id: string;
    session_id: string;
    role: string;
    parts: string;
    error: string | null;
    created_at: number;
    completed_at: number | null;
}

function rowToSession(row: SessionRow): SessionRecord {
    return {
        id: row.id,
        machineId: row.machine_id,
        opencodeSessionId: row.opencode_session_id,
        title: row.title,
        directory: row.directory ?? undefined,
        continuedFromSessionId: row.continued_from ?? undefined,
        lastProviderID: row.last_provider_id ?? undefined,
        lastModelID: row.last_model_id ?? undefined,
        archived: row.archived === 1,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
    };
}

function rowToMessage(row: MessageRow): MessageRecord {
    return {
        id: row.id,
        sessionId: row.session_id,
        role: row.role === "user" ? "user" : "assistant",
        parts: JSON.parse(row.parts) as unknown[],
        error: row.error ? (JSON.parse(row.error) as unknown) : undefined,
        createdAt: row.created_at,
        completedAt: row.completed_at ?? undefined,
    };
}
