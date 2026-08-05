#!/usr/bin/env node

/**
 * Set a file on a file input element without opening the native dialog.
 *
 * Usage:
 *   ./upload_file.js <file_path> [selector]
 *
 * Examples:
 *   upload_file.js /tmp/data.csv
 *   upload_file.js /tmp/data.csv 'input[name="attachment"]'
 */

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const filePath = process.argv[2];
const selector = process.argv[3] || 'input[type="file"]';

if (!filePath) {
  console.log('Usage: upload_file.js <file_path> [selector]');
  console.log('\nExamples:');
  console.log('  upload_file.js /tmp/data.csv');
  console.log('  upload_file.js /tmp/data.csv \'input[name="attachment"]\'');
  process.exit(1);
}

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

  log("resolving file input...");
  const { result } = await cdp.send("Runtime.evaluate", {
    expression: `document.querySelector(${JSON.stringify(selector)})`,
    returnByValue: false,
  }, sessionId);

  if (!result.objectId) {
    console.error("✗ File input not found:", selector);
    process.exit(1);
  }

  const { node } = await cdp.send("DOM.describeNode", { objectId: result.objectId }, sessionId);

  log("setting file...");
  await cdp.send("DOM.setFileInputFiles", {
    files: [filePath],
    backendNodeId: node.backendNodeId,
  }, sessionId);

  const name = await cdp.evaluate(sessionId, `document.querySelector(${JSON.stringify(selector)})?.files[0]?.name`);
  console.log(`✓ File set: ${filePath.split("/").at(-1)}`);
  if (name) console.log(`✓ Input reports: ${name}`);

  cdp.close();
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
