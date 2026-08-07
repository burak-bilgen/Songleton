#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Site check failed: $1" >&2
  exit 1
}

command -v node >/dev/null || fail "node is required"
node --check docs/app.js

if rg -q 'class="mac-desktop"|class="scripted-cursor"|class="tour-stage-wrap"' docs/index.html; then
  fail "the legacy scripted macOS scene must not be present (replaced by the card grid in 2026)"
fi
grep -q 'rel="canonical"' docs/index.html || fail "canonical URL is missing"
grep -q 'name="twitter:card"' docs/index.html || fail "social card metadata is missing"
[ -f docs/.nojekyll ] || fail ".nojekyll is missing; GitHub Pages would process the site with Jekyll"
[ -f docs/404.html ] || fail "404.html is missing"
[ -f docs/robots.txt ] || fail "robots.txt is missing"

if rg -n '<(script|style)[^>]*>[[:space:]]*[^<[:space:]]|[[:space:]]on(click|load|error)=' docs/index.html; then
  fail "inline scripts, styles, and event handlers are not allowed"
fi

DOWNLOAD_URL="https://github.com/burak-bilgen/Songleton/releases/latest/download/Songleton.dmg"
if ! rg -q "href=\"${DOWNLOAD_URL}\"" docs/index.html; then
  fail "the macOS download button must target ${DOWNLOAD_URL}"
fi
if rg -q 'href="https://github.com/burak-bilgen/Songleton/releases/latest"' docs/index.html; then
  fail "download links must point at the stable Songleton.dmg asset, not the release page"
fi
rg -q 'aria-label="Download the latest version of Songleton for macOS"' docs/index.html \
  || fail "download buttons must carry the accessibility label"
rg -q 'release-version' docs/index.html || fail "the visible release version badge is missing"

node <<'NODE'
const fs = require("fs");
const vm = require("vm");

const html = fs.readFileSync("docs/index.html", "utf8");
const script = fs.readFileSync("docs/app.js", "utf8");
const match = script.match(/const copy = (\{[\s\S]*?\n\});/);
if (!match) throw new Error("Could not parse website translation dictionary");
const copy = vm.runInNewContext(`(${match[1]})`, Object.create(null));

const referenced = new Set(["pageTitle", "pageDescription"]);
for (const pattern of [/data-i18n="([^"]+)"/g, /data-i18n-label="([^"]+)"/g, /data-i18n-alt="([^"]+)"/g, /data-i18n-title="([^"]+)"/g]) {
  for (const item of html.matchAll(pattern)) referenced.add(item[1]);
}
for (const language of ["tr", "en"]) {
  if (!copy[language]) throw new Error(`Missing ${language} website translations`);
  for (const key of referenced) {
    if (typeof copy[language][key] !== "string" || copy[language][key].trim() === "") {
      throw new Error(`Missing ${language} website translation for ${key}`);
    }
  }
  const unused = Object.keys(copy[language]).filter((key) => !referenced.has(key));
  if (unused.length) throw new Error(`Unused ${language} website translations: ${unused.join(", ")}`);
}

const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map((item) => item[1]);
const duplicateIDs = ids.filter((id, index) => ids.indexOf(id) !== index);
if (duplicateIDs.length) throw new Error(`Duplicate HTML ids: ${[...new Set(duplicateIDs)].join(", ")}`);

for (const item of html.matchAll(/href="#([^"]+)"/g)) {
  if (!ids.includes(item[1])) throw new Error(`Broken fragment link: #${item[1]}`);
}
for (const item of html.matchAll(/<img\s+([^>]+)>/g)) {
  const attributes = item[1];
  const source = attributes.match(/src="([^"]+)"/)?.[1];
  if (!source) throw new Error("Image without a source");
  if (!attributes.includes('width="') || !attributes.includes('height="')) {
    throw new Error(`Image dimensions are missing for ${source}`);
  }
  if (!source.startsWith("http") && !fs.existsSync(`docs/${source}`)) {
    throw new Error(`Missing website asset: ${source}`);
  }
}
NODE

echo "Site guardrails passed."
