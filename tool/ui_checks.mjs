#!/usr/bin/env node
// UI revamp checks for the car HTML pages. No dependencies.
// Usage: node tool/ui_checks.mjs [--base <commit>] [file.html ...]
// Exit 0 = every check passed.
import { readFileSync, readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const assets = "android/app/src/main/assets";
const args = process.argv.slice(2);
let base = "7be55d7";
const files = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--base") base = args[++i];
  else files.push(args[i].includes("/") ? args[i] : `${assets}/${args[i]}`);
}
if (!files.length) {
  for (const f of readdirSync(join(root, assets))) if (f.endsWith(".html")) files.push(`${assets}/${f}`);
}

const tokens = JSON.parse(readFileSync(join(root, "design/tokens.json"), "utf8"));
let failures = 0;
const fail = (file, check, msg) => { failures++; console.log(`FAIL ${check.padEnd(10)} ${file}: ${msg}`); };
const pass = (file, check) => console.log(`pass ${check.padEnd(10)} ${file}`);

function signature(src) {
  const sets = { ids: new Set(), data: new Set(), fns: new Set(), globals: new Set(), bridge: new Set() };
  for (const m of src.matchAll(/\bid\s*=\s*["']([^"'$+{}\s]+)["']/g)) sets.ids.add(m[1]);
  for (const m of src.matchAll(/\bdata-([a-z][a-z0-9-]*)/g)) sets.data.add(m[1]);
  for (const m of src.matchAll(/\bfunction\s+([A-Za-z_$][\w$]*)\s*\(/g)) sets.fns.add(m[1]);
  for (const m of src.matchAll(/\bwindow\.([A-Za-z_$][\w$]*)\s*=(?!=)/g)) sets.globals.add(m[1]);
  for (const m of src.matchAll(/\b(AutoDeck|AutoDeckWeb|DashMateBridge|DashMateRadio)\.([A-Za-z_$][\w$]*)/g)) sets.bridge.add(`${m[1]}.${m[2]}`);
  return sets;
}

function lum(hex) {
  const c = hex.replace("#", "").match(/../g).map(h => parseInt(h, 16) / 255)
    .map(v => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };

// Palette contrast (independent of files).
for (const theme of ["light", "dark"]) {
  const t = tokens[theme];
  const pairs = [
    ["ink", "bg", 4.5], ["ink", "surface", 4.5], ["ink", "surface2", 4.5],
    ["ink2", "bg", 4.5], ["ink2", "surface", 4.5], ["ink2", "surface2", 4.5],
    ["ink3", "surface", 3], ["onAccent", "accent", 4.5], ["danger", "surface", 4.5], ["accent", "surface", 3],
  ];
  const bad = pairs.filter(([f, b, min]) => ratio(t[f], t[b]) < min)
    .map(([f, b, min]) => `${f} on ${b} = ${ratio(t[f], t[b]).toFixed(2)} (< ${min})`);
  bad.length ? fail(`tokens.${theme}`, "contrast", bad.join("; ")) : pass(`tokens.${theme}`, "contrast");
}

for (const file of files) {
  const now = readFileSync(join(root, file), "utf8");
  let before = null;
  try { before = execFileSync("git", ["show", `${base}:${file}`], { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }); }
  catch { /* new file: no parity check */ }

  if (before) {
    const a = signature(before), b = signature(now);
    const missing = [];
    for (const k of Object.keys(a)) for (const v of a[k]) if (!b[k].has(v)) missing.push(`${k}:${v}`);
    missing.length ? fail(file, "parity", `missing ${missing.join(", ")}`) : pass(file, "parity");
  }

  /backdrop-filter/i.test(now) ? fail(file, "no-blur", "backdrop-filter still used") : pass(file, "no-blur");

  const hook = now.includes("window.ddTheme=") || now.includes("window.ddTheme =");
  const dark = /:root\[data-theme=["']dark["']\]/.test(now);
  hook && dark ? pass(file, "theme-hook") : fail(file, "theme-hook", `${hook ? "" : "no window.ddTheme hook; "}${dark ? "" : 'no :root[data-theme="dark"] block'}`);

  const lower = now.toLowerCase();
  const absent = [];
  for (const theme of ["light", "dark"]) for (const [k, v] of Object.entries(tokens[theme])) {
    if (!lower.includes(v.toLowerCase())) absent.push(`${theme}.${k}`);
  }
  absent.length ? fail(file, "tokens", `palette values not found: ${absent.join(", ")}`) : pass(file, "tokens");
}

console.log(failures ? `\n${failures} check(s) failed` : "\nAll checks passed");
process.exit(failures ? 1 : 0);
