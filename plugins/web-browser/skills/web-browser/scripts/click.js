#!/usr/bin/env node

/**
 * Click an element by CSS selector.
 * Dispatches real mouse events (mousedown → mouseup → click) at the element's
 * centre, matching what a real user does. Falls back to .click() if the element
 * has no layout box (e.g. hidden elements).
 *
 * Usage:
 *   ./click.js <selector>            # Click first matching element
 *   ./click.js <selector> --index N  # Click the Nth match (0-based)
 *   ./click.js <selector> --force    # Use .click() even if element has layout
 */

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const selector = process.argv[2];
if (!selector) {
  console.log("Usage: click.js <selector> [--index N] [--force]");
  console.log("\nExamples:");
  console.log('  click.js \'button[type="submit"]\'');
  console.log("  click.js 'a[href=\"/login\"]'");
  console.log('  click.js \'.item\' --index 2');
  process.exit(1);
}

const idxArg = process.argv.indexOf("--index");
const elementIndex = idxArg !== -1 ? parseInt(process.argv[idxArg + 1], 10) : 0;
const force = process.argv.includes("--force");

const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

try {
  log("connecting...");
  const cdp = await connect(5000);

  log("getting pages...");
  const pages = await cdp.getPages();
  const page = pages.at(-1);
  if (!page) { console.error("✗ No active tab found"); process.exit(1); }

  log("attaching...");
  const sessionId = await cdp.attachToPage(page.targetId);

  // Resolve element and get its centre
  const info = await cdp.evaluate(sessionId, `(() => {
    const els = document.querySelectorAll(${JSON.stringify(selector)});
    const el = els[${elementIndex}];
    if (!el) return { error: "Element not found: " + ${JSON.stringify(selector)} + " (index ${elementIndex})" };
    const r = el.getBoundingClientRect();
    return { x: r.left + r.width / 2, y: r.top + r.height / 2, hasLayout: r.width > 0 || r.height > 0, tag: el.tagName.toLowerCase() };
  })()`);

  if (info?.error) {
    console.error("✗", info.error);
    process.exit(1);
  }

  if (!force && info.hasLayout) {
    // Dispatch real mouse events via Input domain for accurate interaction
    log(`clicking at (${info.x}, ${info.y})...`);
    const mouseParams = { x: info.x, y: info.y, button: "left", clickCount: 1 };
    await cdp.send("Input.dispatchMouseEvent", { type: "mousePressed", ...mouseParams }, sessionId);
    await cdp.send("Input.dispatchMouseEvent", { type: "mouseReleased", ...mouseParams }, sessionId);
  } else {
    // Fall back to programmatic click (works for off-screen / hidden elements)
    log("using programmatic .click()...");
    await cdp.evaluate(sessionId, `document.querySelectorAll(${JSON.stringify(selector)})[${elementIndex}].click()`);
  }

  console.log(`✓ Clicked <${info.tag}> ${selector}${elementIndex > 0 ? ` [${elementIndex}]` : ""}`);

  cdp.close();
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
