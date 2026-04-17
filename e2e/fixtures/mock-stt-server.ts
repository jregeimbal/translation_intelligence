import { type Server, createServer, type IncomingMessage } from "http";
import { WebSocketServer, type WebSocket } from "ws";

export interface MockSttServerOptions {
  /**
   * When the mock STT server receives audio chunks it will wait for
   * `responseDelayMs` before emitting the scripted recognition results.
   */
  responseDelayMs?: number;
  /** Port to listen on (0 = random). */
  port?: number;
}

export interface ScriptedUtterance {
  /** The words to emit as an interim (partial) result. */
  interimText: string;
  /** The words to emit as the final result. */
  finalText: string;
  /** Speaker index (for diarisation). */
  speaker?: number;
}

/**
 * A tiny WebSocket server that speaks the same protocol as the real backend
 * `/v1/stt/live` endpoint, but emits scripted recognition results instead of
 * performing real speech recognition.
 */
export class MockSttServer {
  private httpServer: Server | null = null;
  private wss: WebSocketServer | null = null;
  private utterances: ScriptedUtterance[] = [];
  private responseDelayMs: number;
  private port: number;
  private _address: string | null = null;

  constructor(opts: MockSttServerOptions = {}) {
    this.responseDelayMs = opts.responseDelayMs ?? 300;
    this.port = opts.port ?? 0;
  }

  /** Script the recognition results the server will emit. */
  setUtterances(utterances: ScriptedUtterance[]): void {
    this.utterances = utterances;
  }

  /** Start the mock server and return the base URL (http://…). */
  async start(): Promise<string> {
    return new Promise((resolve, reject) => {
      const server = createServer();
      this.httpServer = server;
      const wss = new WebSocketServer({ server });
      this.wss = wss;

      wss.on("connection", (ws: WebSocket, _req: IncomingMessage) => {
        this.handleConnection(ws);
      });

      server.listen(this.port, "127.0.0.1", () => {
        const addr = server.address();
        if (!addr || typeof addr === "string") {
          reject(new Error("Failed to bind"));
          return;
        }
        this._address = `http://127.0.0.1:${addr.port}`;
        resolve(this._address);
      });

      server.on("error", reject);
    });
  }

  get address(): string {
    if (!this._address) throw new Error("Server not started");
    return this._address;
  }

  async stop(): Promise<void> {
    this.wss?.close();
    await new Promise<void>((resolve) => {
      if (this.httpServer) {
        this.httpServer.close(() => resolve());
      } else {
        resolve();
      }
    });
    this._address = null;
  }

  // -----------------------------------------------------------------------
  private handleConnection(ws: WebSocket): void {
    let started = false;
    let audioChunksReceived = 0;

    ws.on("message", (data: Buffer | string) => {
      if (!started) {
        // First message should be the start payload (JSON text).
        try {
          const payload = JSON.parse(data.toString());
          if (payload.type !== "start") {
            ws.send(JSON.stringify({ type: "error", message: "Expected start" }));
            ws.close();
            return;
          }
          started = true;
          ws.send(JSON.stringify({ type: "ready" }));

          // After a short delay, emit the scripted utterances.
          setTimeout(() => {
            this.emitUtterances(ws);
          }, this.responseDelayMs);
        } catch {
          ws.send(JSON.stringify({ type: "error", message: "Bad JSON" }));
          ws.close();
        }
        return;
      }

      // Subsequent messages are audio chunks – just count them.
      audioChunksReceived++;
    });
  }

  private emitUtterances(ws: WebSocket): void {
    let idx = 0;
    const next = () => {
      if (idx >= this.utterances.length) return;
      const u = this.utterances[idx++];

      // Interim result
      ws.send(
        JSON.stringify({
          type: "recognition_result",
          isFinal: false,
          speechFinal: false,
          words: textToWords(u.interimText, u.speaker),
        }),
      );

      // Final result after a small gap.
      setTimeout(() => {
        ws.send(
          JSON.stringify({
            type: "recognition_result",
            isFinal: true,
            speechFinal: true,
            words: textToWords(u.finalText, u.speaker),
          }),
        );
        // Emit next utterance.
        setTimeout(next, 100);
      }, 150);
    };
    next();
  }
}

function textToWords(
  text: string,
  speaker?: number,
): { word: string; speaker?: number }[] {
  return text
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => ({
      word,
      ...(speaker != null ? { speaker } : {}),
    }));
}
