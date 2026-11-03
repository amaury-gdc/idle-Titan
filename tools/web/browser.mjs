// Launches a Chromium browser (Edge by default) for the captures and the measures of the web export,
// drives it through the DevTools protocol, and ALWAYS closes it: on success, on an error, on a
// timeout, on Ctrl+C. Never the user's profile: a temporary one, removed at the end.
//
// Why the process tree and the profile matter (story 019b): Edge relaunches itself under another PID
// (it adds --edge-skip-compat-layer-relaunch), so killing the process Node started leaves the real
// browser running. The cleanup therefore kills the whole tree AND every process whose command line
// holds this run's own --user-data-dir, which can only be ours.
//
// Environment:
//   BROWSER_PATH        executable to use (any Chromium: Edge, Chrome, Opera); first choice.
//   BROWSER_HEADLESS    "0" opens a visible window; headless otherwise.
//   BROWSER_TIMEOUT_MS  the whole run stops (and closes the browser) after this; 600000 by default.
//   BROWSER_WINDOW_POSITION  "x,y" in screen pixels: where a visible window opens (for instance on
//                       the monitor of the editor); the system chooses otherwise.
//
// Usage:
//   import { withBrowser } from "./browser.mjs";
//   await withBrowser({ gpu: true }, async (browser) => {
//     const page = await browser.newPage();
//     await page.send("Page.navigate", { url });
//   });
import { spawn, execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const DEFAULT_TIMEOUT_MS = 600000;
const START_TIMEOUT_MS = 20000;
const CLOSE_GRACE_MS = 3000;
const POLL_MS = 100;
const PROFILE_PREFIX = "catitans-browser-";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** The browser to launch: BROWSER_PATH, else Edge in Program Files, else in Program Files (x86). */
export function browserPath() {
  if (process.env.BROWSER_PATH) {
    if (!existsSync(process.env.BROWSER_PATH)) throw new Error(`BROWSER_PATH does not exist: ${process.env.BROWSER_PATH}`);
    return process.env.BROWSER_PATH;
  }
  const roots = [process.env.ProgramFiles, process.env["ProgramFiles(x86)"]].filter(Boolean);
  const candidates = roots.map((root) => join(root, "Microsoft", "Edge", "Application", "msedge.exe"));
  const found = candidates.find((path) => existsSync(path));
  if (!found) throw new Error(`Edge not found (looked in: ${candidates.join(", ")}). Set BROWSER_PATH.`);
  return found;
}

// Every process whose command line holds this profile, then each one's tree. Windows only; elsewhere
// pkill does the same on the command line.
function killByProfile(profile, firstPid) {
  if (process.platform !== "win32") {
    try { execFileSync("pkill", ["-9", "-f", profile], { stdio: "ignore" }); } catch { /* none left */ }
    return;
  }
  const pids = new Set(firstPid ? [firstPid] : []);
  try {
    const escaped = profile.replace(/'/g, "''");
    const out = execFileSync("powershell.exe", ["-NoProfile", "-Command",
      `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine.Contains('${escaped}') } | ForEach-Object { $_.ProcessId }`],
      { encoding: "utf8" });
    for (const line of out.split(/\r?\n/)) if (/^\d+$/.test(line.trim())) pids.add(Number(line.trim()));
  } catch { /* the search failing must not stop the rest of the cleanup */ }
  for (const pid of pids) {
    try { execFileSync("taskkill", ["/PID", String(pid), "/T", "/F"], { stdio: "ignore" }); } catch { /* already gone */ }
  }
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let nextId = 0;
  const pending = new Map();
  const listeners = [];
  ws.addEventListener("message", (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(`${msg.error.message} (${msg.error.code})`));
      else resolve(msg.result);
      return;
    }
    for (const listener of listeners) listener(msg);
  });
  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params, sessionId }));
  });
  const opened = new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", () => reject(new Error("DevTools connection failed")), { once: true });
  });
  return { ws, send, opened, onEvent: (listener) => listeners.push(listener) };
}

/**
 * Runs [work] with a fresh browser and closes it whatever happens. [options.gpu] asks for hardware
 * rendering (needed to measure smoothness); otherwise the software renderer is used, which is
 * enough for screenshots and the same on every machine.
 */
export async function withBrowser(options, work) {
  const headless = process.env.BROWSER_HEADLESS !== "0";
  const timeoutMs = Number(process.env.BROWSER_TIMEOUT_MS) || DEFAULT_TIMEOUT_MS;
  const executable = browserPath();
  const profile = mkdtempSync(join(tmpdir(), PROFILE_PREFIX));
  const args = [
    `--user-data-dir=${profile}`, "--remote-debugging-port=0", "--no-first-run", "--no-default-browser-check",
    "--disable-backgrounding-occluded-windows", "--disable-renderer-backgrounding", "--disable-background-timer-throttling",
  ];
  if (headless) args.push("--headless=new");
  if (options.gpu) args.push("--use-angle=d3d11", "--enable-gpu", "--ignore-gpu-blocklist");
  else args.push("--use-angle=swiftshader", "--enable-unsafe-swiftshader");
  if (options.windowSize) args.push(`--window-size=${options.windowSize}`);
  const position = process.env.BROWSER_WINDOW_POSITION;
  if (position) {
    if (!/^-?\d+,-?\d+$/.test(position)) throw new Error(`BROWSER_WINDOW_POSITION must be x,y, got ${position}`);
    args.push(`--window-position=${position}`);
  }
  args.push("about:blank");

  const child = spawn(executable, args, { stdio: "ignore" });
  let cdp = null;
  let cleaned = false;
  const cleanup = async () => {
    if (cleaned) return;
    cleaned = true;
    if (cdp) {
      try { await Promise.race([cdp.send("Browser.close"), sleep(CLOSE_GRACE_MS)]); } catch { /* closing anyway */ }
      try { cdp.ws.close(); } catch { /* closed */ }
    }
    killByProfile(profile, child.pid);
    // The profile is locked until the last process is gone.
    for (let i = 0; i < 20; i++) {
      try { rmSync(profile, { recursive: true, force: true }); break; } catch { await sleep(250); }
    }
  };
  // Last resort when Node exits without the finally (a crash in a callback): synchronous kill.
  const onExit = () => { if (!cleaned) killByProfile(profile, child.pid); };
  const onSignal = (signal) => { cleanup().finally(() => process.exit(signal === "SIGINT" ? 130 : 143)); };
  process.once("exit", onExit);
  process.once("SIGINT", onSignal);
  process.once("SIGTERM", onSignal);

  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`timeout after ${timeoutMs} ms (BROWSER_TIMEOUT_MS)`)), timeoutMs);
  });
  try {
    const run = (async () => {
      // --remote-debugging-port=0 picks a free port and writes it in the profile.
      const portFile = join(profile, "DevToolsActivePort");
      const deadline = Date.now() + START_TIMEOUT_MS;
      while (!existsSync(portFile)) {
        if (Date.now() > deadline) throw new Error(`the browser did not start: ${executable}`);
        await sleep(POLL_MS);
      }
      const [port, path] = readFileSync(portFile, "utf8").trim().split(/\r?\n/);
      cdp = connect(`ws://127.0.0.1:${port}${path}`);
      await cdp.opened;
      const browser = {
        send: cdp.send,
        onEvent: cdp.onEvent,
        // A tab of its own, brought to the front: a tab in the background gets no animation frame.
        async newPage() {
          const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
          await cdp.send("Target.activateTarget", { targetId });
          const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
          const send = (method, params = {}) => cdp.send(method, params, sessionId);
          await send("Page.enable");
          await send("Runtime.enable");
          return { targetId, sessionId, send, close: () => cdp.send("Target.closeTarget", { targetId }) };
        },
      };
      return await work(browser);
    })();
    return await Promise.race([run, timeout]);
  } finally {
    clearTimeout(timer);
    await cleanup();
    process.removeListener("exit", onExit);
    process.removeListener("SIGINT", onSignal);
    process.removeListener("SIGTERM", onSignal);
  }
}

export { sleep };
