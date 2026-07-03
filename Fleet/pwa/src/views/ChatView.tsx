// Fleet/pwa/src/views/ChatView.tsx
//
// What: The chat tab — session list, conversation, and composer.
// Does: Lists sessions (with machine + online badges), opens a conversation
//       with live streaming via SSE deltas, sends prompts with a model picker,
//       aborts running turns, and offers "continue on another machine" for
//       sessions whose home machine is offline (or on demand).
// Touches: api.ts, events.ts.
// Touched by: App.tsx.

import { useCallback, useEffect, useRef, useState } from "react";
import { api } from "../api";
import { onFleetEvent } from "../events";
import type {
    FleetSnapshot,
    MessagePart,
    MessageRecord,
    SessionRecord,
} from "../types";

export function ChatView(props: {
    fleet: FleetSnapshot;
    sessions: SessionRecord[];
    session?: SessionRecord;
    onOpenSettings: () => void;
}) {
    if (props.session) {
        return <Conversation key={props.session.id} fleet={props.fleet} session={props.session} />;
    }
    return (
        <SessionList
            fleet={props.fleet}
            sessions={props.sessions}
            onOpenSettings={props.onOpenSettings}
        />
    );
}

// ---- session list -------------------------------------------------------------

function SessionList(props: {
    fleet: FleetSnapshot;
    sessions: SessionRecord[];
    onOpenSettings: () => void;
}) {
    const [creating, setCreating] = useState(false);
    return (
        <div className="page">
            <header className="pagehead">
                <h1>Lucidity</h1>
                <div className="pagehead-actions">
                    <button onClick={props.onOpenSettings} title="Settings">⚙️</button>
                    <button className="primary" onClick={() => setCreating(true)}>
                        + New session
                    </button>
                </div>
            </header>
            {props.sessions.length === 0 && (
                <p className="empty">No sessions yet. Start one on any online machine.</p>
            )}
            <ul className="sessionlist">
                {props.sessions.map((s) => {
                    const machine = props.fleet.machines.find((m) => m.id === s.machineId);
                    return (
                        <li key={s.id}>
                            <a href={`#/chat/${s.id}`}>
                                <div className="session-title">
                                    {s.busy ? "⏳ " : ""}
                                    {s.title || "(untitled session)"}
                                </div>
                                <div className="session-meta">
                                    <span className={machine?.opencodeOnline ? "dot on" : "dot off"} />
                                    {machine?.name ?? s.machineId}
                                    {s.continuedFromSessionId ? " · continued" : ""}
                                    {" · "}
                                    {new Date(s.updatedAt).toLocaleString()}
                                </div>
                            </a>
                        </li>
                    );
                })}
            </ul>
            {creating && (
                <NewSessionSheet fleet={props.fleet} onClose={() => setCreating(false)} />
            )}
        </div>
    );
}

function NewSessionSheet(props: { fleet: FleetSnapshot; onClose: () => void }) {
    const online = props.fleet.machines.filter((m) => m.opencodeOnline);
    const [machineId, setMachineId] = useState(online[0]?.id ?? "");
    const [title, setTitle] = useState("");
    const [directory, setDirectory] = useState("");
    const [error, setError] = useState("");
    const create = async () => {
        try {
            const session = await api.createSession({
                machineId,
                title: title.trim() || undefined,
                directory: directory.trim() || undefined,
            });
            props.onClose();
            window.location.hash = `#/chat/${session.id}`;
        } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
        }
    };
    return (
        <div className="sheet-backdrop" onClick={props.onClose}>
            <div className="sheet" onClick={(e) => e.stopPropagation()}>
                <h2>New session</h2>
                {online.length === 0 ? (
                    <p className="hint">No machines online right now.</p>
                ) : (
                    <>
                        <label className="field">
                            <span>Machine</span>
                            <select value={machineId} onChange={(e) => setMachineId(e.target.value)}>
                                {online.map((m) => (
                                    <option key={m.id} value={m.id}>
                                        {m.name}
                                    </option>
                                ))}
                            </select>
                        </label>
                        <label className="field">
                            <span>Title (optional)</span>
                            <input value={title} onChange={(e) => setTitle(e.target.value)} />
                        </label>
                        <label className="field">
                            <span>Working directory on that machine (optional)</span>
                            <input
                                value={directory}
                                placeholder="~/Projects/my-app"
                                onChange={(e) => setDirectory(e.target.value)}
                            />
                        </label>
                        {error && <p className="error">{error}</p>}
                        <button className="primary" disabled={!machineId} onClick={create}>
                            Create
                        </button>
                    </>
                )}
            </div>
        </div>
    );
}

// ---- conversation -------------------------------------------------------------

function Conversation(props: { fleet: FleetSnapshot; session: SessionRecord }) {
    const { session, fleet } = props;
    const machine = fleet.machines.find((m) => m.id === session.machineId);
    const [messages, setMessages] = useState<MessageRecord[]>([]);
    const [text, setText] = useState("");
    const [model, setModel] = useState(
        session.lastProviderID && session.lastModelID
            ? `${session.lastProviderID}/${session.lastModelID}`
            : "",
    );
    const [error, setError] = useState("");
    const [showContinue, setShowContinue] = useState(false);
    const scrollRef = useRef<HTMLDivElement>(null);

    const load = useCallback(() => {
        api.session(session.id)
            .then(({ messages }) => setMessages(messages))
            .catch((err) => setError(err.message));
    }, [session.id]);

    useEffect(load, [load]);

    // Live updates: full message replaces, text deltas append in place.
    useEffect(
        () =>
            onFleetEvent((event) => {
                if (event.type === "message.updated" && event.sessionId === session.id) {
                    setMessages((prev) => {
                        const next = prev.filter((m) => m.id !== event.message.id);
                        next.push(event.message);
                        next.sort((a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id));
                        return next;
                    });
                } else if (
                    event.type === "message.part.delta" &&
                    event.sessionId === session.id
                ) {
                    setMessages((prev) =>
                        applyDelta(prev, event.messageId, event.partId, event.delta),
                    );
                } else if (event.type === "session.idle" && event.sessionId === session.id) {
                    load(); // reconcile with the authoritative transcript
                }
            }),
        [session.id, load],
    );

    useEffect(() => {
        scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
    }, [messages]);

    const send = async () => {
        const body = text.trim();
        if (!body) return;
        setError("");
        const [providerID, ...rest] = model.split("/");
        try {
            await api.sendMessage(session.id, {
                text: body,
                providerID: rest.length ? providerID : undefined,
                modelID: rest.length ? rest.join("/") : undefined,
            });
            setText("");
        } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
        }
    };

    return (
        <div className="page conversation">
            <header className="pagehead">
                <a href="#/chat" className="back">‹</a>
                <div className="convo-title">
                    <h1>{session.title || "(untitled)"}</h1>
                    <div className="session-meta">
                        <span className={machine?.opencodeOnline ? "dot on" : "dot off"} />
                        {machine?.name ?? session.machineId}
                        {session.busy ? " · working…" : ""}
                    </div>
                </div>
                <div className="pagehead-actions">
                    {session.busy && (
                        <button onClick={() => api.abortSession(session.id).catch(() => {})}>
                            ⏹ Stop
                        </button>
                    )}
                    <button onClick={() => setShowContinue(true)} title="Continue on another machine">
                        ↪
                    </button>
                </div>
            </header>

            {!machine?.opencodeOnline && (
                <div className="banner warn">
                    {machine?.name ?? session.machineId} is offline — history is read-only.
                    Use ↪ to continue on another machine (transcript only; files don't follow).
                </div>
            )}

            <div className="messages" ref={scrollRef}>
                {messages.map((m) => (
                    <MessageBubble key={m.id} message={m} />
                ))}
            </div>

            {error && <p className="error">{error}</p>}

            <footer className="composer">
                {machine && machine.models.length > 0 && (
                    <select value={model} onChange={(e) => setModel(e.target.value)}>
                        <option value="">default model</option>
                        {machine.models.map((mm) => (
                            <option
                                key={`${mm.providerID}/${mm.modelID}`}
                                value={`${mm.providerID}/${mm.modelID}`}
                            >
                                {mm.name}
                            </option>
                        ))}
                    </select>
                )}
                <div className="composer-row">
                    <textarea
                        value={text}
                        rows={2}
                        placeholder={
                            machine?.opencodeOnline ? "Message the agent…" : "Machine offline"
                        }
                        disabled={!machine?.opencodeOnline}
                        onChange={(e) => setText(e.target.value)}
                        onKeyDown={(e) => {
                            if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) void send();
                        }}
                    />
                    <button
                        className="primary"
                        disabled={!machine?.opencodeOnline || !text.trim()}
                        onClick={send}
                    >
                        ➤
                    </button>
                </div>
            </footer>

            {showContinue && (
                <ContinueSheet
                    fleet={fleet}
                    session={session}
                    onClose={() => setShowContinue(false)}
                />
            )}
        </div>
    );
}

function applyDelta(
    messages: MessageRecord[],
    messageId: string,
    partId: string,
    delta: string,
): MessageRecord[] {
    const idx = messages.findIndex((m) => m.id === messageId);
    // Shell message if the delta beats message.updated over the wire.
    const base: MessageRecord =
        idx >= 0
            ? messages[idx]!
            : {
                  id: messageId,
                  sessionId: "",
                  role: "assistant",
                  parts: [],
                  createdAt: Date.now(),
              };
    const parts = [...base.parts];
    const pIdx = parts.findIndex((p) => p.id === partId);
    if (pIdx >= 0) {
        const part = parts[pIdx]!;
        parts[pIdx] = { ...part, text: (part.text ?? "") + delta };
    } else {
        parts.push({ id: partId, type: "text", text: delta });
    }
    const updated = { ...base, parts };
    const next = [...messages];
    if (idx >= 0) next[idx] = updated;
    else next.push(updated);
    return next;
}

function MessageBubble({ message }: { message: MessageRecord }) {
    const visible = message.parts.filter(
        (p) => p.type === "text" || p.type === "tool" || p.type === "reasoning",
    );
    if (visible.length === 0 && !message.error) return null;
    return (
        <div className={`bubble ${message.role}`}>
            {visible.map((part, i) => (
                <PartView key={part.id ?? i} part={part} />
            ))}
            {message.error != null && (
                <div className="part-error">⚠ {describeError(message.error)}</div>
            )}
        </div>
    );
}

function PartView({ part }: { part: MessagePart }) {
    if (part.type === "text" && part.text) {
        return <div className="part-text">{part.text}</div>;
    }
    if (part.type === "reasoning" && part.text) {
        return (
            <details className="part-reasoning">
                <summary>💭 reasoning</summary>
                <div className="part-text">{part.text}</div>
            </details>
        );
    }
    if (part.type === "tool") {
        const status = part.state?.status ?? "";
        const icon = status === "completed" ? "✓" : status === "error" ? "✗" : "…";
        return (
            <div className="part-tool">
                🔧 {part.tool} <span className={`tool-${status}`}>{icon}</span>
            </div>
        );
    }
    return null;
}

function describeError(error: unknown): string {
    if (typeof error === "string") return error;
    if (error && typeof error === "object") {
        const e = error as { data?: { message?: string }; message?: string; name?: string };
        return e.data?.message ?? e.message ?? e.name ?? "error";
    }
    return "error";
}

function ContinueSheet(props: {
    fleet: FleetSnapshot;
    session: SessionRecord;
    onClose: () => void;
}) {
    const targets = props.fleet.machines.filter(
        (m) => m.opencodeOnline && m.id !== props.session.machineId,
    );
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState("");
    const go = async (machineId: string) => {
        setBusy(true);
        setError("");
        try {
            const created = await api.continueSession(props.session.id, machineId);
            props.onClose();
            window.location.hash = `#/chat/${created.id}`;
        } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
            setBusy(false);
        }
    };
    return (
        <div className="sheet-backdrop" onClick={props.onClose}>
            <div className="sheet" onClick={(e) => e.stopPropagation()}>
                <h2>Continue elsewhere</h2>
                <p className="hint">
                    Starts a <b>new</b> session on another machine seeded with this
                    conversation's transcript. Files and tool state do not follow.
                </p>
                {targets.length === 0 && <p className="empty">No other machines online.</p>}
                {targets.map((m) => (
                    <button key={m.id} disabled={busy} onClick={() => go(m.id)}>
                        ↪ {m.name}
                    </button>
                ))}
                {error && <p className="error">{error}</p>}
            </div>
        </div>
    );
}
