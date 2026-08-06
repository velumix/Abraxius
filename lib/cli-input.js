const fs = require("fs");
const path = require("path");

function readUtf8File(filePath, label = "input") {
  if (!filePath) throw new Error(`Missing path after --${label}-file`);
  const resolved = path.resolve(filePath);
  try {
    return { text: stripBom(fs.readFileSync(resolved, "utf8")), source: resolved };
  } catch (error) {
    throw new Error(`Could not read ${label} file ${resolved}: ${error.message}`);
  }
}

async function readStdin(stream = process.stdin) {
  if (stream.isTTY) {
    throw new Error("Standard input is interactive. Pipe content to this command or use a file option.");
  }
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return stripBom(Buffer.concat(chunks).toString("utf8"));
}

function stripBom(value) {
  return value.charCodeAt(0) === 0xfeff ? value.slice(1) : value;
}

function parseInputOptions(argv, kind) {
  const remaining = [];
  let file;
  let stdin = false;
  let inline;
  let literal = false;

  for (let index = 0; index < argv.length; index++) {
    const argument = argv[index];
    if (literal) {
      remaining.push(argument);
    } else if (argument === "--") {
      literal = true;
    } else if (argument === `--${kind}-file` || (kind === "text" && argument === "--file")) {
      file = argv[++index];
      if (!file) throw new Error(`Missing path after ${argument}`);
    } else if (argument === `--${kind}-stdin` || (kind === "text" && argument === "--stdin")) {
      stdin = true;
    } else if (argument === `--${kind}`) {
      inline = argv[++index];
      if (inline === undefined) throw new Error(`Missing value after ${argument}`);
    } else {
      remaining.push(argument);
    }
  }

  const selected = Number(file !== undefined) + Number(stdin) + Number(inline !== undefined);
  if (selected > 1) {
    throw new Error(`Choose only one --${kind}-file, --${kind}-stdin, or --${kind} input source.`);
  }
  return { file, stdin, inline, remaining };
}

async function readJsonArgument(argv, options = {}) {
  const parsed = parseInputOptions(argv, "json");
  let input;
  let source;

  if (parsed.file !== undefined) {
    ({ text: input, source } = readUtf8File(parsed.file, "json"));
  } else if (parsed.stdin) {
    input = await readStdin(options.stdin);
    source = "standard input";
  } else if (parsed.inline !== undefined) {
    input = parsed.inline;
    source = "--json";
  } else {
    input = parsed.remaining.shift() ?? "{}";
    source = "command line";
  }

  if (parsed.remaining.length > 0) {
    throw new Error(
      `Unexpected arguments after JSON input: ${parsed.remaining.join(" ")}. ` +
      "Use --json-file or --json-stdin when the shell may split the payload.",
    );
  }

  try {
    return JSON.parse(input);
  } catch (error) {
    throw new Error(
      `Invalid JSON from ${source}: ${error.message}. ` +
      "PowerShell users should prefer --json-file or --json-stdin.",
    );
  }
}

async function readJsonObjectArgument(argv, options = {}) {
  const value = await readJsonArgument(argv, options);
  if (value === null || Array.isArray(value) || typeof value !== "object") {
    throw new Error("JSON command arguments must be an object at the top level.");
  }
  return value;
}

async function readTextArgument(argv, options = {}) {
  const parsed = parseInputOptions(argv, "text");
  let value;
  if (parsed.file !== undefined) {
    value = readUtf8File(parsed.file, "text").text;
  } else if (parsed.stdin) {
    value = await readStdin(options.stdin);
  } else if (parsed.inline !== undefined) {
    value = parsed.inline;
  } else {
    value = parsed.remaining.join(" ");
  }
  if (!value) {
    throw new Error("Input is empty. Pass text inline, with --file, or through --stdin.");
  }
  return value;
}

module.exports = {
  parseInputOptions,
  readJsonArgument,
  readJsonObjectArgument,
  readStdin,
  readTextArgument,
  readUtf8File,
};
