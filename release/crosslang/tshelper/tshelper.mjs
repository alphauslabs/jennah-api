// The TypeScript side of the cross-language session tests. run.sh installs the
// jennah-sdk-ts tarball that verify just tested next to this file, so the
// TypeScript half of every test is the code being released.
//
//   node tshelper.mjs call <endpoint>   one authenticated call, resolving the stored session
//   node tshelper.mjs write <n>         rewrite the stored session n times
//   node tshelper.mjs read <seconds>    load the stored session repeatedly, report partial reads

import { Client, loadSession, newSession, saveSession } from "jennah-sdk-ts";

function fail(msg) {
  process.stderr.write(`${msg}\n`);
  process.exit(1);
}

// A writer's n-th session. The run of x's is n%37 long, so a reader can tell a
// whole token from a torn one without knowing what was written.
const token = (lang, n) => `${lang}_${n}_${"x".repeat(n % 37)}`;
const SHAPE = /^(go|py|ts)_(\d+)_(x*)$/;
function wholeToken(t) {
  const m = SHAPE.exec(t);
  return m !== null && m[3].length === Number(m[2]) % 37;
}

async function call(endpoint) {
  let client;
  try {
    client = new Client({ endpoint, insecure: true });
  } catch (e) {
    fail(`construct: ${e.message}`);
  }
  try {
    await client.agents.listAgents({}, { timeoutMs: 20_000 });
  } catch (e) {
    fail(`call: ${e.message}`);
  } finally {
    client.close();
  }
  console.log("ok");
}

async function write(n) {
  for (let i = 0; i < n; i++) {
    try {
      await saveSession(
        newSession({ endpoint: "https://jennah.alphaus.cloud", accessToken: token("ts", i), refreshToken: "rt", tokenType: "Bearer" }),
      );
    } catch (e) {
      fail(`save: ${e.message}`);
    }
  }
  console.log("ok");
}

async function read(seconds) {
  let reads = 0;
  let partial = 0;
  for (const end = Date.now() + seconds * 1000; Date.now() < end; ) {
    let s;
    try {
      s = await loadSession();
    } catch {
      reads++;
      partial++;
      continue;
    }
    if (s === undefined) continue;
    reads++;
    if (!wholeToken(s.accessToken)) partial++;
  }
  console.log(`${reads} ${partial}`);
}

const [cmd, arg] = process.argv.slice(2);
if (arg === undefined) fail("usage: tshelper.mjs call <endpoint> | write <n> | read <seconds>");
switch (cmd) {
  case "call":
    await call(arg);
    break;
  case "write":
    await write(Number.parseInt(arg, 10));
    break;
  case "read":
    await read(Number.parseFloat(arg));
    break;
  default:
    fail(`unknown command ${cmd}`);
}
