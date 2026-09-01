#if os(iOS)

@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct ClerkPhoneNumberFieldTests {
  @Test
  func e164InputPreservesDataValueAndUpdatesCountry() {
    let model = ClerkPhoneNumberField.PhoneNumberModel()

    let formattedText = model.formattedText(for: "+447911123456")

    #expect(formattedText.dataText == "+447911123456")
    #expect(model.currentCountry.prefix == "+44")
  }

  @Test
  func countryNamesFollowTheInjectedLocale() throws {
    let model = ClerkPhoneNumberField.PhoneNumberModel()
    let locale = Locale(identifier: "nb_NO")
    let germany = try #require(
      model.allCountriesExceptDefault(locale: locale).first { $0.code == "DE" }
    )

    #expect(model.stringForCountry(germany, locale: locale).contains("Tyskland"))
  }

  @Test
  func relativeDatesFollowTheInjectedLocale() {
    let oneHourAgo = Date(timeIntervalSinceNow: -3600)

    #expect(oneHourAgo.relativeNamedFormat(locale: Locale(identifier: "nb_NO")).contains("siden"))
  }
}

#endif
