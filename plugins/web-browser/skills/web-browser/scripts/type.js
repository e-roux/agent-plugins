#!/usr/bin/env node

/**
 * Type text into an input, textarea, or contenteditable element.
 * Focuses the element and uses Input.insertText so frameworks that listen to
 * native input events (React, Svelte, Vue) respond correctly.
 * Optionally clears existing content first.
 *
 * Usage:
 *   ./type.js <selector> <text>         # Append text to element
 *   ./type.js <selector> <text> --clear # Clear first, then type
 */

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const selector = process.argv[2];
const text = process.argv[3];

if (!selector || text === undefined) {
  console.log("Usage: type.js <selector> <text> [--clear]");
  console.log("\nExamples:");
  console.log('  type.js \'input[name="email"]\' "user@example.com" --clear');
  console.log('  type.js \'[contenteditable]\' "Hello World" --clear');
  process.exit(1);
}

const clear = process.argv.includes("--clear");

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

  // Focus the element and optionally clear it
  const info = await cdp.evaluate(sessionId, `(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    if (!el) return { error: "Element not found: " + ${JSON.stringify(selector)} };
    el.focus();
    if (${clear}) {
      // Works for inputs, textareas, and contenteditables
      if (typeof el.value !== 'undefined') {
        const nativeSetter = Object.getOwnPropertyDescriptor(el.constructor.prototype, 'value')?.set;
        if (nativeSetter) {
          nativeSetter.call(el, '');
          el.dispatchEvent(new Event('input', { bubbles: true }));
        } else {
          el.value = '';
        }
      } else if (el.isContentEditable) {
        el.textContent = '';
      }
    }
    return { tag: el.tagName.toLowerCase(), type: el.type || null };
  })()`);

  if (info?.error) {
    console.error("✗", info.error);
    process.exit(1);
  }

  // Insert text via Input domain — triggers native keyboard events
  log("inserting text...");
  await cdp.send("Input.insertText", { text }, sessionId);

  console.log(`✓ Typed into <${info.tag}${info.type ? ` type="${info.type}"` : ""}> ${selector}${clear ? " (cleared first)" : ""}`);

  cdp.close();
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
