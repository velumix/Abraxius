const emoji = (...points) => String.fromCodePoint(...points);

const LEVELS = {
  info: { icon: emoji(0x2139, 0xfe0f) },
  ok: { icon: emoji(0x2728) },
  warn: { icon: emoji(0x26a0, 0xfe0f) },
  error: { icon: emoji(0x274c) },
  http: { icon: emoji(0x1f310) },
  cli: { icon: emoji(0x2328, 0xfe0f) },
  studio: { icon: emoji(0x1f3ae) },
  plugin: { icon: emoji(0x1f50c) },
  connect: { icon: emoji(0x2705) },
  disconnect: { icon: emoji(0x1f504) },
};

function format(level, message) {
  const clean = String(message).replace(/[\r\n]+/g, " ");
  if (/^[^\x00-\x7f]/u.test(clean)) return clean;
  const cfg = LEVELS[level] || LEVELS.info;
  return `${cfg.icon} ${clean}`;
}

module.exports = { format, LEVELS };
