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
  func localizedDeleteConfirmationUsesTheSameRequiredWord() throws {
    let catalog = try loadCatalog("Sources/ClerkKitUI/Resources/Localizable.xcstrings")
    let requiredWord = catalog.strings["DELETE"]?.localizations?["nb"]?.stringUnit.value
    let instruction = catalog.strings["Type \"DELETE\" to continue"]?
      .localizations?["nb"]?.stringUnit.value

    // This must remain language-neutral. ClerkKitUI 1.5.1 validates the input
    // without passing the SwiftUI environment locale, so translating the
    // required word can make the displayed instruction and validation differ.
    #expect(requiredWord == "DELETE")
    #expect(instruction?.contains("DELETE") == true)
    #expect(DeleteAccountConfirmationInput.requiredValue == "DELETE")
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
    try matches(pattern: #"%(?:\d+\$)?(?:@|lld|ld|d|f|s)"#, in: value).sorted()
  }

  private func legalConsentTargets(in value: String) throws -> [String] {
    try matches(pattern: #"LegalConsentView://[a-z]+"#, in: value).sorted()
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
