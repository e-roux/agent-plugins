#!/usr/bin/env node

/**
 * Report performance metrics for the current page.
 * Combines CDP Performance.getMetrics with window.performance navigation timing.
 *
 * Usage:
 *   ./perf.js          # Human-readable summary
 *   ./perf.js --json   # Raw JSON
 */

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const jsonMode = process.argv.includes("--json");

const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

function ms(val) {
  return val != null ? `${Math.round(val)}ms` : "n/a";
}

try {
  log("connecting...");
  const cdp = await connect(5000);

  log("getting pages...");
  const pages = await cdp.getPages();
  const page = pages.at(-1);
  if (!page) { console.error("✗ No active tab found"); process.exit(1); }

  log("attaching...");
  const sessionId = await cdp.attachToPage(page.targetId);

  // Enable Performance domain
  await cdp.send("Performance.enable", {}, sessionId);

  // CDP metrics (V8 heap, layout count, etc.)
  const { metrics } = await cdp.send("Performance.getMetrics", {}, sessionId);
  const metricsMap = Object.fromEntries(metrics.map((m) => [m.name, m.value]));

  // Navigation timing from the page context
  const timing = await cdp.evaluate(sessionId, `(() => {
    const e = window.performance?.getEntriesByType("navigation")[0];
    if (!e) return null;
    return {
      dns:              Math.round(e.domainLookupEnd - e.domainLookupStart),
      tcp:              Math.round(e.connectEnd - e.connectStart),
      ttfb:             Math.round(e.responseStart - e.requestStart),
      responseEnd:      Math.round(e.responseEnd - e.fetchStart),
      domInteractive:   Math.round(e.domInteractive - e.fetchStart),
      domComplete:      Math.round(e.domComplete - e.fetchStart),
      loadEvent:        Math.round(e.loadEventEnd - e.fetchStart),
      redirectCount:    e.redirectCount,
      transferSize:     e.transferSize,
      encodedBodySize:  e.encodedBodySize,
      decodedBodySize:  e.decodedBodySize,
      url:              e.name,
    };
  })()`);

  // Web Vitals via PerformanceObserver (if already reported)
  const vitals = await cdp.evaluate(sessionId, `(() => {
    const result = {};
    const paints = window.performance?.getEntriesByType("paint") || [];
    for (const p of paints) {
      if (p.name === "first-contentful-paint") result.fcp = Math.round(p.startTime);
      if (p.name === "first-paint") result.fp = Math.round(p.startTime);
    }
    const lcp = window.performance?.getEntriesByType("largest-contentful-paint") || [];
    if (lcp.length) result.lcp = Math.round(lcp[lcp.length - 1].startTime);
    const cls = window.performance?.getEntriesByType("layout-shift") || [];
    if (cls.length) result.cls = cls.reduce((s, e) => s + e.value, 0).toFixed(4);
    return result;
  })()`);

  if (jsonMode) {
    console.log(JSON.stringify({ timing, vitals, cdpMetrics: metricsMap }, null, 2));
    cdp.close();
    clearTimeout(globalTimeout);
    setTimeout(() => process.exit(0), 100);
    process.exit(0);
  }

  if (timing) {
    console.log(`url:              ${timing.url}`);
    console.log(`dns:              ${ms(timing.dns)}`);
    console.log(`tcp:              ${ms(timing.tcp)}`);
    console.log(`ttfb:             ${ms(timing.ttfb)}`);
    console.log(`response end:     ${ms(timing.responseEnd)}`);
    console.log(`dom interactive:  ${ms(timing.domInteractive)}`);
    console.log(`dom complete:     ${ms(timing.domComplete)}`);
    console.log(`load event:       ${ms(timing.loadEvent)}`);
    if (timing.redirectCount) console.log(`redirects:        ${timing.redirectCount}`);
    if (timing.transferSize) console.log(`transfer size:    ${Math.round(timing.transferSize / 1024)}kb`);
  }

  if (vitals && Object.keys(vitals).length) {
    console.log("---");
    if (vitals.fp  != null) console.log(`first paint:      ${ms(vitals.fp)}`);
    if (vitals.fcp != null) console.log(`FCP:              ${ms(vitals.fcp)}`);
    if (vitals.lcp != null) console.log(`LCP:              ${ms(vitals.lcp)}`);
    if (vitals.cls != null) console.log(`CLS:              ${vitals.cls}`);
  }

  if (metricsMap.JSHeapUsedSize) {
    console.log("---");
    console.log(`js heap used:     ${Math.round(metricsMap.JSHeapUsedSize / 1024 / 1024)}mb`);
    console.log(`js heap total:    ${Math.round(metricsMap.JSHeapTotalSize / 1024 / 1024)}mb`);
    if (metricsMap.LayoutCount) console.log(`layouts:          ${metricsMap.LayoutCount}`);
    if (metricsMap.RecalcStyleCount) console.log(`style recalcs:    ${metricsMap.RecalcStyleCount}`);
  }

  cdp.close();
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
