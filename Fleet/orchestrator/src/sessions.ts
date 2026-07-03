// Fleet/orchestrator/src/sessions.ts
//
// What: Session service — the orchestrator's core session logic.
// Does: Creates sessions pinned to a machine, sends prompts, mirrors opencode
//       events (messages/parts/idle/errors) into SQLite, resyncs transcripts,
//       adopts sessions created outside the orchestrator, and implements
//       "continue elsewhere" (seeding a new session from a stored transcript).
// Touches: FleetDb, FleetMonitor (machine connections), SseHub.
// Touched by: api.ts routes and index.ts event wiring.

import type {
    Event as OpencodeEvent,
    Message,
    Part,
    Session,
} from "@opencode-ai/sdk/client";
import type { FleetEvent, MessageRecord, SessionRecord, SseHub } from "@lucidity/shared";
import type { FleetDb } from "./db.js";
import type { FleetMonitor } from "./fleet.js";
import type { MachineConnection } from "./opencode.js";

const TRANSCRIPT_CHAR_BUDGET = 24_000;

export interface SendMessageInput {
    text: string;
    providerID?: string;
    modelID?: string;
    agent?: string;
}

export class SessionService {
    /** Sessions with an in-flight agent turn (between prompt and idle). */
    private busySessions = new Set<string>();

    constructor(
        private readonly db: FleetDb,
        private readonly fleet: FleetMonitor,
        private readonly hub: SseHub<FleetEvent>,
    ) {}

    // ---- reads ----------------------------------------------------------------

    list(includeArchived = false): SessionRecord[] {
        return this.db.listSessions(includeArchived).map((s) => this.withBusy(s));
    }

    get(id: string): SessionRecord | undefined {
        const record = this.db.getSession(id);
        return record ? this.withBusy(record) : undefined;
    }

    messages(sessionId: string): MessageRecord[] {
        return this.db.listMessages(sessionId);
    }

    private withBusy(record: SessionRecord): SessionRecord {
        return { ...record, busy: this.busySessions.has(record.id) };
    }

    // ---- session lifecycle ------------------------------------------------------

    async create(input: {
        machineId: string;
        title?: string;
        directory?: string;
    }): Promise<SessionRecord> {
        const conn = this.requireOnline(input.machineId);
        const res = await conn.client.session.create({
            body: input.title ? { title: input.title } : {},
            query: input.directory ? { directory: input.directory } : undefined,
        });
        if (!res.data) throw upstreamError("create session", res);
        const record = this.recordFromOpencode(input.machineId, res.data, {
            directory: input.directory,
        });
        this.db.upsertSession(record);
        this.hub.broadcast({ type: "session.created", session: this.withBusy(record) });
        return record;
    }

    async sendMessage(sessionId: string, input: SendMessageInput): Promise<void> {
        const record = this.mustGet(sessionId);
        const conn = this.requireOnline(record.machineId);
        const res = await conn.client.session.promptAsync({
            path: { id: record.opencodeSessionId },
            body: {
                parts: [{ type: "text", text: input.text }],
                model:
                    input.providerID && input.modelID
                        ? { providerID: input.providerID, modelID: input.modelID }
                        : undefined,
                agent: input.agent,
            },
        });
        if (res.error) throw upstreamError("send message", res);
        this.busySessions.add(sessionId);
        this.db.touchSession(sessionId, {
            lastProviderID: input.providerID,
            lastModelID: input.modelID,
        });
        this.broadcastSession(sessionId);
    }

    async abort(sessionId: string): Promise<void> {
        const record = this.mustGet(sessionId);
        const conn = this.requireOnline(record.machineId);
        await conn.client.session.abort({ path: { id: record.opencodeSessionId } });
        this.busySessions.delete(sessionId);
        this.broadcastSession(sessionId);
    }

    update(sessionId: string, fields: { title?: string; archived?: boolean }): SessionRecord {
        this.mustGet(sessionId);
        this.db.touchSession(sessionId, fields);
        const updated = this.withBusy(this.mustGet(sessionId));
        this.hub.broadcast({ type: "session.updated", session: updated });
        return updated;
    }

    /** Delete everywhere: on the pinned machine when reachable, always locally. */
    async remove(sessionId: string): Promise<void> {
        const record = this.mustGet(sessionId);
        const conn = this.fleet.connection(record.machineId);
        if (conn && this.fleet.status(record.machineId)?.opencodeOnline) {
            await conn.client.session
                .delete({ path: { id: record.opencodeSessionId } })
                .catch(() => undefined);
        }
        this.db.deleteSession(sessionId);
        this.busySessions.delete(sessionId);
        this.hub.broadcast({ type: "session.deleted", sessionId });
    }

    /**
     * "Continue elsewhere": create a NEW session on another machine seeded with
     * this session's transcript. Deliberately explicit — the original session's
     * file/tool context does not follow; only the conversation does.
     */
    async continueOn(sessionId: string, targetMachineId: string): Promise<SessionRecord> {
        const source = this.mustGet(sessionId);
        const transcript = buildTranscript(this.db.listMessages(sessionId));
        const target = await this.create({
            machineId: targetMachineId,
            title: `↪ ${source.title || "continued session"}`,
        });
        this.db.touchSession(target.id, { continuedFromSessionId: sessionId });
        const conn = this.requireOnline(targetMachineId);
        // noReply records the context as a user message without starting a turn,
        // so the next real prompt has the prior conversation in-context.
        const res = await conn.client.session.prompt({
            path: { id: target.opencodeSessionId },
            body: {
                noReply: true,
                parts: [
                    {
                        type: "text",
                        text:
                            `Context handoff: this session continues a conversation started on another machine. ` +
                            `The original working directory/files are NOT available here.\n\n` +
                            `--- prior transcript (may be truncated) ---\n${transcript}`,
                    },
                ],
            },
        });
        if (res.error) throw upstreamError("seed continued session", res);
        await this.syncMessages(target.id).catch(() => undefined);
        return this.withBusy(this.mustGet(target.id));
    }

    /** Pull the authoritative transcript from the pinned machine into SQLite. */
    async syncMessages(sessionId: string): Promise<void> {
        const record = this.mustGet(sessionId);
        const status = this.fleet.status(record.machineId);
        if (!status?.opencodeOnline) return; // offline: DB mirror is all we have
        const conn = this.fleet.connection(record.machineId);
        if (!conn) return;
        const res = await conn.client.session.messages({
            path: { id: record.opencodeSessionId },
        });
        if (!res.data) return;
        for (const entry of res.data) {
            this.db.upsertMessage(messageRecord(sessionId, entry.info, entry.parts));
        }
    }

    /** Adopt sessions created outside the orchestrator (e.g. in the TUI). */
    async adoptFromMachine(machineId: string): Promise<number> {
        const conn = this.requireOnline(machineId);
        const res = await conn.client.session.list();
        if (!res.data) throw upstreamError("list sessions", res);
        let adopted = 0;
        for (const session of res.data) {
            if (session.parentID) continue; // sub-agent sessions stay internal
            if (this.db.getSession(session.id)) continue;
            const record = this.recordFromOpencode(machineId, session, {});
            this.db.upsertSession(record);
            this.hub.broadcast({ type: "session.created", session: this.withBusy(record) });
            adopted += 1;
        }
        return adopted;
    }

    // ---- opencode event mirroring ------------------------------------------------

    /** Entry point for every event from every machine's /event stream. */
    handleOpencodeEvent(machineId: string, event: OpencodeEvent): void {
        switch (event.type) {
            case "message.updated":
                this.onMessageUpdated(event.properties.info);
                break;
            case "message.part.updated":
                this.onPartUpdated(event.properties.part, event.properties.delta);
                break;
            case "session.created":
            case "session.updated":
                this.onSessionInfo(machineId, event.properties.info);
                break;
            case "session.deleted":
                this.onSessionDeleted(event.properties.info);
                break;
            case "session.idle":
                this.onSessionIdle(event.properties.sessionID);
                break;
            case "session.error": {
                const sessionId = event.properties.sessionID;
                if (sessionId && this.db.getSession(sessionId)) {
                    this.busySessions.delete(sessionId);
                    this.broadcastSession(sessionId);
                }
                this.hub.broadcast({
                    type: "session.error",
                    sessionId,
                    error: event.properties.error,
                });
                break;
            }
            default:
                break; // LSP, file-watcher, TUI, pty events are irrelevant here
        }
    }

    private onMessageUpdated(info: Message): void {
        if (!this.db.getSession(info.sessionID)) return; // unadopted/child session
        const existing = this.db.getMessage(info.id);
        this.db.upsertMessage({
            ...messageRecord(info.sessionID, info, []),
            parts: existing?.parts ?? [],
        });
        this.db.touchSession(info.sessionID);
        this.broadcastMessage(info.sessionID, info.id);
    }

    private onPartUpdated(part: Part, delta?: string): void {
        if (!this.db.getSession(part.sessionID)) return;
        const existing = this.db.getMessage(part.messageID);
        // A part can arrive before its message.updated; create a shell if needed.
        const record: MessageRecord = existing ?? {
            id: part.messageID,
            sessionId: part.sessionID,
            role: "assistant",
            parts: [],
            createdAt: Date.now(),
        };
        const parts = [...record.parts];
        const idx = parts.findIndex((p) => (p as { id?: string }).id === part.id);
        if (idx >= 0) parts[idx] = part;
        else parts.push(part);
        this.db.upsertMessage({ ...record, parts });
        if (part.type === "text" && typeof delta === "string" && delta.length > 0) {
            // Cheap streaming path: the PWA appends deltas locally.
            this.hub.broadcast({
                type: "message.part.delta",
                sessionId: part.sessionID,
                messageId: part.messageID,
                partId: part.id,
                delta,
            });
        } else {
            this.broadcastMessage(part.sessionID, part.messageID);
        }
    }

    private onSessionInfo(machineId: string, info: Session): void {
        if (info.parentID) return;
        const existing = this.db.getSession(info.id);
        const record = this.recordFromOpencode(machineId, info, {
            directory: existing?.directory,
        });
        if (existing) {
            this.db.touchSession(info.id, { title: record.title });
            this.broadcastSession(info.id);
        } else {
            this.db.upsertSession(record);
            this.hub.broadcast({ type: "session.created", session: this.withBusy(record) });
        }
    }

    private onSessionDeleted(info: Session): void {
        if (!this.db.getSession(info.id)) return;
        this.db.deleteSession(info.id);
        this.busySessions.delete(info.id);
        this.hub.broadcast({ type: "session.deleted", sessionId: info.id });
    }

    private onSessionIdle(sessionId: string): void {
        if (!this.db.getSession(sessionId)) return;
        this.busySessions.delete(sessionId);
        // Idle is the natural reconciliation point: replace the event-built
        // mirror with the machine's authoritative transcript.
        void this.syncMessages(sessionId).catch(() => undefined);
        this.hub.broadcast({ type: "session.idle", sessionId });
        this.broadcastSession(sessionId);
    }

    // ---- helpers -------------------------------------------------------------------

    private mustGet(sessionId: string): SessionRecord {
        const record = this.db.getSession(sessionId);
        if (!record) throw new NotFoundError(`Unknown session ${sessionId}`);
        return record;
    }

    private requireOnline(machineId: string): MachineConnection {
        const conn = this.fleet.connection(machineId);
        if (!conn) throw new NotFoundError(`Unknown machine ${machineId}`);
        if (!this.fleet.status(machineId)?.opencodeOnline) {
            throw new MachineOfflineError(
                `Machine ${machineId} is offline; this session is pinned there. ` +
                    `History remains readable, or use continue-elsewhere.`,
            );
        }
        return conn;
    }

    private recordFromOpencode(
        machineId: string,
        session: Session,
        extra: { directory?: string },
    ): SessionRecord {
        const time = (session as { time?: { created?: number; updated?: number } }).time;
        return {
            id: session.id,
            machineId,
            opencodeSessionId: session.id,
            title: session.title ?? "",
            directory: extra.directory ?? session.directory,
            archived: false,
            createdAt: time?.created ?? Date.now(),
            updatedAt: time?.updated ?? Date.now(),
        };
    }

    private broadcastSession(sessionId: string): void {
        const record = this.db.getSession(sessionId);
        if (record) {
            this.hub.broadcast({ type: "session.updated", session: this.withBusy(record) });
        }
    }

    private broadcastMessage(sessionId: string, messageId: string): void {
        const message = this.db.getMessage(messageId);
        if (message) this.hub.broadcast({ type: "message.updated", sessionId, message });
    }
}

// ---- transcript seeding ------------------------------------------------------------

/** Flatten mirrored messages into a plain-text transcript within a char budget. */
export function buildTranscript(messages: MessageRecord[]): string {
    const blocks: string[] = [];
    for (const message of messages) {
        const texts: string[] = [];
        for (const part of message.parts) {
            const p = part as { type?: string; text?: string; tool?: string };
            if (p.type === "text" && p.text) texts.push(p.text);
            else if (p.type === "tool" && p.tool) texts.push(`[used tool: ${p.tool}]`);
        }
        if (texts.length === 0) continue;
        blocks.push(`${message.role === "user" ? "User" : "Assistant"}:\n${texts.join("\n")}`);
    }
    // Keep the most recent conversation when over budget — recency wins.
    let transcript = blocks.join("\n\n");
    while (transcript.length > TRANSCRIPT_CHAR_BUDGET && blocks.length > 1) {
        blocks.shift();
        transcript = `[...earlier conversation truncated...]\n\n` + blocks.join("\n\n");
    }
    return transcript;
}

function messageRecord(sessionId: string, info: Message, parts: Part[]): MessageRecord {
    return {
        id: info.id,
        sessionId,
        role: info.role,
        parts,
        error: info.role === "assistant" ? info.error : undefined,
        createdAt: info.time.created,
        completedAt: info.role === "assistant" ? info.time.completed : undefined,
    };
}

export class NotFoundError extends Error {}
export class MachineOfflineError extends Error {}

function upstreamError(action: string, res: { error?: unknown; response: Response }): Error {
    const detail =
        res.error && typeof res.error === "object"
            ? JSON.stringify(res.error)
            : res.response.statusText;
    return new Error(`opencode ${action} failed (${res.response.status}): ${detail}`);
}
