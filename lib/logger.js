const fs = require("fs");
const path = require("path");

const ANSI = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  dim: "\x1b[2m",
  underscore: "\x1b[4m",
  blink: "\x1b[5m",
  black: "\x1b[30m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
  white: "\x1b[37m",
  bgBlack: "\x1b[40m",
  bgRed: "\x1b[41m",
  bgGreen: "\x1b[42m",
  bgYellow: "\x1b[43m",
  bgBlue: "\x1b[44m",
  bgMagenta: "\x1b[45m",
  bgCyan: "\x1b[46m",
  bgWhite: "\x1b[47m",
};

function colorize(text, color) {
  return `${ANSI[color] || ""}${text}${ANSI.reset}`;
}

function timestamp() {
  const now = new Date();
  return now.toLocaleTimeString("en-US", { hour12: false }) + "." + String(now.getMilliseconds()).padStart(3, "0");
}

function prefix(level, icon) {
  const t = colorize(timestamp(), "dim");
  const tag = colorize(`[ABRAXIUS]`, "cyan");
  const lvl = colorize(level, "bright");
  return `${t} ${icon} ${tag} ${lvl}`;
}

function info(message) {
  console.log(`${prefix("INFO", "🔷")} ${message}`);
}

function success(message) {
  console.log(`${prefix("OK", "🟢")} ${colorize(message, "green")}`);
}

function warn(message) {
  console.log(`${prefix("WARN", "🟡")} ${colorize(message, "yellow")}`);
}

function error(message) {
  console.log(`${prefix("ERROR", "🔴")} ${colorize(message, "red")}`);
}

function http(method, route) {
  const methodColor = method === "GET" ? "green" : method === "POST" ? "magenta" : "yellow";
  console.log(`${prefix("HTTP", "🌐")} ${colorize(method, methodColor)} ${colorize(route, "cyan")}`);
}

function cli(command, detail = "") {
  console.log(`${prefix("CLI", "⌨️ ")} ${colorize(command, "bright")}${detail ? " " + colorize(detail, "dim") : ""}`);
}

function studio(message) {
  console.log(`${prefix("STUDIO", "🎮")} ${colorize(message, "magenta")}`);
}

function matrixBanner() {
  const lines = [
    "  ███   ████   ████    ███   █   █  █████  █   █   ████",
    " █   █  █   █  █   █  █   █  █   █    █    █   █  █    ",
    " █████  ████   ████   █████   ███     █    █   █   ███ ",
    " █   █  █   █  █  █   █   █  █   █    █    █   █      █",
    " █   █  ████   █   █  █   █  █   █  █████   ███   ████ ",
    "",
    "        🌊  Roblox Studio bridge + sync daemon  🌊",
  ];
  console.log("");
  for (const line of lines) {
    console.log("  " + colorize(line, "green"));
  }
  console.log("");
}

function pacmanBanner() {
  const lines = [
    "   ╔═══════════════════════════════════════════════════════╗",
    "   ║  • • • • • • • • • • • • • • • • • • • • • • • • •   ║",
    "   ║                                                       ║",
    "   ║     ABRAXIUS    C  [◉‿◉]  [====>                    ║",
    "   ║                                                       ║",
    "   ║  • • • • • • • • • • • • • • • • • • • • • • • • •   ║",
    "   ╚═══════════════════════════════════════════════════════╝",
    "",
    "        👾  Roblox Studio bridge + sync daemon  👾",
  ];
  console.log("");
  for (const line of lines) {
    console.log(colorize(line, "yellow"));
  }
  console.log("");
}

function startupBanner(style = "matrix") {
  if (style === "pacman") {
    pacmanBanner();
  } else {
    matrixBanner();
  }
}

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
