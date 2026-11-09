#!/usr/bin/env node
// Renders each Mermaid file given to an SVG with Pele and a 2x PNG beside it,
// for a Before and After flow chart pair. Classes `key` and `terminal` mark the
// steps a caption is about and the chart's start and end.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const files = process.argv.slice(2);
if (files.length === 0 || files.some((file) => !file.endsWith(".mmd") || !existsSync(file))) {
  console.error("usage: chart.mjs <file.mmd> [file.mmd...]");
  process.exit(2);
}

// The renderer and browser live outside any repository, installed on first use.
const tools = join(homedir(), ".cache", "pr-chart");
const modules = join(tools, "node_modules");
if (!existsSync(join(modules, "pele")) || !existsSync(join(modules, "playwright"))) {
  mkdirSync(tools, { recursive: true });
  execFileSync("npm", ["install", "--prefix", tools, "--no-save", "--silent", "pele@1.9.0", "playwright@1"], { stdio: "inherit" });
}
const { render } = await import(pathToFileURL(join(modules, "pele", "dist", "pele.js")).href);
const { chromium } = await import(pathToFileURL(join(modules, "playwright", "index.mjs")).href);

const css = `
.pele { --pele-bg: #ffffff; --pele-fg: #1c1c1c; --pele-muted: #656565; --pele-line: #808080;
  --pele-surface: #fcfcfc; --pele-surface-alt: #f1f1f1; --pele-border: #c9c9c9;
  --pele-font: Inter, "DejaVu Sans", sans-serif; }
.pele .key rect { fill: #c3e0ff !important; stroke: #1680f3 !important; stroke-width: 2px !important; }
.pele .terminal rect { fill: #f1f1f1 !important; }`;

let browser;
try {
  browser = await chromium.launch();
} catch {
  execFileSync(join(modules, ".bin", "playwright"), ["install", "chromium"], { stdio: "inherit" });
  browser = await chromium.launch();
}
const page = await browser.newPage({ deviceScaleFactor: 2 });
for (const file of files) {
  const { svg } = render(readFileSync(file, "utf8"), { limit: 1_000_000, outputLimit: 8_000_000, maxEdges: 10_000 });
  const styled = svg.replace(/<svg([^>]*)>/, `<svg$1><style>${css}</style>`);
  writeFileSync(file.replace(/\.mmd$/, ".svg"), styled);
  await page.setContent(`<body style="margin:0;background:#fff"><div id="chart" style="display:inline-block;padding:24px;background:#fff">${styled}</div></body>`);
  await page.locator("#chart").screenshot({ path: file.replace(/\.mmd$/, ".png") });
  console.log(file.replace(/\.mmd$/, ".png"));
}
await browser.close();
