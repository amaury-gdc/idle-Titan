// Screenshots of the web export at several sizes, with touches and waits in between (story 019b).
// Headless and software-rendered by default (see browser.mjs), so the same on every machine.
//
// Usage: node tools/web/capture.mjs <url> <out_dir> <prefix> <spec> [<spec> ...]
//   spec: WxH[@dpr][m] ("m": phone emulation), then any number of steps:
//     +X,Y:name   touch at X,Y CSS px, wait 900 ms, capture <prefix>-wWxH-name.png
//     +wMS:name   wait MS, capture <prefix>-wWxH-name.png
//   Example: node tools/web/capture.mjs http://127.0.0.1:8765/index.html out lot3 "390x742@2m+330,85:combat"
// Prints, for each size, the window and canvas sizes and whether the page scrolls sideways.
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { withBrowser, sleep } from "./browser.mjs";

const LOAD_MS = 9000;
const STEP_MS = 900;

function parseSpec(spec) {
  const [head, ...steps] = spec.split("+");
  const m = head.match(/^(\d+)x(\d+)(?:@([\d.]+))?(m?)$/);
  if (!m) throw new Error(`bad size: ${head}`);
  return {
    w: +m[1], h: +m[2], dpr: +(m[3] || 1), mobile: m[4] === "m", tag: `w${m[1]}x${m[2]}`,
    steps: steps.map((s) => {
      const wait = s.match(/^w(\d+):([\w-]+)$/);
      if (wait) return { wait: +wait[1], name: wait[2] };
      const touch = s.match(/^(\d+(?:\.\d+)?),(\d+(?:\.\d+)?):([\w-]+)$/);
      if (!touch) throw new Error(`bad step: ${s}`);
      return { x: +touch[1], y: +touch[2], name: touch[3] };
    }),
  };
}

const [url, outDir, prefix, ...specs] = process.argv.slice(2);
if (!url || !outDir || !prefix || specs.length === 0) {
  console.error("usage: node tools/web/capture.mjs <url> <out_dir> <prefix> <spec> [<spec> ...]");
  process.exit(2);
}
const sizes = specs.map(parseSpec);
mkdirSync(outDir, { recursive: true });

try {
  await withBrowser({ gpu: false }, async (browser) => {
    const logs = [];
    browser.onEvent((msg) => {
      if (msg.method === "Runtime.consoleAPICalled" && ["error", "warning"].includes(msg.params.type))
        logs.push(`${msg.params.type}: ${msg.params.args.map((a) => a.value ?? a.description).join(" ")}`);
      if (msg.method === "Runtime.exceptionThrown") logs.push(`exception: ${msg.params.exceptionDetails.text}`);
    });
    for (const size of sizes) {
      const page = await browser.newPage();
      const shoot = async (name) => {
        const { data } = await page.send("Page.captureScreenshot", { format: "png" });
        const file = join(outDir, name);
        writeFileSync(file, Buffer.from(data, "base64"));
        return file;
      };
      await page.send("Emulation.setDeviceMetricsOverride", { width: size.w, height: size.h, deviceScaleFactor: size.dpr, mobile: size.mobile });
      await page.send("Page.navigate", { url });
      await sleep(LOAD_MS);
      const probe = await page.send("Runtime.evaluate", {
        expression: "JSON.stringify({iw:innerWidth,ih:innerHeight,dpr:devicePixelRatio,sw:document.documentElement.scrollWidth,cw:(document.querySelector('canvas')||{}).width})",
        returnByValue: true,
      });
      console.log(await shoot(`${prefix}-${size.tag}.png`), probe.result.value);
      for (const step of size.steps) {
        if (step.wait !== undefined) {
          await sleep(step.wait);
        } else {
          for (const type of ["mousePressed", "mouseReleased"])
            await page.send("Input.dispatchMouseEvent", { type, x: step.x, y: step.y, button: "left", clickCount: 1 });
          await sleep(STEP_MS);
        }
        console.log(await shoot(`${prefix}-${size.tag}-${step.name}.png`));
      }
      await page.close();
    }
    console.log(logs.length ? logs.join("\n") : "console: no error");
  });
} catch (error) {
  console.error(`capture failed: ${error.message}`);
  process.exitCode = 1;
}
