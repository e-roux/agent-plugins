#!/usr/bin/env node

/**
 * Dump the accessibility tree for the current page.
 * Uses CDP Accessibility.getFullAXTree to reveal aria roles, labels, and states.
 * Essential for debugging screen-reader behaviour and aria attribute correctness.
 *
 * Usage:
 *   ./a11y.js                      # Full tree
 *   ./a11y.js --selector 'main'    # Subtree rooted at CSS selector
 *   ./a11y.js --json               # Raw JSON output
 *   ./a11y.js --roles button,link  # Filter to specific roles (comma-separated)
 */

import { connect } from "./cdp.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const jsonMode = process.argv.includes("--json");

const selIdx = process.argv.indexOf("--selector");
const selector = selIdx !== -1 ? process.argv[selIdx + 1] : null;

const rolesIdx = process.argv.indexOf("--roles");
const filterRoles = rolesIdx !== -1
  ? new Set(process.argv[rolesIdx + 1].split(",").map((r) => r.trim()))
  : null;

const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (20s)");
  process.exit(1);
}, 20000);

function val(v) {
  if (!v) return null;
  if (v.type === "string" || v.type === "boolean" || v.type === "integer") return v.value;
  if (v.type === "computedString") return v.value;
  return v.value ?? null;
}

function printNode(node, indent = 0) {
  const role = val(node.role);
  const skip = !role || role === "none" || role === "generic" || role === "InlineTextBox";

  if (!skip) {
    if (filterRoles && !filterRoles.has(role)) {
      for (const child of node.children ?? []) printNode(child, indent);
      return;
    }

    const name = val(node.name);
    const desc = val(node.description);
    const value = val(node.value);

    const parts = [role];
    if (name) parts.push(`"${name}"`);
    if (desc && desc !== name) parts.push(`desc="${desc}"`);
    if (value) parts.push(`value="${value}"`);

    const states = (node.properties ?? [])
      .filter((p) => p.value?.value === true)
      .map((p) => p.name);
    if (states.length) parts.push(`[${states.join(",")}]`);

    console.log(" ".repeat(indent * 2) + parts.join(" "));
  }

  // Always walk children — "none"/"generic" wrappers are transparent
  for (const child of node.children ?? []) printNode(child, skip ? indent : indent + 1);
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

  let backendNodeId;
  if (selector) {
    log("resolving selector...");
    const result = await cdp.send("Runtime.evaluate", {
      expression: `document.querySelector(${JSON.stringify(selector)})`,
      returnByValue: false,
    }, sessionId);
    if (!result.result?.objectId) {
      console.error(`✗ Selector not found: ${selector}`);
      process.exit(1);
    }
    const { node } = await cdp.send("DOM.describeNode", {
      objectId: result.result.objectId,
    }, sessionId);
    backendNodeId = node.backendNodeId;
  }

  log("fetching accessibility tree...");
  const { nodes } = await cdp.send(
    "Accessibility.getFullAXTree",
    {},  // Always fetch full tree; filter by backendNodeId below if selector given
    sessionId,
    15000,
  );

  if (jsonMode) {
    const filtered = backendNodeId
      ? (() => {
          const root = nodes.find((n) => n.backendDOMNodeId === backendNodeId);
          if (!root) return nodes;
          const ids = new Set();
          const collect = (id) => { ids.add(id); nodes.find(n=>n.nodeId===id)?.childIds?.forEach(collect); };
          collect(root.nodeId);
          return nodes.filter(n => ids.has(n.nodeId));
        })()
      : nodes;
    console.log(JSON.stringify(filtered, null, 2));
    cdp.close();
    clearTimeout(globalTimeout);
    setTimeout(() => process.exit(0), 100);
    process.exit(0); // handled in finally
  }

  // Build parent→children map
  const nodeMap = new Map(nodes.map((n) => [n.nodeId, { ...n, children: [] }]));
  for (const n of nodes) {
    for (const childId of n.childIds ?? []) {
      if (nodeMap.has(childId)) nodeMap.get(n.nodeId).children.push(nodeMap.get(childId));
    }
  }

  // Find print root: the AX node matching backendNodeId, or the document root
  let printRoot;
  if (backendNodeId) {
    const matchNode = nodes.find((n) => n.backendDOMNodeId === backendNodeId);
    printRoot = matchNode ? nodeMap.get(matchNode.nodeId) : null;
  }
  if (!printRoot) {
    // Fall back to topmost node (has no parent in the set)
    const childIds = new Set(nodes.flatMap((n) => n.childIds ?? []));
    const roots = nodes.filter((n) => !childIds.has(n.nodeId));
    for (const root of roots) printNode(nodeMap.get(root.nodeId));
    cdp.close();
    clearTimeout(globalTimeout);
    setTimeout(() => process.exit(0), 100);
    process.exit(0);
  }
  printNode(printRoot);

  cdp.close();
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
