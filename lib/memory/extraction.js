const {
  detectSecrets,
  createMemoryRecord,
  MEMORY_TYPES,
  MEMORY_SCOPES,
} = require("./model");
const { computeKeywordSimilarity } = require("./embeddings");

const EXTRACTION_SYSTEM_PROMPT = `You are the Abraxius Memory Core Extraction Engine.
Your task is to analyze the conversation / task transcript and extract ANY durable long-term memories.

Durable memory categories:
- preference (user styling/workflow choices)
- project_fact (confirmed project architecture or environment facts)
- requirement (explicit project/feature requirements)
- technical_decision (architectural or tech stack decisions made)
- known_issue (recurrent bugs or limitations discovered)
- failed_attempt (approaches that failed and why)
- successful_fix (solutions that fixed a specific issue)
- procedure (steps for build, deploy, or maintenance)
- pending_task (explicit follow-up work needed)

STRICT RULES:
1. DO NOT extract casual conversation, pleasantries, temporary wording, code snippets, speculation, or chain of thought.
2. DO NOT extract API keys, tokens, passwords, secrets, or credential strings.
3. Keep summary under 100 characters. Keep content concise (1-3 sentences).
4. Return ONLY a valid JSON array of objects. Do not include markdown code block syntax or extra text outside JSON.

JSON Schema per item:
[
  {
    "scope": "global" | "project" | "agent" | "session" | "private",
    "type": "preference" | "project_fact" | "requirement" | "technical_decision" | "known_issue" | "failed_attempt" | "successful_fix" | "procedure" | "pending_task" | "custom",
    "summary": "Short 1-line summary",
    "content": "Detailed description of memory fact",
    "tags": ["tag1", "tag2"],
    "confidence": 0.8
  }
]`;

class MemoryExtractionEngine {
  constructor(options = {}) {
    this.store = options.store;
    this.provider = options.provider || null; // LLM provider wrapper
    this.autoApprove = options.autoApprove || false;
  }

  /**
   * Processes a task transcript or message history to extract durable memories.
   */
  async extractFromTranscript(transcriptText, scopeContext = {}) {
    if (!this.store || typeof transcriptText !== "string" || !transcriptText.trim()) {
      return { extracted: [], added: [], proposed: [] };
    }

    // Secret Guard on transcript input (don't fail, but log warning if present)
    const rawCheck = detectSecrets(transcriptText);

    let rawOutput = "";
    if (this.provider && typeof this.provider.complete === "function") {
      try {
        rawOutput = await this.provider.complete({
          system: EXTRACTION_SYSTEM_PROMPT,
          prompt: `Extract durable memories from this transcript:\n\n${transcriptText.slice(0, 8000)}`,
        });
      } catch (err) {
        console.error("[MemoryExtractionEngine] Provider completion failed:", err.message);
        return { extracted: [], added: [], proposed: [], error: err.message };
      }
    } else {
      // Fallback simple rule-based / regex extraction if LLM provider not connected
      rawOutput = this.ruleBasedExtraction(transcriptText);
    }

    const items = this.parseAndValidateJson(rawOutput);
    const results = { extracted: items, added: [], proposed: [] };

    for (const item of items) {
      // Check for secrets in extracted output
      const secCheck = detectSecrets(`${item.summary} ${item.content}`);
      if (secCheck.detected) {
        console.warn(`[MemoryExtractionEngine] Secret detected in extracted memory (${secCheck.patternName}). Dropping record.`);
        continue;
      }

      // Check deduplication against existing store
      const existingRecords = this.store.listRecords({
        projectId: scopeContext.projectId,
      });

      let isDuplicate = false;
      let conflictRecord = null;

      for (const rec of existingRecords) {
        const sim = computeKeywordSimilarity(item.content, rec.content);
        if (sim > 0.85) {
          isDuplicate = true;
          break;
        } else if (sim > 0.5 && item.type === rec.type) {
          conflictRecord = rec;
        }
      }

      if (isDuplicate) {
        continue;
      }

      // Determine verification status
      let verificationStatus = "proposed";
      if (this.autoApprove && item.confidence >= 0.8 && !conflictRecord) {
        verificationStatus = "verified";
      } else if (conflictRecord) {
        verificationStatus = "disputed";
      }

      const scope = MEMORY_SCOPES.includes(item.scope) ? item.scope : "project";
      const type = MEMORY_TYPES.includes(item.type) ? item.type : "project_fact";

      try {
        const record = this.store.addRecord({
          scope,
          projectId: scopeContext.projectId || null,
          agentId: scopeContext.agentId || null,
          sessionId: scopeContext.sessionId || null,
          type,
          content: item.content,
          summary: item.summary,
          tags: item.tags || [],
          sourceType: "llm_extraction",
          confidence: typeof item.confidence === "number" ? item.confidence : 0.75,
          verificationStatus,
          sensitivity: scope === "private" ? "private" : "normal",
        });

        if (verificationStatus === "verified") {
          results.added.push(record);
        } else {
          results.proposed.push(record);
        }
      } catch (err) {
        console.warn("[MemoryExtractionEngine] Record creation skipped:", err.message);
      }
    }

    return results;
  }

  /**
   * Rule-based extraction fallback for when no LLM provider is active.
   */
  ruleBasedExtraction(text) {
    const extracted = [];
    const lines = text.split("\n");
    for (const line of lines) {
      const trimmed = line.trim();
      if (/(?:^|\b)(?:decision|architecture):/i.test(trimmed)) {
        extracted.push({
          scope: "project",
          type: "technical_decision",
          summary: trimmed.slice(0, 80),
          content: trimmed,
          tags: ["decision"],
          confidence: 0.8,
        });
      } else if (/(?:^|\b)(?:fix|fixed|solution):/i.test(trimmed)) {
        extracted.push({
          scope: "project",
          type: "successful_fix",
          summary: trimmed.slice(0, 80),
          content: trimmed,
          tags: ["fix"],
          confidence: 0.8,
        });
      } else if (/(?:^|\b)(?:failed|error|bug):/i.test(trimmed)) {
        extracted.push({
          scope: "project",
          type: "failed_attempt",
          summary: trimmed.slice(0, 80),
          content: trimmed,
          tags: ["bug"],
          confidence: 0.7,
        });
      }
    }
    return JSON.stringify(extracted);
  }

  parseAndValidateJson(raw) {
    if (!raw) return [];
    try {
      let cleaned = raw.trim();
      if (cleaned.startsWith("```")) {
        cleaned = cleaned.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
      }
      const parsed = JSON.parse(cleaned);
      if (!Array.isArray(parsed)) return [];

      return parsed.filter((item) => {
        return item && typeof item === "object" && typeof item.content === "string" && item.content.trim().length > 0;
      });
    } catch {
      return [];
    }
  }

  // Review Queue Management
  getProposed(projectId = null) {
    if (!this.store) return [];
    return this.store.listRecords({
      projectId,
      verificationStatus: "proposed",
    });
  }

  approveProposed(id) {
    if (!this.store) throw new Error("Store unavailable");
    return this.store.updateRecord(id, { verificationStatus: "verified" });
  }

  rejectProposed(id, options = { confirm: true }) {
    if (!this.store) throw new Error("Store unavailable");
    return this.store.forgetRecord(id, options);
  }

  correctProposed(id, newContent, newSummary, reason) {
    if (!this.store) throw new Error("Store unavailable");
    const { oldRecord, newRecord } = this.store.supersedeRecord(id, {
      content: newContent,
      summary: newSummary || newContent.slice(0, 100),
      verificationStatus: "verified",
      metadata: { correctionReason: reason || "User correction" },
    });
    return { oldRecord, newRecord };
  }
}

module.exports = {
  MemoryExtractionEngine,
  EXTRACTION_SYSTEM_PROMPT,
};
