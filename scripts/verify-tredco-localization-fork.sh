#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$repository_root/TREDCO_LOCALIZATION_BASE.json"
upstream_revision="$({
  python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest_file:
    print(json.load(manifest_file)["upstreamRevision"])
PY
} | tr -d '[:space:]')"

git -C "$repository_root" cat-file -e "$upstream_revision^{commit}"
git -C "$repository_root" merge-base --is-ancestor "$upstream_revision" HEAD

unexpected_paths=()
while IFS= read -r changed_path; do
  case "$changed_path" in
    .github/workflows/checks.yml | \
    TREDCO_LOCALIZATION_BASE.json | \
    TREDCO_NORWEGIAN_LOCALIZATION.md | \
    scripts/verify-tredco-localization-fork.sh | \
    Sources/ClerkKit/Resources/Localizable.xcstrings | \
    Sources/ClerkKitUI/Resources/Localizable.xcstrings | \
    Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView.swift | \
    Sources/ClerkKitUI/Components/Organization/OrganizationPersonalAccountRow.swift | \
    Sources/ClerkKitUI/Components/Organization/OrganizationSwitcherLabel.swift | \
    Sources/ClerkKitUI/Components/Organization/OrganizationAccountListSections.swift | \
    Tests/Localization/NorwegianStringCatalogTests.swift)
      ;;
    *)
      unexpected_paths+=("$changed_path")
      ;;
  esac
done < <(git -C "$repository_root" diff --name-only "$upstream_revision...HEAD")

if (( ${#unexpected_paths[@]} > 0 )); then
  printf 'Unexpected files in the Tredco localization fork:\n' >&2
  printf '  %s\n' "${unexpected_paths[@]}" >&2
  exit 1
fi

printf 'Tredco localization fork is scoped to approved paths from %s.\n' "$upstream_revision"
