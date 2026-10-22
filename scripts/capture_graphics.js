import { chromium } from "playwright";

async function run() {
  console.log("Launching Edge to capture new graphics...");
  const browser = await chromium.launch({
    channel: "msedge",
    headless: true,
  });

  // 1. Desktop 1280x720 Widescreen - Vista de Exploración
  const desktopContext = await browser.newContext({
    viewport: { width: 1280, height: 720 },
  });
  const page = await desktopContext.newPage();
  page.on("console", (msg) => console.log("[BROWSER]", msg.text()));

  console.log("Navigating to http://localhost:2567...");
  await page.goto("http://localhost:2567", { waitUntil: "networkidle" });
  await page.click("button:has-text('DESPERTAR EN LA ISLA')");
  console.log("Waiting 5 seconds for 3D world to render with post-processing...");
  await page.waitForTimeout(5000);

  const desktopPath =
    "C:\\Users\\Diego\\.gemini\\antigravity\\brain\\f1ec7eea-9497-480f-9520-1a6e1d9681de\\wildborn_graphics_desktop.png";
  await page.screenshot({ path: desktopPath });
  console.log("Desktop Graphics screenshot saved to:", desktopPath);

  // 2. Desktop Vista Frontal del Aventurero (Rostro, peinado y equipamiento)
  await page.evaluate(() => {
    const ctrl = window.__controller;
    if (ctrl) {
      ctrl.yaw += Math.PI;
      ctrl.camera.radius = 3.6;
      ctrl.camera.beta = Math.PI / 2.6;
    }
  });
  await page.waitForTimeout(1500);

  const frontPath =
    "C:\\Users\\Diego\\.gemini\\antigravity\\brain\\f1ec7eea-9497-480f-9520-1a6e1d9681de\\wildborn_graphics_front.png";
  await page.screenshot({ path: frontPath });
  console.log("Front Adventurer screenshot saved to:", frontPath);

  // 3. Mobile 390x844 Portrait
  const mobileContext = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
  });
  const mobilePage = await mobileContext.newPage();
  await mobilePage.goto("http://localhost:2567", { waitUntil: "networkidle" });
  await mobilePage.click("button:has-text('DESPERTAR EN LA ISLA')");
  await mobilePage.waitForTimeout(5000);

  const mobilePath =
    "C:\\Users\\Diego\\.gemini\\antigravity\\brain\\f1ec7eea-9497-480f-9520-1a6e1d9681de\\wildborn_graphics_mobile.png";
  await mobilePage.screenshot({ path: mobilePath });
  console.log("Mobile Graphics screenshot saved to:", mobilePath);

  await browser.close();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
