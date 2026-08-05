#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Security check failed: $1" >&2
  exit 1
}

echo "Running security guardrails..."

plutil -lint Songleton/Songleton.entitlements Songleton/Debug.entitlements >/dev/null

grep -q 'ENABLE_HARDENED_RUNTIME = YES;' Songleton.xcodeproj/project.pbxproj \
  || fail "Hardened Runtime must remain enabled"
grep -q 'DEAD_CODE_STRIPPING = YES;' Songleton.xcodeproj/project.pbxproj \
  || fail "Release dead-code stripping must remain enabled"
grep -q 'SWIFT_STRICT_CONCURRENCY = complete;' Songleton.xcodeproj/project.pbxproj \
  || fail "Complete Swift concurrency checking must remain enabled"
grep -q 'SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;' Songleton.xcodeproj/project.pbxproj \
  || fail "Compiler warnings must remain release blockers"

if rg -n 'uses:[[:space:]]+[^[:space:]#]+@(v[0-9]+|main|master)([[:space:]]|$)' .github/workflows; then
  fail "GitHub Actions must use full commit SHAs"
fi

if rg -n 'sha256[[:space:]]+:no_check' homebrew-tap/Casks --glob '*.rb'; then
  fail "Homebrew artifacts must never disable checksum verification"
fi

cask_checksum="$(sed -nE 's/^[[:space:]]*sha256 "([0-9a-f]{64})"/\1/p' homebrew-tap/Casks/songleton.rb)"
[[ ${#cask_checksum} -eq 64 ]] || fail "Homebrew checksum must be a 64-character SHA-256"

release_entitlements="$(plutil -convert json -o - Songleton/Songleton.entitlements)"
for forbidden in \
  com.apple.security.get-task-allow \
  com.apple.security.cs.allow-dyld-environment-variables \
  com.apple.security.cs.disable-library-validation \
  com.apple.security.cs.allow-unsigned-executable-memory \
  com.apple.security.cs.disable-executable-page-protection; do
  if grep -q "${forbidden}" <<<"${release_entitlements}"; then
    fail "Forbidden release entitlement present: ${forbidden}"
  fi
done

grep -q 'http-equiv="Content-Security-Policy"' docs/index.html \
  || fail "Website must define a Content Security Policy"

if rg -n '\.innerHTML[[:space:]]*=' docs --glob '*.js'; then
  fail "Website scripts must not assign HTML strings to the DOM"
fi

if rg -n 'NSAllowsArbitraryLoads|NSExceptionAllowsInsecureHTTPLoads' Songleton Songleton.xcodeproj --glob '!**/*.xcstrings'; then
  fail "ATS exceptions require an explicit security review"
fi

echo "Security guardrails passed."
