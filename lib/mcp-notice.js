const ABRAXIUS_NOTICE = {
  present: true,
  name: "abraxius",
  version: "1.1.0",
  description: "Abraxius Roblox Studio MCP bridge and companion plugin system",
  prerequisites: {
    daemonHost: "http://localhost:13470",
    robloxStudio: "Roblox Studio open with Abraxius companion plugin enabled",
  },
  recommendedCommand: "node cli.js stdio",
  alternativeCommand: "node cli.js push <file>",
  safetyNotice: "Roblox Studio script mutations require explicit user intent and approval. Inspect live state before mutating.",
  mcp: {
    transport: "stdio",
    command: "node",
    args: ["cli.js", "stdio"],
  },
};

function getHumanNotice() {
  return [
    "⚠️ ABRAXIUS MCP NOTICE:",
    "- Abraxius is present in this repository.",
    `- Prerequisites: Abraxius App host running (${ABRAXIUS_NOTICE.prerequisites.daemonHost}) and ${ABRAXIUS_NOTICE.prerequisites.robloxStudio}.`,
    `- Recommended MCP command: ${ABRAXIUS_NOTICE.recommendedCommand} (or ${ABRAXIUS_NOTICE.alternativeCommand} for script changes).`,
    `- Safety Rule: ${ABRAXIUS_NOTICE.safetyNotice}`,
  ].join("\n");
}

module.exports = {
  ABRAXIUS_NOTICE,
  getHumanNotice,
};
