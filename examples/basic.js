const { MCPClient } = require("../client");

async function main() {
  const client = new MCPClient();

  console.log("Health:", await client.health());
  console.log("Tools:", (await client.tools()).tools.map((t) => t.name));
  console.log("State:", await client.state());
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
