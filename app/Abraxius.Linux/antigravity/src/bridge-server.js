"use strict";

const crypto = require("crypto");
const http = require("http");

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
      try { resolve(JSON.parse(body)); }
      catch { reject(Object.assign(new Error("Request body must be valid JSON"), { statusCode: 400 })); }
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

function createBridgeServer(options) {
  if (!options?.session) throw new TypeError("session is required");
  const session = options.session;
  const token = options.token || crypto.randomBytes(32).toString("hex");
  const host = options.host || "127.0.0.1";
  const initialPort = options.port === undefined ? 13472 : Number(options.port);
  const fallbackPorts = Array.isArray(options.fallbackPorts)
    ? options.fallbackPorts.map(Number)
    : [initialPort];
  let boundPort = initialPort;
  const eventClients = new Set();
  const jobs = new Map();

  function jobView(job) {
    return {
      id: job.id,
      status: job.status,
      createdAt: job.createdAt,
      startedAt: job.startedAt || null,
      completedAt: job.completedAt || null,
      result: job.result || null,
      error: job.error || null,
    };
  }

  function retainJob(job) {
    jobs.set(job.id, job);
    while (jobs.size > 100) jobs.delete(jobs.keys().next().value);
  }

  function isAuthorized(req, url) {
    const authorization = req.headers.authorization || "";
    const bearer = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
    return timingSafeEqual(bearer || url.searchParams.get("token"), token);
  }

  function publish(type, payload) {
    const data = JSON.stringify({ type, timestamp: new Date().toISOString(), payload });
    for (const client of eventClients) client.write(`event: ${type}\ndata: ${data}\n\n`);
  }

  const relayedEvents = [
    "connected", "exit", "fault", "output", "queued", "reconnecting",
    "request", "request-error", "response", "state",
  ];
  for (const eventName of relayedEvents) {
    session.on(eventName, (payload) => {
      if (eventName === "request" && jobs.has(payload?.id)) {
        const job = jobs.get(payload.id);
        job.status = "running";
        job.startedAt = new Date().toISOString();
      }
      if (payload?.error instanceof Error) payload = { ...payload, error: payload.error.message };
      publish(eventName, payload);
    });
  }

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host || `${host}:${boundPort}`}`);

    try {
      if (req.method === "GET" && url.pathname === "/health") {
        return sendJson(res, 200, { ok: true, session: session.status() });
      }

      if (!isAuthorized(req, url)) return sendJson(res, 401, { error: "Unauthorized" });

      if (req.method === "GET" && url.pathname === "/v1/events") {
        res.writeHead(200, {
          "content-type": "text/event-stream",
          "cache-control": "no-cache, no-transform",
          connection: "keep-alive",
          "x-accel-buffering": "no",
        });
        res.write(`event: state\ndata: ${JSON.stringify({ type: "state", payload: session.status() })}\n\n`);
        eventClients.add(res);
        req.on("close", () => eventClients.delete(res));
        return;
      }

      if (req.method === "POST" && url.pathname === "/v1/session/start") {
        const status = await session.start();
        return sendJson(res, 200, { ok: true, session: status });
      }

      if (req.method === "POST" && url.pathname === "/v1/session/restart") {
        const status = await session.restart();
        return sendJson(res, 200, { ok: true, session: status });
      }

      if (req.method === "POST" && url.pathname === "/v1/session/interrupt") {
        return sendJson(res, session.interrupt() ? 200 : 409, {
          ok: Boolean(session.child),
          session: session.status(),
        });
      }

      if (req.method === "POST" && url.pathname === "/v1/session/input") {
        const body = await readJson(req);
        if (typeof body.data !== "string") {
          return sendJson(res, 400, { error: "data must be a string" });
        }
        const result = session.writeInput(body.data);
        return sendJson(res, result.written ? 200 : 409, { ok: result.written, result });
      }

      if (req.method === "DELETE" && url.pathname === "/v1/session") {
        await session.stop();
        return sendJson(res, 200, { ok: true, session: session.status() });
      }

      if (req.method === "POST" && url.pathname === "/v1/prompt") {
        const body = await readJson(req);
        if (typeof body.prompt !== "string" || !body.prompt.trim()) {
          return sendJson(res, 400, { error: "prompt must be a non-empty string" });
        }
        const result = await session.send(body.prompt, { timeoutMs: body.timeoutMs });
        return sendJson(res, 200, { ok: true, result });
      }

      if (req.method === "POST" && url.pathname === "/v1/prompt/stream") {
        const body = await readJson(req);
        if (typeof body.prompt !== "string" || !body.prompt.trim()) {
          return sendJson(res, 400, { error: "prompt must be a non-empty string" });
        }
        res.writeHead(200, {
          "content-type": "text/event-stream; charset=utf-8",
          "cache-control": "no-cache, no-transform",
          connection: "keep-alive",
          "x-accel-buffering": "no",
        });

        const id = crypto.randomUUID();
        const onOutput = (data) => {
          if (res.writableEnded || res.destroyed) return;
          res.write(`event: output\ndata: ${JSON.stringify(data)}\n\n`);
        };

        session.on("output", onOutput);

        try {
          const result = await session.send(body.prompt, { id, timeoutMs: body.timeoutMs });
          if (!res.writableEnded && !res.destroyed) {
            res.write(`event: response\ndata: ${JSON.stringify({ type: "response", payload: result })}\n\n`);
            res.end();
          }
        } catch (error) {
          if (!res.writableEnded && !res.destroyed) {
            res.write(`event: error\ndata: ${JSON.stringify({ type: "error", error: error.message })}\n\n`);
            res.end();
          }
        } finally {
          session.off("output", onOutput);
        }
        return;
      }

      if (req.method === "POST" && url.pathname === "/v1/jobs") {
        const body = await readJson(req);
        if (typeof body.prompt !== "string" || !body.prompt.trim()) {
          return sendJson(res, 400, { error: "prompt must be a non-empty string" });
        }
        const id = crypto.randomUUID();
        const job = { id, status: "queued", createdAt: new Date().toISOString() };
        retainJob(job);
        session.send(body.prompt, { id, timeoutMs: body.timeoutMs }).then((result) => {
          job.status = "completed";
          job.completedAt = new Date().toISOString();
          job.result = result;
          publish("job", jobView(job));
        }).catch((error) => {
          job.status = /cancel|interrupt/i.test(error.message) ? "canceled" : "failed";
          job.completedAt = new Date().toISOString();
          job.error = error.message;
          publish("job", jobView(job));
        });
        return sendJson(res, 202, { ok: true, job: jobView(job) });
      }

      if (req.method === "GET" && url.pathname === "/v1/jobs") {
        return sendJson(res, 200, { ok: true, jobs: [...jobs.values()].reverse().map(jobView) });
      }

      const jobMatch = url.pathname.match(/^\/v1\/jobs\/([0-9a-f-]+)$/i);
      if (jobMatch && req.method === "GET") {
        const job = jobs.get(jobMatch[1]);
        return job ? sendJson(res, 200, { ok: true, job: jobView(job) }) : sendJson(res, 404, { error: "Job not found" });
      }
      if (jobMatch && req.method === "DELETE") {
        const job = jobs.get(jobMatch[1]);
        if (!job) return sendJson(res, 404, { error: "Job not found" });
        if (!["queued", "running"].includes(job.status)) return sendJson(res, 409, { error: `Job is already ${job.status}`, job: jobView(job) });
        const canceled = session.cancel(job.id);
        return sendJson(res, canceled ? 202 : 409, { ok: canceled, job: jobView(job) });
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
    listen() {
      return new Promise((resolve, reject) => {
        const portsToTry = fallbackPorts.includes(initialPort) ? [...fallbackPorts] : [initialPort, ...fallbackPorts];
        const tryListen = (remainingPorts) => {
          if (remainingPorts.length === 0) {
            return reject(new Error(`Failed to bind bridge server on ${host}:${initialPort}`));
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
      for (const client of eventClients) client.end();
      eventClients.clear();
      return new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    },
  };
}

module.exports = { createBridgeServer, readJson, timingSafeEqual };
