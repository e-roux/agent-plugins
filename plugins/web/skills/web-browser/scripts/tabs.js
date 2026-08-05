#!/usr/bin/env node

/**
 * List all open browser tabs.
 *
 * Usage:
 *   ./tabs.js           # Show all tabs
 *   ./tabs.js --json    # Raw JSON output
 */

import { connect } from "./cdp.js";

const jsonMode = process.argv.includes("--json");

const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (10s)");
  process.exit(1);
}, 10000);

try {
  const cdp = await connect(5000);
  const pages = await cdp.getPages();

  if (pages.length === 0) {
    console.log("No open tabs");
    cdp.close();
    process.exit(0);
  }

  if (jsonMode) {
    console.log(JSON.stringify(pages, null, 2));
  } else {
    pages.forEach((p, i) => {
      const title = p.title ? p.title.slice(0, 60) : "(no title)";
      const url = p.url ? p.url.slice(0, 80) : "(no url)";
      console.log(`[${i}] ${title}`);
      console.log(`    ${url}`);
      console.log(`    id: ${p.targetId}`);
    });
  }

  cdp.close();
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
