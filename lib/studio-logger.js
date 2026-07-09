const LEVELS = {
  info: { icon: "🔷", label: "INFO" },
  ok: { icon: "🟢", label: "OK" },
  warn: { icon: "🟡", label: "WARN" },
  error: { icon: "🔴", label: "ERROR" },
  http: { icon: "🌐", label: "HTTP" },
  cli: { icon: "⌨️", label: "CLI" },
  studio: { icon: "🎮", label: "STUDIO" },
  plugin: { icon: "🔌", label: "PLUGIN" },
  connect: { icon: "✅", label: "CONNECT" },
  disconnect: { icon: "❌", label: "DISCONNECT" },
};

function format(level, message) {
  const cfg = LEVELS[level] || LEVELS.info;
  return `${cfg.icon} ${cfg.label} │ ${message}`;
}

module.exports = { format, LEVELS };