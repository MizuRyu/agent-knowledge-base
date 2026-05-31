import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { createInterface, type Interface as ReadlineInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { AIConfigError, AITransientError } from './errors.ts';

type RuriInputType = 'document' | 'query';

interface RuriWorkerRequest {
  id: string;
  model: string;
  input_type: RuriInputType;
  texts: string[];
}

interface RuriWorkerResponse {
  id: string;
  embeddings?: number[][];
  error?: string;
}

interface PendingRequest {
  resolve: (value: number[][]) => void;
  reject: (reason: unknown) => void;
  timer: ReturnType<typeof setTimeout>;
  abort?: () => void;
}

let worker: ChildProcessWithoutNullStreams | null = null;
let stdoutLines: ReadlineInterface | null = null;
let idleTimer: ReturnType<typeof setTimeout> | null = null;
let requestSeq = 0;
const pending = new Map<string, PendingRequest>();
const stderrTail: string[] = [];

function defaultWorkerPath(): string {
  return fileURLToPath(new URL('../../../scripts/ruri_embed_worker.py', import.meta.url));
}

function workerCommand(): { command: string; args: string[] } {
  const command = process.env.GBRAIN_RURI_UV || 'uv';
  const script = process.env.GBRAIN_RURI_WORKER || defaultWorkerPath();
  return {
    command,
    args: [
      'run',
      '--with',
      'sentence-transformers>=3.0',
      '--with',
      'transformers>=4.48.0',
      '--with',
      'torch',
      '--with',
      'numpy',
      'python',
      script,
    ],
  };
}

function rejectAll(err: Error): void {
  for (const [id, req] of pending) {
    clearTimeout(req.timer);
    req.abort?.();
    req.reject(err);
    pending.delete(id);
  }
}

function clearIdleTimer(): void {
  if (!idleTimer) return;
  clearTimeout(idleTimer);
  idleTimer = null;
}

function scheduleIdleShutdown(): void {
  if (pending.size > 0 || !worker) return;
  clearIdleTimer();
  const idleMs = Number.parseInt(process.env.GBRAIN_RURI_IDLE_TIMEOUT_MS || '2000', 10);
  idleTimer = setTimeout(() => {
    if (pending.size > 0) return;
    worker?.kill();
    cleanupWorker();
  }, idleMs);
}

function ensureWorker(): ChildProcessWithoutNullStreams {
  clearIdleTimer();
  if (worker && !worker.killed) return worker;

  const { command, args } = workerCommand();
  stderrTail.length = 0;
  worker = spawn(command, args, {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: {
      ...process.env,
      GBRAIN_RURI_MODEL: process.env.GBRAIN_RURI_MODEL || 'cl-nagoya/ruri-v3-310m',
      TOKENIZERS_PARALLELISM: process.env.TOKENIZERS_PARALLELISM || 'false',
      TRANSFORMERS_VERBOSITY: process.env.TRANSFORMERS_VERBOSITY || 'error',
    },
  });

  stdoutLines = createInterface({ input: worker.stdout });
  stdoutLines.on('line', line => {
    let msg: RuriWorkerResponse;
    try {
      msg = JSON.parse(line);
    } catch {
      return;
    }
    const req = pending.get(msg.id);
    if (!req) return;
    pending.delete(msg.id);
    clearTimeout(req.timer);
    req.abort?.();
    if (msg.error) {
      req.reject(new AITransientError(`Ruri worker error: ${msg.error}`));
      scheduleIdleShutdown();
      return;
    }
    if (!Array.isArray(msg.embeddings)) {
      req.reject(new AIConfigError('Ruri worker returned no embeddings.'));
      scheduleIdleShutdown();
      return;
    }
    req.resolve(msg.embeddings);
    scheduleIdleShutdown();
  });

  worker.stderr.on('data', chunk => {
    for (const line of String(chunk).split(/\r?\n/)) {
      if (!line.trim()) continue;
      stderrTail.push(line.slice(0, 500));
      if (stderrTail.length > 20) stderrTail.shift();
    }
  });

  worker.on('error', err => {
    const message = `Failed to start Ruri worker with ${command}: ${err.message}`;
    rejectAll(new AIConfigError(message, 'Install uv and ensure sentence-transformers / torch can run locally.'));
    cleanupWorker();
  });

  worker.on('exit', (code, signal) => {
    const detail = stderrTail.length ? ` stderr: ${stderrTail.join('\n')}` : '';
    rejectAll(new AITransientError(`Ruri worker exited code=${code} signal=${signal}.${detail}`));
    cleanupWorker();
  });

  return worker;
}

function cleanupWorker(): void {
  clearIdleTimer();
  stdoutLines?.close();
  stdoutLines = null;
  worker = null;
}

export async function embedWithRuriWorker(
  modelId: string,
  texts: string[],
  inputType: RuriInputType,
  abortSignal?: AbortSignal,
): Promise<number[][]> {
  if (texts.length === 0) return [];
  const child = ensureWorker();
  const id = `ruri-${Date.now()}-${++requestSeq}`;
  const timeoutMs = Number.parseInt(process.env.GBRAIN_RURI_TIMEOUT_MS || '120000', 10);

  return await new Promise<number[][]>((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new AITransientError(`Ruri worker request timed out after ${timeoutMs}ms.`));
      scheduleIdleShutdown();
    }, timeoutMs);

    let abort: (() => void) | undefined;
    if (abortSignal) {
      abort = () => {
        clearTimeout(timer);
        pending.delete(id);
        reject(new AITransientError('Ruri worker request aborted.'));
        scheduleIdleShutdown();
      };
      if (abortSignal.aborted) {
        abort();
        return;
      }
      abortSignal.addEventListener('abort', abort, { once: true });
    }

    pending.set(id, {
      resolve,
      reject,
      timer,
      abort: abortSignal && abort ? () => abortSignal.removeEventListener('abort', abort) : undefined,
    });

    const payload: RuriWorkerRequest = {
      id,
      model: modelId,
      input_type: inputType,
      texts,
    };
    child.stdin.write(`${JSON.stringify(payload)}\n`, err => {
      if (!err) return;
      pending.delete(id);
      clearTimeout(timer);
      abortSignal && abort && abortSignal.removeEventListener('abort', abort);
      reject(new AITransientError(`Failed to write to Ruri worker: ${err.message}`));
      scheduleIdleShutdown();
    });
  });
}

export function shutdownRuriWorkerForTests(): void {
  rejectAll(new AITransientError('Ruri worker shutdown requested.'));
  worker?.kill();
  cleanupWorker();
}
