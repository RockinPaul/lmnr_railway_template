// Block until Postgres accepts TCP connections and ClickHouse answers /ping.
//
// The Next.js startup hook runs both sets of migrations before it serves
// anything and rethrows if ClickHouse is unreachable, so on a fresh deployment
// the frontend would otherwise crash-loop until the stores finish starting.
import net from "node:net";

const TIMEOUT_MS = 300_000;
const RETRY_MS = 2_000;
const deadline = Date.now() + TIMEOUT_MS;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const tcpOpen = (host, port) =>
  new Promise((resolve) => {
    const socket = net.connect({ host, port, timeout: 5_000 });
    const done = (ok) => {
      socket.destroy();
      resolve(ok);
    };
    socket.once("connect", () => done(true));
    socket.once("error", () => done(false));
    socket.once("timeout", () => done(false));
  });

const httpOk = async (url) => {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(5_000) });
    return res.ok;
  } catch {
    return false;
  }
};

const waitFor = async (label, probe) => {
  for (let attempt = 1; ; attempt++) {
    if (await probe()) {
      console.log(`${label} is ready`);
      return;
    }
    if (Date.now() > deadline) {
      console.error(`timed out waiting for ${label}`);
      process.exit(1);
    }
    if (attempt === 1 || attempt % 10 === 0) {
      console.log(`waiting for ${label}...`);
    }
    await sleep(RETRY_MS);
  }
};

const pg = new URL(process.env.DATABASE_URL);
const ch = new URL(process.env.CLICKHOUSE_URL);

await waitFor("postgres", () => tcpOpen(pg.hostname, Number(pg.port || 5432)));
// /ping means the HTTP interface is serving, not merely that the port is open,
// which is what the migrations actually need.
await waitFor("clickhouse", () => httpOk(new URL("/ping", ch).toString()));
