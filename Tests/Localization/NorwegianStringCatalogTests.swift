@testable import ClerkKitUI
import Foundation
import Testing

struct NorwegianStringCatalogTests {
  private struct Catalog: Decodable {
    let strings: [String: Entry]
  }

  private struct Entry: Decodable {
    let localizations: [String: Localization]?
  }

  private struct Localization: Decodable {
    let stringUnit: StringUnit
  }

  private struct StringUnit: Decodable {
    let state: String
    let value: String
  }

  private static let catalogPaths = [
    "Sources/ClerkKit/Resources/Localizable.xcstrings",
    "Sources/ClerkKitUI/Resources/Localizable.xcstrings",
  ]

  @Test
  func norwegianCatalogsAreCompleteAndPreservePlaceholders() throws {
    for relativePath in Self.catalogPaths {
      let catalog = try loadCatalog(relativePath)

      for (sourceKey, entry) in catalog.strings {
        guard let norwegian = entry.localizations?["nb"]?.stringUnit else {
          Issue.record("Missing nb translation for \(sourceKey) in \(relativePath)")
          continue
        }

        let sourceValue = entry.localizations?["en"]?.stringUnit.value ?? sourceKey
        #expect(
          norwegian.state == "translated",
          "Expected translated state for \(sourceKey) in \(relativePath)"
        )
        #expect(
          try placeholders(in: norwegian.value) == placeholders(in: sourceValue),
          "Printf placeholder mismatch for \(sourceKey) in \(relativePath)"
        )
        #expect(
          try legalConsentTargets(in: norwegian.value) == legalConsentTargets(in: sourceValue),
          "Legal-consent target mismatch for \(sourceKey) in \(relativePath)"
        )
        #expect(
          !norwegian.value.contains("{{"),
          "JavaScript placeholder leaked into \(sourceKey) in \(relativePath)"
        )
      }
    }
  }

  @Test
  func localizedDeleteConfirmationUsesTheDisplayedRequiredWord() throws {
    let catalog = try loadCatalog("Sources/ClerkKitUI/Resources/Localizable.xcstrings")
    let requiredEntry = try #require(catalog.strings["DELETE"])
    let instructionEntry = try #require(catalog.strings["Type \"DELETE\" to continue"])
    var requiredWords = ["en": "DELETE"]
    var instructions = ["en": "Type \"DELETE\" to continue"]

    for (identifier, localization) in requiredEntry.localizations ?? [:] {
      requiredWords[identifier] = localization.stringUnit.value
    }
    for (identifier, localization) in instructionEntry.localizations ?? [:] {
      instructions[identifier] = localization.stringUnit.value
    }

    for (identifier, requiredWord) in requiredWords {
      let locale = Locale(identifier: identifier)
      #expect(instructions[identifier]?.contains(requiredWord) == true, Comment(rawValue: identifier))
      // SwiftPM copies xcstrings as source data on macOS. Xcode compiles them
      // into locale bundles on Apple platform test destinations, where the
      // runtime lookup can be verified directly.
      if DeleteAccountConfirmationInput.localizationBundle.url(
        forResource: "Localizable",
        withExtension: "xcstrings"
      ) == nil {
        #expect(
          DeleteAccountConfirmationInput.requiredValue(locale: locale) == requiredWord,
          Comment(rawValue: identifier)
        )
      }
    }

    #expect(requiredWords["nb"] == "DELETE")
  }

  @Test
  func catalogGuardRecognizesFoundationPlaceholderAndLegalTargetVariants() throws {
    let formatVariants = "%@ %02d %u %1$lu %lld %.2f %%"
    #expect(
      try placeholders(in: formatVariants)
        == ["%@", "%02d", "%u", "%1$lu", "%lld", "%.2f", "%%"].sorted()
    )

    let legalText = "[Terms](LegalConsentView://terms-and_conditions/v2?from=sign_up)"
    #expect(
      try legalConsentTargets(in: legalText)
        == ["LegalConsentView://terms-and_conditions/v2?from=sign_up"]
    )
  }

  private func loadCatalog(_ relativePath: String) throws -> Catalog {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let data = try Data(contentsOf: repositoryRoot.appending(path: relativePath))
    return try JSONDecoder().decode(Catalog.self, from: data)
  }

  private func placeholders(in value: String) throws -> [String] {
    try matches(
      pattern: #"%(?:\d+\$)?[-+# 0',(]*(?:\*|\d+)?(?:\.(?:\*|\d+))?(?:hh|h|ll|l|q|L|z|t|j)?[@a-zA-Z%]"#,
      in: value
    ).sorted()
  }

  private func legalConsentTargets(in value: String) throws -> [String] {
    try matches(pattern: #"LegalConsentView://[^)\s]+"#, in: value).sorted()
  }

  private func matches(pattern: String, in value: String) throws -> [String] {
    let expression = try NSRegularExpression(pattern: pattern)
    let range = NSRange(value.startIndex..., in: value)
    return expression.matches(in: value, range: range).compactMap { match in
      guard let matchRange = Range(match.range, in: value) else { return nil }
      return String(value[matchRange])
    }
  }
}
