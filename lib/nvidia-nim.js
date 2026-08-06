"use strict";

const DEFAULT_ENDPOINT = "https://integrate.api.nvidia.com/v1";
const DEFAULT_MODEL = "nvidia/nemotron-3-super-120b-a12b";

class NvidiaNimError extends Error {
  constructor(message, options = {}) {
    super(message);
    this.name = "NvidiaNimError";
    this.status = options.status || null;
    this.code = options.code || "NVIDIA_NIM_ERROR";
  }
}

function numberOr(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

class NvidiaNimClient {
  constructor(options = {}) {
    this.endpoint = (options.endpoint || DEFAULT_ENDPOINT).replace(/\/+$/, "");
    this.apiKey = options.apiKey || "";
    this.model = options.model || DEFAULT_MODEL;
    this.temperature = numberOr(options.temperature, 1);
    this.topP = numberOr(options.topP, 0.95);
    this.maxTokens = Math.max(1, Math.floor(numberOr(options.maxTokens, 16384)));
    this.reasoningBudget = Math.max(0, Math.floor(numberOr(options.reasoningBudget, 16384)));
    this.customFetch = options.fetch || globalThis.fetch;
  }

  headers() {
    return {
      "Content-Type": "application/json",
      Authorization: `Bearer ${this.apiKey}`,
    };
  }

  async streamChat(options = {}) {
    const model = options.model || this.model;
    const messages = Array.isArray(options.messages) ? options.messages : [];
    const signal = options.signal;
    if (!this.apiKey) throw new NvidiaNimError("NVIDIA NIM API key is not configured.", { code: "NO_API_KEY" });
    if (!model) throw new NvidiaNimError("No NVIDIA NIM model selected.", { code: "NO_MODEL" });

    const response = await this.customFetch(`${this.endpoint}/chat/completions`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        model,
        messages,
        temperature: numberOr(options.temperature, this.temperature),
        top_p: numberOr(options.topP, this.topP),
        max_tokens: Math.max(1, Math.floor(numberOr(options.maxTokens, this.maxTokens))),
        chat_template_kwargs: { enable_thinking: options.enableThinking !== false },
        reasoning_budget: Math.max(0, Math.floor(numberOr(options.reasoningBudget, this.reasoningBudget))),
        stream: true,
      }),
      signal,
    });

    if (!response.ok) {
      const detail = await response.text().catch(() => "");
      throw new NvidiaNimError(
        `NVIDIA NIM returned HTTP ${response.status}${detail ? `: ${detail.slice(0, 240)}` : ""}`,
        { status: response.status, code: response.status === 401 || response.status === 403 ? "AUTH_ERROR" : "HTTP_ERROR" },
      );
    }

    const reader = response.body?.getReader?.();
    if (!reader) throw new NvidiaNimError("NVIDIA NIM returned no streaming body.", { code: "NO_STREAM_BODY" });

    const decoder = new TextDecoder();
    const reasoning = [];
    const content = [];
    let buffer = "";
    const consume = (line) => {
      const value = line.trim();
      if (!value || !value.startsWith("data:")) return false;
      const payload = value.slice(5).trim();
      if (payload === "[DONE]") return true;
      let parsed;
      try { parsed = JSON.parse(payload); } catch { return false; }
      const delta = parsed.choices?.[0]?.delta || {};
      const reasoningChunk = delta.reasoning_content || "";
      const contentChunk = delta.content || "";
      if (reasoningChunk) {
        reasoning.push(reasoningChunk);
        options.onReasoning?.(reasoningChunk);
      }
      if (contentChunk) {
        content.push(contentChunk);
        options.onChunk?.(contentChunk);
      }
      return false;
    };

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
            return { reasoning: reasoning.join(""), fullText: content.join("") };
          }
        }
      }
      if (buffer) consume(buffer);
    } catch (error) {
      if (signal?.aborted || error.name === "AbortError") {
        throw new NvidiaNimError("NVIDIA NIM generation cancelled by user.", { code: "CANCELLED" });
      }
      throw error;
    }

    return { reasoning: reasoning.join(""), fullText: content.join("") };
  }
}

module.exports = { NvidiaNimClient, NvidiaNimError, DEFAULT_ENDPOINT, DEFAULT_MODEL };
