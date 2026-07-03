// Fleet/shared/src/sse.ts
//
// What: Tiny Server-Sent Events helpers shared by both Node services.
// Does: SseHub broadcasts JSON events to connected HTTP responses with
//       monotonically increasing ids and a replay ring buffer (so clients on
//       flaky links can resume via Last-Event-ID). subscribeSse is a
//       fetch-based SSE *client* with automatic reconnection.
// Touches: Node HTTP response objects (structurally typed), global fetch.
// Touched by: orchestrator (hub + client) and mcp-diffusion (hub).

/** Structural subset of http.ServerResponse we need; keeps express out of shared. */
export interface SseResponse {
    setHeader(name: string, value: string): void;
    write(chunk: string): boolean;
    flushHeaders?(): void;
    on(event: "close", listener: () => void): unknown;
}

interface BufferedEvent {
    id: number;
    payload: string;
}

/** Broadcast hub with Last-Event-ID replay. One instance per service process. */
export class SseHub<T> {
    private clients = new Set<SseResponse>();
    private nextId = 1;
    private buffer: BufferedEvent[] = [];

    constructor(private readonly bufferSize = 500) {}

    /** Attach an HTTP response as an SSE subscriber, replaying missed events. */
    attach(res: SseResponse, lastEventId?: string): void {
        res.setHeader("content-type", "text/event-stream");
        res.setHeader("cache-control", "no-cache, no-transform");
        res.setHeader("connection", "keep-alive");
        res.setHeader("x-accel-buffering", "no");
        res.flushHeaders?.();
        // Ask EventSource to wait 2s before reconnecting (Tailscale flaps recover fast).
        res.write("retry: 2000\n\n");
        const since = lastEventId ? Number.parseInt(lastEventId, 10) : Number.NaN;
        if (Number.isFinite(since)) {
            for (const ev of this.buffer) {
                if (ev.id > since) res.write(ev.payload);
            }
        }
        this.clients.add(res);
        res.on("close", () => this.clients.delete(res));
    }

    /** Broadcast one JSON event to all subscribers and record it for replay. */
    broadcast(event: T): void {
        const id = this.nextId++;
        const payload = `id: ${id}\ndata: ${JSON.stringify(event)}\n\n`;
        this.buffer.push({ id, payload });
        if (this.buffer.length > this.bufferSize) this.buffer.shift();
        for (const res of this.clients) {
            try {
                res.write(payload);
            } catch {
                this.clients.delete(res);
            }
        }
    }

    /** Comment-line heartbeat so proxies/idle links don't kill the stream. */
    heartbeat(): void {
        for (const res of this.clients) {
            try {
                res.write(": ping\n\n");
            } catch {
                this.clients.delete(res);
            }
        }
    }

    get clientCount(): number {
        return this.clients.size;
    }
}

export interface SseSubscription {
    close(): void;
}

/**
 * Fetch-based SSE client with automatic exponential-backoff reconnection.
 * Used by the orchestrator to follow the diffusion server's event stream.
 */
export function subscribeSse<T>(
    url: string,
    onEvent: (event: T) => void,
    options: {
        headers?: Record<string, string>;
        onStateChange?: (connected: boolean) => void;
    } = {},
): SseSubscription {
    let closed = false;
    let retryMs = 1_000;
    let controller: AbortController | undefined;

    const loop = async (): Promise<void> => {
        while (!closed) {
            controller = new AbortController();
            try {
                const res = await fetch(url, {
                    headers: { accept: "text/event-stream", ...options.headers },
                    signal: controller.signal,
                });
                if (!res.ok || !res.body) throw new Error(`SSE ${res.status}`);
                options.onStateChange?.(true);
                retryMs = 1_000;
                const reader = res.body.getReader();
                const decoder = new TextDecoder();
                let pending = "";
                for (;;) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    pending += decoder.decode(value, { stream: true });
                    let sep: number;
                    // SSE frames are separated by a blank line.
                    while ((sep = pending.indexOf("\n\n")) >= 0) {
                        const frame = pending.slice(0, sep);
                        pending = pending.slice(sep + 2);
                        const data = frame
                            .split("\n")
                            .filter((l) => l.startsWith("data:"))
                            .map((l) => l.slice(5).trim())
                            .join("\n");
                        if (!data) continue;
                        try {
                            onEvent(JSON.parse(data) as T);
                        } catch {
                            /* ignore malformed frame */
                        }
                    }
                }
            } catch {
                /* fall through to reconnect */
            }
            options.onStateChange?.(false);
            if (closed) return;
            await new Promise((r) => setTimeout(r, retryMs));
            retryMs = Math.min(retryMs * 2, 30_000);
        }
    };
    void loop();

    return {
        close() {
            closed = true;
            controller?.abort();
        },
    };
}
