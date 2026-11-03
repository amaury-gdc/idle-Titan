// Smoothness of the web export (story 019b): for each shape and processor rate, passes of 10 s with
// about 13 touches per second on the monster, the page reloaded before each pass. The builds take
// turns pass by pass (A B A B ...), so that a drift of the machine during the run touches them all
// alike; compare builds measured in the same run only. Frame
// times come from requestAnimationFrame. Headless with hardware rendering by default (see
// browser.mjs); the renderer in use is printed, and a software one is a warning: such a measure
// says nothing about a real machine.
//
// The busy column is the share of the measure the main thread spent on tasks (Performance metric
// TaskDuration). It is the one that tells a costlier build in headless: there, the frame times
// stayed at 16.7 ms for a build whose drawing cost 18 to 32 frames over 33 ms per pass in a visible
// window (measured, story 019b). Compare builds on the busy share first.
//
// The touches must land on the monster of every build, or the builds do not do the same work: a
// layout that moves the monster needs its own point, given as touch:<label>:<shape>=X,Y (CSS px,
// shape "portrait" or "paysage"). Story 019b: the portrait monster of the reference stands at
// 195,197, the one of the new layout at 195,126 (the default); a reference touched at 195,126 was
// never hit, and seemed cheaper than it is.
//
// Usage: node tools/web/perf.mjs <label=url> [<label=url> ...] [touch:<label>:<shape>=X,Y ...]
// Environment: PERF_PASSES (5), PERF_RATES ("1,4"), PERF_MEASURE_MS (10000).
// Output: one JSON line per build, shape and rate, then a table with the median busy share.
import { withBrowser, sleep } from "./browser.mjs";

const SHAPES = [
  { key: "portrait", name: "portrait 390x742", w: 390, h: 742, dpr: 2, mobile: true, touch: { x: 195, y: 126 } },
  { key: "paysage", name: "paysage 1280x720", w: 1280, h: 720, dpr: 1, mobile: false, touch: { x: 384, y: 380 } },
];
const PASSES = Number(process.env.PERF_PASSES) || 5;
const RATES = (process.env.PERF_RATES || "1,4").split(",").map(Number);
const MEASURE_MS = Number(process.env.PERF_MEASURE_MS) || 10000;
const LOAD_MS = 9000;
const TOUCH_MS = 75;
const SLOW_FRAME_MS = 33.4;

const touches = new Map();
const builds = [];
for (const arg of process.argv.slice(2)) {
  const touch = arg.match(/^touch:([^:=]+):(portrait|paysage)=(\d+(?:\.\d+)?),(\d+(?:\.\d+)?)$/);
  if (touch) {
    touches.set(`${touch[1]}:${touch[2]}`, { x: +touch[3], y: +touch[4] });
    continue;
  }
  const i = arg.indexOf("=");
  if (i < 1 || arg.startsWith("touch:")) throw new Error(`expected label=url or touch:<label>:<shape>=X,Y, got ${arg}`);
  builds.push({ label: arg.slice(0, i), url: arg.slice(i + 1) });
}
if (builds.length === 0) {
  console.error("usage: node tools/web/perf.mjs <label=url> [<label=url> ...]");
  process.exit(2);
}

async function taskSeconds(page) {
  const { metrics } = await page.send("Performance.getMetrics");
  return metrics.find((m) => m.name === "TaskDuration").value;
}

function stats(frames, busySeconds) {
  const busy = +((busySeconds * 1000 / MEASURE_MS) * 100).toFixed(1);
  if (frames.length === 0) return { fps: 0, median: null, p95: null, worst: null, over33: null, busy, empty: true };
  const sorted = [...frames].sort((a, b) => a - b);
  const at = (share) => sorted[Math.min(sorted.length - 1, Math.floor(share * sorted.length))];
  return {
    fps: +(frames.length / (MEASURE_MS / 1000)).toFixed(1),
    median: +at(0.5).toFixed(1),
    p95: +at(0.95).toFixed(1),
    worst: +sorted[sorted.length - 1].toFixed(1),
    over33: frames.filter((t) => t > SLOW_FRAME_MS).length,
    busy,
  };
}

const RENDERER = "(()=>{const g=document.createElement('canvas').getContext('webgl2')||document.createElement('canvas').getContext('webgl');if(!g)return 'no WebGL';const e=g.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER)})()";
const RECORD = "window.__f=[];window.__last=performance.now();requestAnimationFrame(function t(n){window.__f.push(n-window.__last);window.__last=n;requestAnimationFrame(t)});document.visibilityState";

try {
  await withBrowser({ gpu: true, windowSize: "1400,900" }, async (browser) => {
    const page = await browser.newPage();
    await page.send("Performance.enable", { timeDomain: "threadTicks" });
    const rows = [];
    let renderer = null;
    for (const shape of SHAPES) for (const rate of RATES) {
      const passesOf = new Map(builds.map((build) => [build, []]));
      for (let p = 0; p < PASSES; p++) for (const build of builds) {
        await page.send("Emulation.setCPUThrottlingRate", { rate: 1 });
        await page.send("Emulation.setDeviceMetricsOverride", { width: shape.w, height: shape.h, deviceScaleFactor: shape.dpr, mobile: shape.mobile });
        await page.send("Page.navigate", { url: build.url });
        await sleep(LOAD_MS);
        if (renderer === null) {
          renderer = (await page.send("Runtime.evaluate", { expression: RENDERER, returnByValue: true })).result.value;
          console.log(`renderer: ${renderer}`);
          if (/swiftshader|software|basic render/i.test(renderer)) console.log("WARNING: software rendering, the measure is not representative");
        }
        await page.send("Emulation.setCPUThrottlingRate", { rate });
        const visibility = (await page.send("Runtime.evaluate", { expression: RECORD, returnByValue: true })).result.value;
        if (visibility !== "visible") console.log(`WARNING: page ${visibility} during ${build.label} ${shape.name} x${rate}`);
        const point = touches.get(`${build.label}:${shape.key}`) || shape.touch;
        const busyBefore = await taskSeconds(page);
        const end = Date.now() + MEASURE_MS;
        while (Date.now() < end) {
          const sent = Date.now();
          // Awaited: unacknowledged input events piling up stop the frames.
          for (const type of ["mousePressed", "mouseReleased"])
            await page.send("Input.dispatchMouseEvent", { type, x: point.x, y: point.y, button: "left", clickCount: 1 });
          await sleep(Math.max(0, TOUCH_MS - (Date.now() - sent)));
        }
        const busySeconds = (await taskSeconds(page)) - busyBefore;
        const frames = (await page.send("Runtime.evaluate", { expression: "JSON.stringify(window.__f.slice(1))", returnByValue: true })).result.value;
        passesOf.get(build).push(stats(JSON.parse(frames), busySeconds));
      }
      for (const build of builds) {
        const row = { build: build.label, shape: shape.name, cpu: `x${rate}`, passes: passesOf.get(build) };
        rows.push(row);
        console.log(JSON.stringify(row));
      }
    }
    await page.send("Emulation.setCPUThrottlingRate", { rate: 1 });
    const median = (values) => {
      const sorted = [...values].sort((a, b) => a - b);
      const mid = Math.floor(sorted.length / 2);
      return sorted.length % 2 ? sorted[mid] : +((sorted[mid - 1] + sorted[mid]) / 2).toFixed(2);
    };
    console.log("\nbuild | shape | cpu | busy % median | main thread busy % | fps | median ms | p95 ms | worst ms | frames > 33 ms (each pass)");
    for (const r of rows) {
      const cell = (key) => r.passes.map((p) => (p.empty && key !== "busy" ? "-" : p[key])).join(" / ");
      console.log(`${r.build} | ${r.shape} | ${r.cpu} | ${median(r.passes.map((p) => p.busy))} | ${cell("busy")} | ${cell("fps")} | ${cell("median")} | ${cell("p95")} | ${cell("worst")} | ${cell("over33")}`);
    }
  });
} catch (error) {
  console.error(`perf failed: ${error.message}`);
  process.exitCode = 1;
}
