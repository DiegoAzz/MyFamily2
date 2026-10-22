import { chromium } from "playwright";

async function run() {
  console.log("Launching Edge for Mobile testing...");
  const browser = await chromium.launch({
    channel: "msedge",
    headless: true,
  });

  // Emulación de Móvil (iPhone 13 / Pixel 7: 390x844 con Touch activado)
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();

  page.on("console", (msg) => console.log("[BROWSER]", msg.text()));

  console.log("Navigating to http://localhost:2567 (direct Node.js Express server)...");
  await page.goto("http://localhost:2567", { waitUntil: "networkidle" });

  // 1. Captura del Menú en Móvil
  const menuPath =
    "C:\\Users\\Diego\\.gemini\\antigravity\\brain\\f1ec7eea-9497-480f-9520-1a6e1d9681de\\wildborn_mobile_menu.png";
  await page.screenshot({ path: menuPath });
  console.log("Mobile Menu Screenshot saved to:", menuPath);

  // 2. Entrar a la isla
  console.log("Clicking 'DESPERTAR EN LA ISLA' on mobile...");
  await page.click("button:has-text('DESPERTAR EN LA ISLA')");
  await page.waitForTimeout(5000);

  // 3. Captura del Gameplay en Móvil (Retrato)
  const gameplayPath =
    "C:\\Users\\Diego\\.gemini\\antigravity\\brain\\f1ec7eea-9497-480f-9520-1a6e1d9681de\\wildborn_mobile_gameplay.png";
  await page.screenshot({ path: gameplayPath });
  console.log("Mobile Gameplay Screenshot saved to:", gameplayPath);

  // 4. Captura en Modo Paisaje (Landscape 844x390)
  await page.setViewportSize({ width: 844, height: 390 });
  await page.waitForTimeout(1000);
  const landscapePath =
    "C:\\Users\\Diego\\.gemini\\antigravity\\brain\\f1ec7eea-9497-480f-9520-1a6e1d9681de\\wildborn_mobile_landscape.png";
  await page.screenshot({ path: landscapePath });
  console.log("Mobile Landscape Screenshot saved to:", landscapePath);

  await browser.close();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
