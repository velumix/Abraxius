const AXL_VERSION = "axl/1";
const MAX_COMMAND_CHARS = 256 * 1024;
const MAX_BUDGET = 32_000;

class AxlError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = "AxlError";
    this.code = code;
    this.details = details;
  }
}

function fail(code, message, details) {
  throw new AxlError(code, message, details);
}

function tokenize(line) {
  const tokens = [];
  let token = "";
  let quote = null;
  let active = false;

  for (let index = 0; index < line.length; index++) {
    const character = line[index];
    if (quote) {
      if (character === "\\") {
        const next = line[++index];
        if (next === undefined) fail("SYNTAX", "Trailing escape in quoted text");
        token += { n: "\n", r: "\r", t: "\t" }[next] ?? next;
      } else if (character === quote) {
        quote = null;
      } else {
        token += character;
      }
      active = true;
    } else if (character === '"' || character === "'") {
      quote = character;
      active = true;
    } else if (/\s/.test(character)) {
      if (active) {
        tokens.push(token);
        token = "";
        active = false;
      }
    } else {
      token += character;
      active = true;
    }
  }

  if (quote) fail("SYNTAX", "Unterminated quoted text");
  if (active) tokens.push(token);
  return tokens;
}

function parseOptions(tokens, allowed) {
  const options = {};
  const positional = [];
  for (const token of tokens) {
    const match = /^([A-Za-z][\w-]*)=(.*)$/.exec(token);
    if (!match) {
      positional.push(token);
      continue;
    }
    const [, key, value] = match;
    if (!allowed.has(key)) fail("OPTION", `Unknown option: ${key}`);
    if (Object.hasOwn(options, key)) fail("OPTION", `Duplicate option: ${key}`);
    options[key] = value;
  }
  return { options, positional };
}

function parseInteger(value, name, { minimum = 0, maximum = Number.MAX_SAFE_INTEGER } = {}) {
  if (!/^\d+$/.test(String(value ?? ""))) fail("VALUE", `${name} must be an integer`);
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < minimum || number > maximum) {
    fail("VALUE", `${name} must be between ${minimum} and ${maximum}`);
  }
  return number;
}

function parseTarget(value, { revisionAllowed = true } = {}) {
  if (!value || /\s/.test(value)) fail("TARGET", "Target is required and cannot contain whitespace");

  let raw = value;
  let namespaceVersion = null;
  const namespaceMatch = /\^(\d+)$/.exec(raw);
  if (namespaceMatch) {
    namespaceVersion = parseInteger(namespaceMatch[1], "namespace version");
    raw = raw.slice(0, namespaceMatch.index);
  }

  let revision = null;
  const revisionMatch = /@(\d+)$/.exec(raw);
  if (revisionAllowed && revisionMatch) {
    revision = parseInteger(revisionMatch[1], "revision");
    raw = raw.slice(0, revisionMatch.index);
  }

  const idMatch = /^([@#$%])(\d+)$/.exec(raw);
  if (idMatch) {
    const kinds = { "@": "instance", "#": "symbol", "$": "context", "%": "operation" };
    return {
      kind: kinds[idMatch[1]],
      id: parseInteger(idMatch[2], "target id"),
      revision,
      namespaceVersion,
      raw: value,
    };
  }

  if (raw.length > 1024 || !/^(?:game\.)?[A-Za-z_][\w]*(?:\.[^.\r\n]+)*$/.test(raw)) {
    fail("TARGET", `Invalid Studio path: ${raw}`);
  }
  return { kind: "path", path: raw, revision, namespaceVersion, raw: value };
}

function parseRange(value) {
  const match = /^(\d+)\.\.(\d+)$/.exec(value || "");
  if (!match) fail("RANGE", "Line range must use start..end");
  const start = parseInteger(match[1], "start line", { minimum: 1 });
  const end = parseInteger(match[2], "end line", { minimum: start });
  return { start, end };
}

function readHeredoc(lines, startIndex, expectedName = null) {
  const header = lines[startIndex]?.trim();
  const match = expectedName
    ? new RegExp(`^${expectedName}\\s+<<([A-Za-z][\\w-]*)$`, "i").exec(header || "")
    : /^<<([A-Za-z][\w-]*)$/.exec(header || "");
  if (!match) {
    fail("HEREDOC", expectedName ? `Expected ${expectedName} <<TAG` : "Expected <<TAG");
  }
  const tag = match[1];
  const body = [];
  let index = startIndex + 1;
  while (index < lines.length && lines[index] !== tag) body.push(lines[index++]);
  if (index >= lines.length) fail("HEREDOC", `Missing closing ${tag}`);
  return { value: body.join("\n"), nextIndex: index + 1 };
}

function parseAxl(input) {
  if (typeof input !== "string") fail("INPUT", "AXL input must be text");
  const normalized = input.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").trim();
  if (!normalized) fail("EMPTY", "AXL command is empty");
  if (normalized.length > MAX_COMMAND_CHARS) fail("LIMIT", "AXL command exceeds 256 KiB");

  const lines = normalized.split("\n");
  const header = tokenize(lines[0].trim());
  const command = (header.shift() || "").toLowerCase();

  switch (command) {
    case "hello": {
      const { options, positional } = parseOptions(header, new Set(["project"]));
      if (positional.length > 1 || (positional[0] && positional[0] !== AXL_VERSION)) {
        fail("VERSION", `Expected HELLO ${AXL_VERSION}`);
      }
      return { type: "hello", version: positional[0] || AXL_VERSION, project: options.project ?? null };
    }
    case "context": {
      const { options, positional } = parseOptions(header, new Set(["budget"]));
      if (positional.length !== 1) fail("SYNTAX", 'Usage: context "task" budget=N');
      const budget = options.budget === undefined
        ? 800
        : parseInteger(options.budget, "budget", { minimum: 64, maximum: MAX_BUDGET });
      return { type: "context", task: positional[0], budget };
    }
    case "find": {
      const { options, positional } = parseOptions(header, new Set(["budget"]));
      if (positional.length !== 1) fail("SYNTAX", 'Usage: find "query" [budget=N]');
      const budget = options.budget === undefined
        ? 800
        : parseInteger(options.budget, "budget", { minimum: 64, maximum: MAX_BUDGET });
      return { type: "find", query: positional[0], budget };
    }
    case "read": {
      if (header.length < 1) fail("SYNTAX", "Usage: read target [summary|symbols|source|full|lines A..B]");
      const target = parseTarget(header.shift());
      if (/^\^\d+$/.test(header[0] || "")) {
        if (target.namespaceVersion !== null) fail("VALUE", "Namespace version was provided twice");
        target.namespaceVersion = parseInteger(header.shift().slice(1), "namespace version");
      }
      const detail = (header.shift() || "source").toLowerCase();
      if (!["summary", "symbols", "source", "full", "lines"].includes(detail)) {
        fail("VALUE", `Unknown read detail: ${detail}`);
      }
      const range = detail === "lines" ? parseRange(header.shift()) : null;
      if (header.length) fail("SYNTAX", "Unexpected tokens after read command");
      return { type: "read", target, detail, range };
    }
    case "patch": {
      if (header.length !== 1) fail("SYNTAX", "Usage: patch target@revision followed by old/new heredocs");
      const target = parseTarget(header[0]);
      if (target.revision === null) fail("REVISION", "Patch requires target@revision");
      const oldBlock = readHeredoc(lines, 1, "old");
      const newBlock = readHeredoc(lines, oldBlock.nextIndex, "new");
      if (newBlock.nextIndex !== lines.length) fail("SYNTAX", "Unexpected text after patch heredocs");
      if (oldBlock.value === newBlock.value) fail("PATCH", "Old and new patch text must differ");
      if (!oldBlock.value) fail("PATCH", "Old patch text cannot be empty");
      return { type: "patch", target, oldText: oldBlock.value, newText: newBlock.value };
    }
    case "execute": {
      const heredocIndex = header.findIndex((token) => /^<<[A-Za-z]/.test(token));
      const optionTokens = heredocIndex >= 0 ? header.filter((_, index) => index !== heredocIndex) : header;
      const { options, positional } = parseOptions(optionTokens, new Set(["mode"]));
      let code;
      if (heredocIndex >= 0) {
        if (positional.length) fail("SYNTAX", "Execute heredoc cannot also contain inline code");
        lines[0] = header[heredocIndex];
        code = readHeredoc(lines, 0).value;
      } else {
        if (positional.length !== 1) fail("SYNTAX", 'Usage: execute "code" [mode=Edit] or execute <<TAG');
        code = positional[0];
      }
      const mode = options.mode || "Edit";
      if (!["Edit", "Client", "Server"].includes(mode)) fail("VALUE", "mode must be Edit, Client, or Server");
      if (!code) fail("VALUE", "Execute code cannot be empty");
      return { type: "execute", code, mode };
    }
    case "state": {
      if (header.length > 1) fail("SYNTAX", "Usage: state [target]");
      return { type: "state", target: header[0] ? parseTarget(header[0], { revisionAllowed: false }) : null };
    }
    case "undo": {
      if (header.length !== 1) fail("SYNTAX", "Usage: undo %operation");
      const target = parseTarget(header[0], { revisionAllowed: false });
      if (target.kind !== "operation") fail("TARGET", "Undo requires an operation ID such as %18");
      return { type: "undo", operation: target };
    }
    default:
      fail("COMMAND", `Unknown AXL command: ${command}`);
  }
}

function deepValue(value, key) {
  if (!value || typeof value !== "object") return undefined;
  if (Object.hasOwn(value, key)) return value[key];
  for (const child of Object.values(value)) {
    const found = deepValue(child, key);
    if (found !== undefined) return found;
  }
  return undefined;
}

async function executePluginAxl(source, client) {
  if (typeof source !== "string" || !source.trim()) fail("EMPTY", "AXL command is empty");
  const result = await client.pluginCall({ type: "axl", source });
  const response = deepValue(result, "response");
  if (typeof response !== "string") {
    fail("RESPONSE", "Companion response did not contain an AXL response");
  }
  return response;
}

function encodeAxlError(error) {
  const message = String(error?.message || error);
  const code = error instanceof AxlError
    ? error.code
    : /ECONNREFUSED|Cannot connect/i.test(message)
      ? "NOHOST"
      : /Studio.*not connected|not connected.*Studio|MCP.*unavailable/i.test(message)
        ? "NOSTUDIO"
        : "INTERNAL";
  const fields = error instanceof AxlError
    ? Object.entries(error.details).map(([key, value]) => `${key}=${value}`)
    : [];
  return `ERR ${code}${fields.length ? ` ${fields.join(" ")}` : ""} ${message}`.trim();
}

module.exports = {
  AXL_VERSION,
  AxlError,
  encodeAxlError,
  executePluginAxl,
  parseAxl,
  tokenize,
};
