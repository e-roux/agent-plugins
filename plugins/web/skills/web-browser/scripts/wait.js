#!/usr/bin/env node

/**
 * Wait for a CSS selector to appear in the DOM.
 * Useful when navigating SPAs where content loads asynchronously.
 *
 * Usage:
 *   ./wait.js <selector>                        # Wait for element to exist
 *   ./wait.js <selector> --visible              # Wait until also visible
 *   ./wait.js <selector> --timeout 15000        # Custom timeout (ms, default 10000)
 *   ./wait.js <selector> --gone                 # Wait until element disappears
 */

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const selector = process.argv[2];
if (!selector) {
  console.log("Usage: wait.js <selector> [--visible] [--gone] [--timeout ms]");
  console.log("\nExamples:");
  console.log('  wait.js \'.dashboard-loaded\'');
  console.log('  wait.js \'#spinner\' --gone');
  console.log('  wait.js \'[data-ready]\' --visible --timeout 20000');
  process.exit(1);
}

const visible = process.argv.includes("--visible");
const gone = process.argv.includes("--gone");
const toIdx = process.argv.indexOf("--timeout");
const timeout = toIdx !== -1 ? parseInt(process.argv[toIdx + 1], 10) : 10000;

const globalTimeout = setTimeout(() => {
  console.error(`✗ Timeout: selector "${selector}" not ${gone ? "gone" : (visible ? "visible" : "found")} after ${timeout}ms`);
  process.exit(1);
}, timeout + 5000);

const POLL_EXPR = `(() => {
  const el = document.querySelector(${JSON.stringify(selector)});
  if (${gone}) return !el;
  if (!el) return false;
  if (!${visible}) return true;
  const s = getComputedStyle(el);
  return s.display !== 'none' && s.visibility !== 'hidden' && s.opacity !== '0' && (el.offsetParent !== null || s.position === 'fixed');
})()`;

try {
  log("connecting...");
  const cdp = await connect(5000);

  log("getting pages...");
  const pages = await cdp.getPages();
  const page = pages.at(-1);
  if (!page) { console.error("✗ No active tab found"); process.exit(1); }

  log("attaching...");
  const sessionId = await cdp.attachToPage(page.targetId);

  const deadline = Date.now() + timeout;
  const INTERVAL = 250;
  let succeeded = false;

  while (Date.now() < deadline) {
    const found = await cdp.evaluate(sessionId, POLL_EXPR);
    if (found) { succeeded = true; break; }
    await new Promise((r) => setTimeout(r, INTERVAL));
  }

  cdp.close();
  clearTimeout(globalTimeout);

  if (succeeded) {
    const condition = gone ? "gone" : visible ? "visible" : "found";
    console.log(`✓ "${selector}" ${condition}`);
    setTimeout(() => process.exit(0), 100);
  } else {
    console.error(`✗ Timeout: "${selector}" not ${gone ? "gone" : (visible ? "visible" : "found")} after ${timeout}ms`);
    process.exit(1);
  }
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
}
