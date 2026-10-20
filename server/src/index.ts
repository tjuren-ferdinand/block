import { networkInterfaces } from "os";
import { config } from "./config";
import { GameServer } from "./net/wsServer";

function localAddresses(): string[] {
  const out: string[] = [];
  for (const infos of Object.values(networkInterfaces())) {
    for (const info of infos ?? []) {
      if (info.family === "IPv4" && !info.internal) out.push(info.address);
    }
  }
  return out;
}

const server = new GameServer(config.port, config.host);
console.log("Block Duel server running");
console.log(`Port: ${config.port}`);
for (const addr of localAddresses()) {
  console.log(`Local network IP: ${addr}  ->  ws://${addr}:${config.port}`);
}
console.log(`Match duration: ${config.matchDurationMs / 1000}s | Reconnect grace: ${config.reconnectGraceMs / 1000}s`);

process.on("SIGINT", () => {
  server.close();
  process.exit(0);
});
process.on("SIGTERM", () => {
  server.close();
  process.exit(0);
});
