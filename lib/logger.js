const ANSI = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  magenta: "\x1b[35m",
};

const emoji = (...points) => String.fromCodePoint(...points);
const ICONS = {
  info: emoji(0x2139, 0xfe0f),
  ready: emoji(0x2728),
  warn: emoji(0x26a0, 0xfe0f),
  error: emoji(0x274c),
  http: emoji(0x1f310),
  action: emoji(0x2328, 0xfe0f),
  studio: emoji(0x1f3ae),
};

function colorize(text, color) {
  return `${ANSI[color] || ""}${text}${ANSI.reset}`;
}

function timestamp() {
  const now = new Date();
  return now.toLocaleTimeString("en-US", { hour12: false }) + "." +
    String(now.getMilliseconds()).padStart(3, "0");
}

function prefix(icon) {
  return `${colorize(timestamp(), "dim")} ${icon}`;
}

function write(icon, message, color) {
  const clean = String(message).replace(/[\r\n]+/g, " ");
  console.log(`${prefix(icon)} ${colorize(clean, color)}`);
}

function info(message) {
  write(ICONS.info, message);
}

function success(message) {
  write(ICONS.ready, message, "green");
}

function warn(message) {
  write(ICONS.warn, message, "yellow");
}

function error(message) {
  write(ICONS.error, message, "red");
}

function http(method, route) {
  const methodColor = method === "GET" ? "green" : method === "POST" ? "magenta" : "yellow";
  console.log(`${prefix(ICONS.http)} ${colorize(method, methodColor)} ${colorize(route, "cyan")}`);
}

function cli(command, detail = "") {
  const suffix = detail ? ` ${colorize(detail, "dim")}` : "";
  console.log(`${prefix(ICONS.action)} ${colorize(command, "bright")}${suffix}`);
}

function studio(message) {
  write(ICONS.studio, message, "magenta");
}

function startupBanner() {
  console.log("");
  console.log(colorize(`  ${emoji(0x26a1)} ABRAXIUS`, "green"));
  console.log(colorize("  Roblox Studio workspace bridge", "dim"));
  console.log("");
}

const matrixBanner = startupBanner;
const pacmanBanner = startupBanner;

module.exports = {
  ANSI,
  colorize,
  timestamp,
  info,
  success,
  warn,
  error,
  http,
  cli,
  studio,
  matrixBanner,
  pacmanBanner,
  startupBanner,
};
