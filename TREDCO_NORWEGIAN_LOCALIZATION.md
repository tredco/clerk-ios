# Tredco Norwegian localization

This branch adds Norwegian Bokmål (`nb`) to the two Clerk string catalogs. Its source changes are limited to locale propagation inside ClerkKitUI and a locale-independent account-deletion confirmation. It does not change authentication, session, storage, or network behavior.

## Upstream base

- Clerk iOS release: `1.5.1`
- Upstream commit: `1b58165de0b6519ed3fb226f41763b354bca95d5`
- Fork branch: `tredco/nb-NO-1.5.1`

`TREDCO_LOCALIZATION_BASE.json` is the machine-readable source of these revisions. The localization workflow runs `scripts/verify-tredco-localization-fork.sh` to reject changes outside the approved catalogs, tests, documentation, workflow, and narrowly scoped ClerkKitUI locale fixes.
- Clerk JavaScript localization terminology seed: `8c60f772aa7df3a5493fbabdbf20174cd503df46`

The JavaScript `en-US`/`nb-NO` pair was used only as a terminology seed where the native meaning matched. Every native string was reviewed, and native-specific wording and corrections were applied manually.

The localized catalogs are:

- `Sources/ClerkKit/Resources/Localizable.xcstrings`
- `Sources/ClerkKitUI/Resources/Localizable.xcstrings`

The localization support patches are:

- pass the SwiftUI environment locale to five organization-label lookups that otherwise use the device locale;
- validate account deletion against Clerk's documented literal `DELETE` so the selected app locale and device locale cannot disagree.

## Updating Clerk

1. Fetch the new Clerk tag from `upstream` and create a new `tredco/nb-NO-<version>` branch from that tag.
2. Replay the Norwegian localization commits. Resolve catalog conflicts by keeping all upstream keys and languages, then adding the `nb` string unit beside them. Recheck whether upstream still needs the locale-propagation and deletion-confirmation patches before carrying them forward.
3. Translate every new source key into Norwegian Bokmål. Keep printf/Swift placeholders such as `%@` and `%lld` unchanged, including their count. Keep `LegalConsentView://` link targets unchanged.
4. Run `swift test --filter NorwegianStringCatalogTests`. The completeness test fails if either catalog has a key without an `nb` translation or if placeholders differ. Pushing a `tredco/nb-NO-*` branch also runs the fork's full shared checks workflow.
5. Review the changed screens on an iOS simulator set to Norwegian Bokmål. At minimum, cover sign-in, verification, password recovery, account security, profile editing, and account deletion.
6. Pin Tredco's Swift package dependency to the reviewed fork commit and rebuild the native app.

Do not copy translations from Clerk's JavaScript catalog without review. It is a useful terminology reference, but native keys can have different context and the community catalog can lag or contain mismatched values.

### Translation exception: `DELETE`

Keep the `DELETE` confirmation value and the word in `Type "DELETE" to continue` untranslated. ClerkKitUI 1.5.1 originally validated the entered value with a device-locale bundle lookup, which could disagree with Tredco's selected app locale. The fork validates against the literal `DELETE`, and the catalog test locks the instruction and required value together until upstream makes the validation locale-aware.
