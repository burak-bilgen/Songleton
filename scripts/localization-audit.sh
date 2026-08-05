#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Localization check failed: $1" >&2
  exit 1
}

command -v jq >/dev/null || fail "jq is required"
jq empty Songleton/Localizable.xcstrings Songleton/InfoPlist.xcstrings

if ! jq -e '
  all(.strings[] | select(.localizations != null);
    all(.localizations[]; (.stringUnit.value // "") != "" and .stringUnit.state == "translated")
  )
' Songleton/InfoPlist.xcstrings >/dev/null; then
  fail "every localized Info.plist value must be complete and translated"
fi

if ! jq -e '
  all(.strings | to_entries[];
    .value.extractionState == "manual"
    and (.value.localizations.en.stringUnit.value // "") != ""
    and (.value.localizations.tr.stringUnit.value // "") != ""
    and .value.localizations.en.stringUnit.state == "translated"
    and .value.localizations.tr.stringUnit.state == "translated"
  )
' Songleton/Localizable.xcstrings >/dev/null; then
  fail "every app string must have complete manual English and Turkish translations"
fi

if rg -n --glob '*.swift' \
  '(Text|Button|Label|Toggle|Picker|Section|Menu|Link|GroupBox)\([[:space:]]*"[^"]+"|\.help\([[:space:]]*"[^"]+"|\.accessibility(Label|Hint|Value)\([[:space:]]*"[^"]+"|NSMenuItem\([[:space:]]*title:[[:space:]]*"[^"]+"' \
  Songleton; then
  fail "user-facing SwiftUI and accessibility strings must use localization keys or Text(verbatim:)"
fi

audit_dir="$(mktemp -d)"
trap 'rm -rf "${audit_dir}"' EXIT

jq -r '.strings | keys[]' Songleton/Localizable.xcstrings | sort -u > "${audit_dir}/catalog-keys"
{
  rg -o --no-filename '"[a-z][a-z0-9_]*(\.[A-Za-z0-9_]+)+"' Songleton --glob '*.swift' | tr -d '"'
  for position in topLeading top topTrailing leading trailing bottomLeading bottom bottomTrailing; do
    echo "settings.notification_position.${position}"
  done
} | sort -u > "${audit_dir}/source-keys"

{
  rg -oP --no-filename '(?:localization|LocalizationManager\.shared)\.string\("\K[^"]+' Songleton --glob '*.swift'
  rg -oP --no-filename 'gestureDescription\("\K[^"]+' Songleton --glob '*.swift'
  rg -oP --no-filename 'localizedString\(forKey:[[:space:]]*"\K[^"]+' Songleton --glob '*.swift'
  for position in topLeading top topTrailing leading trailing bottomLeading bottom bottomTrailing; do
    echo "settings.notification_position.${position}"
  done
} | sort -u > "${audit_dir}/requested-keys"

if comm -23 "${audit_dir}/catalog-keys" "${audit_dir}/source-keys" | grep -q .; then
  comm -23 "${audit_dir}/catalog-keys" "${audit_dir}/source-keys" >&2
  fail "catalog contains keys that are no longer referenced"
fi

if comm -13 "${audit_dir}/catalog-keys" "${audit_dir}/requested-keys" | grep -q .; then
  comm -13 "${audit_dir}/catalog-keys" "${audit_dir}/requested-keys" >&2
  fail "source code requests localization keys that are missing from the catalog"
fi

echo "Localization guardrails passed."
