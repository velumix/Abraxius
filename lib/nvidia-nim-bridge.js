"use strict";

const crypto = require("crypto");
const fs = require("fs");
const http = require("http");
const path = require("path");
const { NvidiaNimClient, DEFAULT_MODEL, DEFAULT_ENDPOINT } = require("./nvidia-nim");

function timingSafeEqual(left, right) {
  const a = Buffer.from(String(left || ""));
  const b = Buffer.from(String(right || ""));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function readJson(req, limit = 256_000) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > limit) {
        reject(Object.assign(new Error("Request body too large"), { statusCode: 413 }));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!body) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(Object.assign(new Error("Request body must be valid JSON"), { statusCode: 400 }));
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res, statusCode, body) {
  const data = JSON.stringify(body);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(data),
    "cache-control": "no-store",
  });
  res.end(data);
}

function getNimBridgeInfo(userDataDir) {
  if (!userDataDir) return null;
  const file = path.join(userDataDir, "linux", "nvidia-nim-bridge.json");
  if (!fs.existsSync(file)) return null;
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

function saveNimBridgeInfo(userDataDir, info) {
  if (!userDataDir) return;
  const dir = path.join(userDataDir, "linux");
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  const file = path.join(dir, "nvidia-nim-bridge.json");
  fs.writeFileSync(file, JSON.stringify(info, null, 2), { mode: 0o600 });
  try { fs.chmodSync(file, 0o600); } catch {}

  const tokenFile = path.join(dir, "nvidia-nim-token");
  fs.writeFileSync(tokenFile, `${info.token}\n`, { mode: 0o600 });
  try { fs.chmodSync(tokenFile, 0o600); } catch {}
}

function createNimBridgeServer(options = {}) {
  const getApiKey = options.getApiKey || (() => "");
  const getSettings = options.getSettings || (() => ({ endpoint: DEFAULT_ENDPOINT, model: DEFAULT_MODEL }));
  const token = options.token || crypto.randomBytes(32).toString("hex");
  const host = options.host || "127.0.0.1";
  const initialPort = options.port === undefined ? 13476 : Number(options.port);
  const fallbackPorts = Array.isArray(options.fallbackPorts)
    ? options.fallbackPorts.map(Number)
    : [initialPort, 13477, 13478, 13479];
  const clientFactory = options.clientFactory || ((opts) => new NvidiaNimClient(opts));

  let boundPort = initialPort;
  let activeJob = null;
  const queue = [];
  const activeJobsMap = new Map();

  function isAuthorized(req, url) {
    const authorization = req.headers.authorization || "";
    const bearer = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
    return timingSafeEqual(bearer || url.searchParams.get("token"), token);
  }

  function runNextJob() {
    if (activeJob || queue.length === 0) return;
    const job = queue.shift();
    activeJob = job;
    job.status = "running";

    options.onChatStart?.({
      sessionId: job.sessionId,
      prompt: job.prompt,
      source: job.source,
      status: "running",
      model: job.model || getSettings().model || DEFAULT_MODEL,
    });

    if (job.res && !job.res.writableEnded && !job.res.destroyed) {
      job.res.write(`event: status\ndata: ${JSON.stringify({ status: "running", sessionId: job.sessionId })}\n\n`);
    }

    const apiKey = getApiKey();
    if (!apiKey) {
      const err = new Error("NVIDIA NIM API key is not configured in Abraxius.");
      job.status = "error";
      job.error = err.message;
      options.onChatEnd?.({
        sessionId: job.sessionId,
        ok: false,
        error: err.message,
        source: job.source,
      });
      if (job.res && !job.res.writableEnded && !job.res.destroyed) {
        job.res.write(`event: error\ndata: ${JSON.stringify({ error: err.message })}\n\n`);
        job.res.end();
      }
      job.resolve?.({ ok: false, sessionId: job.sessionId, error: err.message });
      activeJobsMap.delete(job.sessionId);
      activeJob = null;
      setImmediate(runNextJob);
      return;
    }

    const settings = getSettings();
    const client = clientFactory({
      apiKey,
      endpoint: job.endpoint || settings.endpoint || DEFAULT_ENDPOINT,
      model: job.model || settings.model || DEFAULT_MODEL,
      temperature: job.temperature ?? settings.temperature,
      topP: job.topP ?? settings.topP,
      maxTokens: job.maxTokens ?? settings.maxTokens,
      reasoningBudget: job.reasoningBudget ?? settings.reasoningBudget,
    });

    const messages = Array.isArray(job.messages) && job.messages.length > 0
      ? [...job.messages]
      : [{ role: "user", content: job.prompt }];

    client
      .streamChat({
        messages,
        signal: job.controller.signal,
        onReasoning: (chunk) => {
          options.onReasoning?.({ sessionId: job.sessionId, chunk, source: job.source });
          if (job.res && !job.res.writableEnded && !job.res.destroyed) {
            job.res.write(`event: reasoning\ndata: ${JSON.stringify({ chunk })}\n\n`);
          }
        },
        onChunk: (chunk) => {
          options.onChunk?.({ sessionId: job.sessionId, chunk, source: job.source });
          if (job.res && !job.res.writableEnded && !job.res.destroyed) {
            job.res.write(`event: chunk\ndata: ${JSON.stringify({ chunk })}\n\n`);
          }
        },
      })
      .then((result) => {
        job.status = "completed";
        options.onChatEnd?.({
          sessionId: job.sessionId,
          ok: true,
          reasoning: result.reasoning,
          fullText: result.fullText,
          source: job.source,
        });
        if (job.res && !job.res.writableEnded && !job.res.destroyed) {
          job.res.write(
            `event: done\ndata: ${JSON.stringify({
              ok: true,
              reasoning: result.reasoning,
              fullText: result.fullText,
            })}\n\n`,
          );
          job.res.end();
        }
        job.resolve?.({ ok: true, sessionId: job.sessionId, reasoning: result.reasoning, fullText: result.fullText });
      })
      .catch((error) => {
        const isCancelled = job.controller.signal.aborted;
        job.status = isCancelled ? "cancelled" : "error";
        job.error = error.message;
        options.onChatEnd?.({
          sessionId: job.sessionId,
          ok: false,
          error: error.message,
          cancelled: isCancelled,
          source: job.source,
        });
        if (job.res && !job.res.writableEnded && !job.res.destroyed) {
          job.res.write(
            `event: error\ndata: ${JSON.stringify({ error: error.message, cancelled: isCancelled })}\n\n`,
          );
          job.res.end();
        }
        job.resolve?.({
          ok: false,
          sessionId: job.sessionId,
          error: error.message,
          cancelled: isCancelled,
        });
      })
      .finally(() => {
        activeJobsMap.delete(job.sessionId);
        activeJob = null;
        setImmediate(runNextJob);
      });
  }

  function submitJob(params, res = null) {
    const sessionId = params.sessionId || `nim-${Date.now()}-${crypto.randomBytes(4).toString("hex")}`;
    const controller = new AbortController();
    let jobResolve;
    let jobReject;
    const promise = new Promise((resolve, reject) => {
      jobResolve = resolve;
      jobReject = reject;
    });

    const job = {
      sessionId,
      prompt: params.prompt || "",
      messages: params.messages,
      model: params.model,
      endpoint: params.endpoint,
      temperature: params.temperature,
      topP: params.topP,
      maxTokens: params.maxTokens,
      reasoningBudget: params.reasoningBudget,
      source: params.source || "cli",
      controller,
      res,
      status: "queued",
      createdAt: Date.now(),
      resolve: jobResolve,
      reject: jobReject,
    };

    if (res) {
      res.on("close", () => {
        if (job.status === "queued" || job.status === "running") {
          cancelJob(sessionId);
        }
      });
    }

    activeJobsMap.set(sessionId, job);
    queue.push(job);

    options.onChatStart?.({
      sessionId,
      prompt: job.prompt,
      source: job.source,
      status: "queued",
      model: job.model || getSettings().model || DEFAULT_MODEL,
    });

    setImmediate(runNextJob);

    return { sessionId, promise, controller };
  }

  function cancelJob(sessionId) {
    const job = activeJobsMap.get(sessionId);
    if (!job) return false;
    job.controller.abort();
    const idx = queue.indexOf(job);
    if (idx >= 0) {
      queue.splice(idx, 1);
      job.status = "cancelled";
      options.onChatEnd?.({
        sessionId,
        ok: false,
        error: "Cancelled before starting",
        cancelled: true,
        source: job.source,
      });
      if (job.res && !job.res.writableEnded && !job.res.destroyed) {
        job.res.write(`event: error\ndata: ${JSON.stringify({ error: "Cancelled", cancelled: true })}\n\n`);
        job.res.end();
      }
      job.resolve?.({ ok: false, sessionId, error: "Cancelled", cancelled: true });
      activeJobsMap.delete(sessionId);
    }
    return true;
  }

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host || `${host}:${boundPort}`}`);

    try {
      if (req.method === "GET" && url.pathname === "/health") {
        const apiKey = getApiKey();
        return sendJson(res, 200, {
          ok: true,
          hasApiKey: Boolean(apiKey),
          port: boundPort,
          activeJob: activeJob ? activeJob.sessionId : null,
          queueLength: queue.length,
        });
      }

      if (!isAuthorized(req, url)) {
        return sendJson(res, 401, { error: "Unauthorized" });
      }

      if (req.method === "POST" && (url.pathname === "/v1/nim/chat" || url.pathname === "/v1/chat/completions")) {
        const body = await readJson(req);
        if (!body.prompt && (!Array.isArray(body.messages) || body.messages.length === 0)) {
          return sendJson(res, 400, { error: "prompt or messages is required" });
        }
        res.writeHead(200, {
          "content-type": "text/event-stream; charset=utf-8",
          "cache-control": "no-cache, no-transform",
          connection: "keep-alive",
          "x-accel-buffering": "no",
        });

        const promptText = body.prompt || (body.messages?.[body.messages.length - 1]?.content || "");
        submitJob({ ...body, prompt: promptText, source: body.source || "cli" }, res);
        return;
      }

      if (req.method === "POST" && url.pathname === "/v1/nim/cancel") {
        const body = await readJson(req);
        const canceled = cancelJob(body.sessionId);
        return sendJson(res, canceled ? 200 : 404, { ok: canceled });
      }

      return sendJson(res, 404, { error: "Not found" });
    } catch (error) {
      const statusCode = error.statusCode || 500;
      sendJson(res, statusCode, { error: error.message || String(error) });
    }
  });

  return {
    host,
    get port() {
      return server.address()?.port || boundPort;
    },
    server,
    token,
    submitJob,
    cancelJob,
    listen() {
      return new Promise((resolve, reject) => {
        const portsToTry = fallbackPorts.includes(initialPort) ? [...fallbackPorts] : [initialPort, ...fallbackPorts];
        const tryListen = (remainingPorts) => {
          if (remainingPorts.length === 0) {
            return reject(new Error(`Failed to bind NIM bridge server on ${host}:${initialPort}`));
          }
          const currentPort = remainingPorts[0];
          const onError = (error) => {
            if (error.code === "EADDRINUSE" && remainingPorts.length > 1) {
              server.off("error", onError);
              tryListen(remainingPorts.slice(1));
            } else {
              server.off("error", onError);
              reject(error);
            }
          };
          server.once("error", onError);
          server.listen(currentPort, host, () => {
            server.off("error", onError);
            boundPort = server.address().port;
            resolve(server.address());
          });
        };
        tryListen(portsToTry);
      });
    },
    close() {
      return new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
    },
  };
}

module.exports = {
  createNimBridgeServer,
  getNimBridgeInfo,
  saveNimBridgeInfo,
  timingSafeEqual,
};
