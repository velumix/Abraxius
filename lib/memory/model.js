const crypto = require("crypto");

/**
 * Valid memory scopes
 */
const MEMORY_SCOPES = Object.freeze([
  "global",
  "project",
  "agent",
  "session",
  "private",
]);

/**
 * Valid memory types
 */
const MEMORY_TYPES = Object.freeze([
  "preference",
  "project_fact",
  "requirement",
  "technical_decision",
  "known_issue",
  "failed_attempt",
  "successful_fix",
  "procedure",
  "person",
  "organization",
  "pending_task",
  "summary",
  "custom",
]);

/**
 * Verification statuses
 */
const VERIFICATION_STATUSES = Object.freeze([
  "proposed",
  "verified",
  "disputed",
  "superseded",
]);

/**
 * Sensitivity levels
 */
const SENSITIVITY_LEVELS = Object.freeze([
  "normal",
  "private",
  "secret-rejected",
]);

/**
 * Source types
 */
const SOURCE_TYPES = Object.freeze([
  "user",
  "agent",
  "llm_extraction",
  "document_index",
  "mcp",
]);

/**
 * Secret Detection Patterns
 */
const SECRET_PATTERNS = [
  { name: "API Key (Generic/OpenAI/Anthropic)", regex: /(?:sk-[a-zA-Z0-9]{20,}|sk-proj-[a-zA-Z0-9_-]{20,}|xai-[a-zA-Z0-9]{20,})/i },
  { name: "GitHub Token", regex: /(?:ghp_[a-zA-Z0-9]{30,}|gho_[a-zA-Z0-9]{30,}|ghu_[a-zA-Z0-9]{30,}|ghs_[a-zA-Z0-9]{30,}|ghr_[a-zA-Z0-9]{30,})/i },
  { name: "GitLab Token", regex: /glpat-[a-zA-Z0-9_-]{20,}/i },
  { name: "Bearer Token", regex: /Bearer\s+[a-zA-Z0-9._-]{25,}/i },
  { name: "Slack Token", regex: /xox[baprs]-[a-zA-Z0-9]{10,}/i },
  { name: "AWS Key ID", regex: /(?:AKIA|ASIA)[0-9A-Z]{16}/ },
  { name: "Private Key", regex: /-----BEGIN\s+(?:RSA|DSA|EC|OPENSSH|PGP)?\s*PRIVATE\s+KEY-----/i },
  { name: "Database Connection String", regex: /(?:mongodb(?:\+srv)?|postgres|postgresql|mysql|redis):\/\/[^:\s]+:[^@\s]+@[^\s]+/i },
  { name: "Password Assignment", regex: /(?:password|passwd|pwd|secret)\s*[:=]\s*["']?[^\s"';]{8,}["']?/i },
  { name: "Auth Cookie / Session Token", regex: /(?:connect\.sid|session_id|jwt|auth_token)\s*=\s*[a-zA-Z0-9._-]{20,}/i },
  { name: "Secret Environment Variable", regex: /(?:[A-Z0-9_]*(?:SECRET|PASSWORD|API_KEY|PRIVATE_KEY)[A-Z0-9_]*)\s*=\s*["']?[^\s"']{8,}["']?/ },
];

/**
 * Checks text for secret patterns.
 * Returns { detected: boolean, patternName?: string }
 */
function detectSecrets(text) {
  if (typeof text !== "string" || !text) {
    return { detected: false };
  }
  for (const pattern of SECRET_PATTERNS) {
    if (pattern.regex.test(text)) {
      return { detected: true, patternName: pattern.name };
    }
  }
  return { detected: false };
}

/**
 * Creates a unique UUID v4 string.
 */
function generateUuid() {
  return crypto.randomUUID
    ? crypto.randomUUID()
    : `${Date.now().toString(36)}-${crypto.randomBytes(8).toString("hex")}`;
}

/**
 * Sanitizes and validates a record input object.
 * Throws an error if secret detected or invalid fields provided.
 */
function createMemoryRecord(input = {}) {
  const content = String(input.content || "").trim();
  if (!content) {
    throw new Error("Memory content is required and cannot be empty.");
  }

  // Secret Detection Guard - Reject secrets immediately without logging content!
  const secretCheck = detectSecrets(content);
  if (secretCheck.detected) {
    throw new Error(`Secret detected (${secretCheck.patternName}). Record rejected to prevent credential exposure.`);
  }

  const summaryCheck = detectSecrets(input.summary || "");
  if (summaryCheck.detected) {
    throw new Error(`Secret detected in summary (${summaryCheck.patternName}). Record rejected.`);
  }

  const scope = MEMORY_SCOPES.includes(input.scope) ? input.scope : "project";
  const type = MEMORY_TYPES.includes(input.type) ? input.type : "project_fact";
  const verificationStatus = VERIFICATION_STATUSES.includes(input.verificationStatus)
    ? input.verificationStatus
    : "verified";
  const sensitivity = SENSITIVITY_LEVELS.includes(input.sensitivity)
    ? input.sensitivity
    : scope === "private" ? "private" : "normal";
  const sourceType = SOURCE_TYPES.includes(input.sourceType)
    ? input.sourceType
    : "user";

  const now = Date.now();

  const record = {
    id: input.id || generateUuid(),
    scope,
    projectId: input.projectId ? String(input.projectId) : null,
    agentId: input.agentId ? String(input.agentId) : null,
    sessionId: input.sessionId ? String(input.sessionId) : null,
    type,
    content,
    summary: String(input.summary || content.slice(0, 120)).trim(),
    tags: Array.isArray(input.tags) ? input.tags.map((t) => String(t).trim().toLowerCase()).filter(Boolean) : [],
    sourceType,
    sourceReference: input.sourceReference ? String(input.sourceReference) : null,
    confidence: typeof input.confidence === "number" ? Math.max(0, Math.min(1, input.confidence)) : 1.0,
    verificationStatus,
    sensitivity,
    createdAt: input.createdAt || now,
    updatedAt: input.updatedAt || now,
    accessedAt: input.accessedAt || now,
    accessCount: typeof input.accessCount === "number" ? input.accessCount : 0,
    expiresAt: typeof input.expiresAt === "number" ? input.expiresAt : null,
    supersedesId: input.supersedesId ? String(input.supersedesId) : null,
    embeddingStatus: input.embeddingStatus || "none",
    embedding: Array.isArray(input.embedding) ? input.embedding : null,
    metadata: input.metadata && typeof input.metadata === "object" ? input.metadata : {},
  };

  return record;
}

/**
 * Sanitizes untrusted memory text before returning in prompts to prevent instruction override.
 */
function sanitizeMemoryForContext(text) {
  if (typeof text !== "string") return "";
  // Escape potential prompt injection delimiters or system prompt overrides
  return text
    .replace(/<system>/gi, "[system]")
    .replace(/<\/system>/gi, "[/system]")
    .replace(/<abraxius_memory>/gi, "[abraxius_memory]")
    .replace(/<\/abraxius_memory>/gi, "[/abraxius_memory]");
}

module.exports = {
  MEMORY_SCOPES,
  MEMORY_TYPES,
  VERIFICATION_STATUSES,
  SENSITIVITY_LEVELS,
  SOURCE_TYPES,
  detectSecrets,
  createMemoryRecord,
  generateUuid,
  sanitizeMemoryForContext,
};
