"use strict";

const fs = require("fs");
const path = require("path");

const DEFAULT_MODEL = "inclusionai/ling-3.0-flash:free";
const DEFAULT_ENDPOINT = "https://openrouter.ai/api/v1";

class OpenRouterError extends Error {
  constructor(message, options = {}) {
    super(message);
    this.name = "OpenRouterError";
    this.status = options.status || null;
    this.code = options.code || "OPENROUTER_ERROR";
    this.isRateLimit = options.isRateLimit || options.status === 429;
    this.isAuthError = options.isAuthError || options.status === 401 || options.status === 403;
    this.isUnavailable = options.isUnavailable || [404, 502, 503, 504].includes(options.status);
    this.isPartial = options.isPartial || false;
    this.retryAfterMs = options.retryAfterMs || null;
    this.partialText = options.partialText || "";
    this.partialToolCalls = options.partialToolCalls || [];
  }
}

function parseRetryAfter(headerValue) {
  if (!headerValue) return null;
  const str = String(headerValue).trim();
  if (/^\d+$/.test(str)) {
    return Math.max(0, parseInt(str, 10) * 1000);
  }
  const dateMs = Date.parse(str);
  if (!isNaN(dateMs)) {
    return Math.max(0, dateMs - Date.now());
  }
  return null;
}

function isRetryableStatus(status) {
  return [408, 409, 425, 429, 500, 502, 503, 504].includes(status);
}

class OpenRouterClient {
  constructor(options = {}) {
    this.endpoint = (options.endpoint || DEFAULT_ENDPOINT).replace(/\/+$/, "");
    this.apiKey = options.apiKey || "";
    this.customFetch = options.fetch || globalThis.fetch;
    this.maxRetries = options.maxRetries !== undefined ? Math.max(0, Math.min(10, Number(options.maxRetries))) : 3;
    this.initialBackoffMs = options.initialBackoffMs || 1000;
    this.maxBackoffMs = options.maxBackoffMs !== undefined ? Math.max(1000, Number(options.maxBackoffMs)) : 30000;
  }

  headers() {
    return {
      "Content-Type": "application/json",
      Authorization: `Bearer ${this.apiKey}`,
      "HTTP-Referer": "http://127.0.0.1:13470",
      "X-Title": "Abraxius",
    };
  }

  async listModels(options = {}) {
    const { signal, freeOnly = false } = options;
    const response = await this.customFetch(`${this.endpoint}/models`, {
      headers: this.headers(),
      signal: signal || AbortSignal.timeout(10000),
    });
    if (!response.ok) {
      throw new OpenRouterError(`OpenRouter returned HTTP ${response.status}`, { status: response.status });
    }
    const data = await response.json();
    const rawList = Array.isArray(data.data) ? data.data : [];
    
    const parsed = rawList.map((model) => {
      const pPrompt = model.pricing?.prompt;
      const pComp = model.pricing?.completion;
      const isFree = Boolean(
        (model.id && model.id.endsWith(":free")) ||
        (pPrompt !== null && pPrompt !== undefined && Number(pPrompt) === 0 &&
         pComp !== null && pComp !== undefined && Number(pComp) === 0)
      );
      return {
        id: model.id,
        name: model.name || model.id,
        contextLength: model.context_length || 0,
        promptPrice: pPrompt !== undefined ? pPrompt : null,
        completionPrice: pComp !== undefined ? pComp : null,
        isFree,
      };
    });

    if (freeOnly) {
      return parsed.filter((m) => m.isFree);
    }
    return parsed;
  }

  async streamChat(options = {}) {
    const {
      model,
      messages = [],
      temperature = 0.7,
      signal,
      onChunk,
      onRetry,
      tools = [],
      toolChoice,
      maxRetries = this.maxRetries,
      maxBackoffMs = this.maxBackoffMs,
    } = options;

    if (!this.apiKey) throw new OpenRouterError("OpenRouter API key is not configured.", { code: "NO_API_KEY" });
    if (!model) throw new OpenRouterError("No OpenRouter model selected.", { code: "NO_MODEL" });

    let attempt = 0;
    const effectiveMaxRetries = Math.max(0, Math.min(10, Number(maxRetries)));

    while (attempt <= effectiveMaxRetries) {
      attempt += 1;
      let hasReceivedContent = false;
      let fullText = "";
      const toolCalls = new Map();

      try {
        const response = await this.customFetch(`${this.endpoint}/chat/completions`, {
          method: "POST",
          headers: this.headers(),
          body: JSON.stringify({
            model,
            messages,
            temperature: Number(temperature) || 0.7,
            stream: true,
            ...(tools.length ? { tools, tool_choice: toolChoice || "auto" } : {}),
          }),
          signal,
        });

        if (!response.ok) {
          const detail = await response.text().catch(() => "");
          const retryHeader = response.headers?.get?.("retry-after") || response.headers?.get?.("x-ratelimit-reset");
          const retryAfterMs = parseRetryAfter(retryHeader);
          const isRateLimit = response.status === 429;
          const isAuth = response.status === 401 || response.status === 403;

          const error = new OpenRouterError(
            `OpenRouter returned HTTP ${response.status}${detail ? `: ${detail.slice(0, 240)}` : ""}`,
            {
              status: response.status,
              isRateLimit,
              isAuthError: isAuth,
              isUnavailable: [404, 502, 503, 504].includes(response.status),
              retryAfterMs,
            }
          );

          if (isAuth || !isRetryableStatus(response.status) || attempt > effectiveMaxRetries) {
            throw error;
          }

          const baseDelay = Math.min(maxBackoffMs, this.initialBackoffMs * Math.pow(2, attempt - 1));
          const jitter = Math.floor(Math.random() * 300);
          const delayMs = retryAfterMs ? Math.min(maxBackoffMs, Math.max(retryAfterMs, baseDelay)) : baseDelay + jitter;

          if (onRetry) {
            onRetry({
              attempt,
              maxRetries: effectiveMaxRetries,
              delayMs,
              status: response.status,
              statusText: response.statusText || "",
              error: error.message,
              isRateLimit,
            });
          }

          await this._sleep(delayMs, signal);
          continue;
        }

        const consume = (line) => {
          const value = line.trim();
          if (!value || !value.startsWith("data:")) return false;
          const payload = value.slice(5).trim();
          if (payload === "[DONE]") return true;
          let parsed;
          try {
            parsed = JSON.parse(payload);
          } catch {
            return false;
          }

          const chunk = parsed.choices?.[0]?.delta?.content || "";
          if (chunk) {
            hasReceivedContent = true;
            fullText += chunk;
            onChunk?.(chunk);
          }

          for (const call of parsed.choices?.[0]?.delta?.tool_calls || []) {
            hasReceivedContent = true;
            const current = toolCalls.get(call.index) || {
              id: call.id || `call_${call.index}`,
              type: "function",
              function: { name: "", arguments: "" },
            };
            if (call.id) current.id = call.id;
            if (call.function?.name) current.function.name += call.function.name;
            if (call.function?.arguments) current.function.arguments += call.function.arguments;
            toolCalls.set(call.index, current);
          }
          return false;
        };

        const reader = response.body?.getReader?.();
        if (!reader) throw new OpenRouterError("OpenRouter returned no streaming body.", { code: "NO_STREAM_BODY" });
        const decoder = new TextDecoder();
        let buffer = "";

        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split(/\r?\n/);
            buffer = lines.pop() || "";
            for (const line of lines) {
              if (consume(line)) {
                await reader.cancel().catch(() => {});
                return { fullText, toolCalls: [...toolCalls.values()] };
              }
            }
          }
          if (buffer) consume(buffer);
        } catch (streamError) {
          if (signal?.aborted || streamError.name === "AbortError") {
            throw new OpenRouterError("OpenRouter generation cancelled by user.", { code: "CANCELLED" });
          }
          if (hasReceivedContent) {
            throw new OpenRouterError(
              `OpenRouter stream interrupted: ${streamError.message}`,
              {
                isPartial: true,
                partialText: fullText,
                partialToolCalls: [...toolCalls.values()],
              }
            );
          }
          throw streamError;
        }

        return { fullText, toolCalls: [...toolCalls.values()] };

      } catch (err) {
        if (signal?.aborted || err.name === "AbortError" || err.code === "CANCELLED") {
          throw new OpenRouterError("OpenRouter generation cancelled by user.", { code: "CANCELLED" });
        }
        if (err instanceof OpenRouterError) {
          if (err.isPartial || err.isAuthError || attempt > effectiveMaxRetries || !isRetryableStatus(err.status)) {
            throw err;
          }
        }
        if (!hasReceivedContent && attempt <= effectiveMaxRetries) {
          const baseDelay = Math.min(maxBackoffMs, this.initialBackoffMs * Math.pow(2, attempt - 1));
          const delayMs = baseDelay + Math.floor(Math.random() * 300);

          if (onRetry) {
            onRetry({
              attempt,
              maxRetries: effectiveMaxRetries,
              delayMs,
              status: null,
              error: err.message,
              isRateLimit: false,
            });
          }
          await this._sleep(delayMs, signal);
          continue;
        }

        throw err;
      }
    }
  }

  _sleep(ms, signal) {
    return new Promise((resolve, reject) => {
      if (signal?.aborted) {
        return reject(new OpenRouterError("OpenRouter generation cancelled by user.", { code: "CANCELLED" }));
      }
      const timer = setTimeout(() => {
        if (signal) signal.removeEventListener("abort", onAbort);
        resolve();
      }, ms);

      const onAbort = () => {
        clearTimeout(timer);
        reject(new OpenRouterError("OpenRouter generation cancelled by user.", { code: "CANCELLED" }));
      };

      if (signal) {
        signal.addEventListener("abort", onAbort, { once: true });
      }
    });
  }
}

function defaultOpenRouterSettings() {
  return {
    enabled: true,
    endpoint: DEFAULT_ENDPOINT,
    selectedModel: DEFAULT_MODEL,
    temperature: 0.7,
    useMemory: true,
    maxRetries: 3,
    maxBackoffSeconds: 30,
  };
}

function loadOpenRouterSettings(dataDir) {
  const filePath = path.join(dataDir, "openrouter-settings.json");
  try {
    if (fs.existsSync(filePath)) {
      const parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
      return { ...defaultOpenRouterSettings(), ...parsed };
    }
  } catch (error) {
    console.error("Failed to load openrouter-settings.json:", error.message);
  }
  return defaultOpenRouterSettings();
}

function saveOpenRouterSettings(dataDir, settings = {}) {
  fs.mkdirSync(dataDir, { recursive: true, mode: 0o700 });
  const current = loadOpenRouterSettings(dataDir);
  const updated = { ...current, ...settings };
  delete updated.apiKey;
  delete updated.token;
  delete updated.secret;

  if (updated.maxRetries !== undefined) updated.maxRetries = Math.max(0, Math.min(10, Number(updated.maxRetries) || 0));
  if (updated.maxBackoffSeconds !== undefined) updated.maxBackoffSeconds = Math.max(5, Math.min(120, Number(updated.maxBackoffSeconds) || 30));

  fs.writeFileSync(path.join(dataDir, "openrouter-settings.json"), JSON.stringify(updated, null, 2), { mode: 0o600 });
  return updated;
}

module.exports = {
  OpenRouterClient,
  OpenRouterError,
  parseRetryAfter,
  DEFAULT_MODEL,
  DEFAULT_ENDPOINT,
  defaultOpenRouterSettings,
  loadOpenRouterSettings,
  saveOpenRouterSettings,
};
