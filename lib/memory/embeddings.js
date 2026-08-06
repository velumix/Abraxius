/**
 * Abstract Embedding Provider & Hybrid Keyword Fallback Engine
 */

function cosineSimilarity(vecA, vecB) {
  if (!Array.isArray(vecA) || !Array.isArray(vecB) || vecA.length !== vecB.length || vecA.length === 0) {
    return 0;
  }
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

function tokenize(text) {
  if (typeof text !== "string") return [];
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2);
}

function computeKeywordSimilarity(query, text) {
  const queryTokens = tokenize(query);
  const textTokens = tokenize(text);
  if (queryTokens.length === 0 || textTokens.length === 0) return 0;

  const textTokenSet = new Set(textTokens);
  let matches = 0;
  for (const qt of queryTokens) {
    if (textTokenSet.has(qt)) {
      matches++;
    } else {
      // Substring match check
      for (const tt of textTokens) {
        if (tt.includes(qt) || qt.includes(tt)) {
          matches += 0.5;
          break;
        }
      }
    }
  }
  return matches / Math.sqrt(queryTokens.length * textTokens.length);
}

class BaseEmbeddingProvider {
  async getEmbedding(_text) {
    throw new Error("getEmbedding must be implemented by subclass");
  }
}

class OllamaEmbeddingProvider extends BaseEmbeddingProvider {
  constructor(options = {}) {
    super();
    this.host = options.host || "http://127.0.0.1:11434";
    this.model = options.model || "nomic-embed-text";
    this.timeoutMs = options.timeoutMs || 3000;
  }

  async getEmbedding(text) {
    if (typeof text !== "string" || !text.trim()) {
      return null;
    }
    try {
      const url = `${this.host.replace(/\/$/, "")}/api/embeddings`;
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: this.model, prompt: text }),
        signal: AbortSignal.timeout(this.timeoutMs),
      });

      if (!response.ok) {
        return null;
      }

      const data = await response.json();
      if (Array.isArray(data.embedding)) {
        return data.embedding;
      }
      return null;
    } catch {
      // Gracefully fall back to keyword search if Ollama is unreachable/timing out
      return null;
    }
  }
}

class KeywordEmbeddingProvider extends BaseEmbeddingProvider {
  async getEmbedding(_text) {
    return null; // Signals retrieval engine to use keyword fallback
  }
}

module.exports = {
  cosineSimilarity,
  tokenize,
  computeKeywordSimilarity,
  BaseEmbeddingProvider,
  OllamaEmbeddingProvider,
  KeywordEmbeddingProvider,
};
