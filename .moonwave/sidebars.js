module.exports = {
  docs: [
    "intro",
    {
      type: "category",
      label: "Use Abraxius",
      collapsed: false,
      items: ["installation", "windows-app", "sync"],
    },
    {
      type: "category",
      label: "AI and automation",
      collapsed: false,
      items: ["ai-usage", "ai-context", "github-context", "axl"],
    },
    {
      type: "category",
      label: "Reference",
      collapsed: true,
      items: ["cli", "api", "rust-extension", "agent-skill"],
    },
    "product-roadmap",
  ],
};
