import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const baseUrl = process.env.AGENTOS_DASHBOARD_URL ?? "http://127.0.0.1:3000";
const executablePath = process.env.PLAYWRIGHT_EXECUTABLE_PATH;
const outputDir = process.env.VISUAL_OUTPUT_DIR ?? path.resolve("data/visual-smoke");
fs.mkdirSync(outputDir, { recursive: true });

const browser = await chromium.launch({ headless: true, executablePath });
try {
  for (const viewport of [{ name: "desktop", width: 1440, height: 900 }, { name: "mobile", width: 390, height: 844 }]) {
    const page = await browser.newPage({ viewport });
    const errors = [];
    page.on("console", (message) => { if (message.type() === "error") errors.push(message.text()); });
    await page.goto(baseUrl, { waitUntil: "networkidle" });
    const evidence = await page.evaluate(() => ({
      title: document.title,
      overflow: document.documentElement.scrollWidth > window.innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      viewportWidth: window.innerWidth,
      headings: Array.from(document.querySelectorAll("h1,h2")).map((element) => element.textContent?.trim()).filter(Boolean),
      runtimeCards: Array.from(document.querySelectorAll("section")).find((element) => element.textContent?.includes("Runtime health"))?.querySelectorAll(".grid > div").length ?? 0,
    }));
    await page.screenshot({ path: path.join(outputDir, `dashboard-${viewport.name}.png`), fullPage: true });
    fs.writeFileSync(path.join(outputDir, `dashboard-${viewport.name}.json`), JSON.stringify({ ...evidence, consoleErrors: errors }, null, 2));
    if (evidence.overflow) throw new Error(`${viewport.name} has horizontal overflow: ${evidence.scrollWidth}/${evidence.viewportWidth}`);
    if (!evidence.headings.includes("AgentOS") || !evidence.headings.includes("Runtime health")) throw new Error(`${viewport.name} missing primary headings`);
    if (evidence.runtimeCards < 1) throw new Error(`${viewport.name} rendered no runtime cards`);
    if (errors.length) throw new Error(`${viewport.name} console errors: ${errors.join(" | ")}`);
    await page.close();
  }
  console.log("dashboard_visual_status=PASS");
  console.log(`output_dir=${outputDir}`);
} finally {
  await browser.close();
}
