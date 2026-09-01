# Tredco iOS Clerk fork

This branch adds Norwegian Bokmål (`nb`) to the two Clerk string catalogs. Its locale source changes are limited to propagation inside ClerkKitUI, including runtime-formatted country names and relative dates. It also carries one narrowly scoped authentication UI patch: the prebuilt `AuthView` honors Clerk's dashboard-controlled passkey `show_sign_in_button` setting. It does not change session, storage, or network behavior.

## Upstream base

- Clerk iOS release: `1.5.1`
- Upstream commit: `1b58165de0b6519ed3fb226f41763b354bca95d5`
- Fork branch: `tredco/nb-NO-1.5.1`

`TREDCO_LOCALIZATION_BASE.json` is the machine-readable source of these revisions. The localization workflow runs `scripts/verify-tredco-localization-fork.sh` to reject changes outside the approved catalogs, tests, documentation, workflow, narrowly scoped ClerkKitUI locale fixes, and passkey-button patch.
- Clerk JavaScript localization terminology seed: `8c60f772aa7df3a5493fbabdbf20174cd503df46`

The JavaScript `en-US`/`nb-NO` pair was used only as a terminology seed where the native meaning matched. Every native string was reviewed, and native-specific wording and corrections were applied manually.

The localized catalogs are:

- `Sources/ClerkKit/Resources/Localizable.xcstrings`
- `Sources/ClerkKitUI/Resources/Localizable.xcstrings`

The localization support patches are:

- pass the SwiftUI environment locale to five organization-label lookups that otherwise use the device locale;
- format phone-country names and device/passkey relative dates with the SwiftUI environment locale;
- validate account deletion with the same localized `DELETE` value shown by the selected app locale.

The passkey patch renders the existing localized “Sign in with your passkey” action when passkeys are enabled as a first factor and the dashboard requests a dedicated button. It uses the full interactive credential selector, remains hidden in sign-up-only and locked-identifier flows, and leaves automatic passkey and AutoFill behavior unchanged.

## Updating Clerk

1. Fetch the new Clerk tag from `upstream` and create a new `tredco/nb-NO-<version>` branch from that tag.
2. Replay the Norwegian localization commits. Resolve catalog conflicts by keeping all upstream keys and languages, then adding the `nb` string unit beside them. Recheck whether upstream still needs the locale-propagation and deletion-confirmation patches before carrying them forward.
3. Check whether upstream's prebuilt `AuthView` now honors `show_sign_in_button`. Drop Tredco's passkey source and tests if it does; otherwise replay the small patch and its UI tests.
4. Translate every new source key into Norwegian Bokmål. Keep printf/Swift placeholders such as `%@` and `%lld` unchanged, including their count. Keep `LegalConsentView://` link targets unchanged.
5. Run `swift test --filter NorwegianStringCatalogTests`. The completeness test fails if either catalog has a key without an `nb` translation, if placeholders or legal-link targets differ, or if a deletion instruction disagrees with its accepted localized value. Pushing a `tredco/nb-NO-*` branch also runs the fork's full shared checks workflow.
6. Review the changed screens on an iOS simulator set to Norwegian Bokmål. At minimum, cover sign-in, verification, password recovery, account security, profile editing, and account deletion. Exercise the passkey action on a physical device when that patch remains necessary.
7. Pin Tredco's Swift package dependency to the reviewed fork commit and rebuild the native app.

Do not copy translations from Clerk's JavaScript catalog without review. It is a useful terminology reference, but native keys can have different context and the community catalog can lag or contain mismatched values.

### Translation exception: `DELETE`

Keep the Norwegian `DELETE` confirmation value and the word in `Type "DELETE" to continue` untranslated. Other Clerk locales retain their existing translated required words. ClerkKitUI 1.5.1 originally validated the entered value with a device-locale bundle lookup, which could disagree with Tredco's selected app locale. The fork passes the SwiftUI environment locale to both display and validation, and the catalog test locks every language's instruction and accepted value together.
