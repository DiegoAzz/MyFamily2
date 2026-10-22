import { chromium } from "playwright";

async function run() {
  console.log("Launching Edge...");
  const browser = await chromium.launch({
    channel: "msedge",
    headless: true,
  });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
  });
  const page = await context.newPage();

  page.on("console", (msg) => console.log("[BROWSER]", msg.text()));
  page.on("pageerror", (err) => console.error("[BROWSER ERROR]", err));

  console.log("Navigating to http://localhost:5173...");
  await page.goto("http://localhost:5173", { waitUntil: "networkidle" });

  console.log("Clicking 'DESPERTAR EN LA ISLA'...");
  await page.click("button:has-text('DESPERTAR EN LA ISLA')");

  console.log("Waiting 6 seconds for Babylon.js 3D world to render...");
  await page.waitForTimeout(6000);

  const screenshotPath =
    "C:\\Users\\Diego\\.gemini\\antigravity\\brain\\f1ec7eea-9497-480f-9520-1a6e1d9681de\\wildborn_gameplay_3d.png";
  await page.screenshot({ path: screenshotPath });
  console.log("Screenshot saved to:", screenshotPath);

  await browser.close();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
