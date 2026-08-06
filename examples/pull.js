const { MCPClient } = require("../client");
const { Puller } = require("../lib/pull");

async function main() {
  const client = new MCPClient();
  const puller = new Puller(client, {
    outputDir: "./pulled-place",
    onProgress: (action, target) => console.log(`[${action}] ${target}`),
  });

  const { project, stats } = await puller.pull();
  console.log("\nPulled project:", project.name);
  console.log("Stats:", stats);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
