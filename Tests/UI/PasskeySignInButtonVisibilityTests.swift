@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct PasskeySignInButtonVisibilityTests {
  private func environment(
    passkeyIsFirstFactor: Bool = true,
    showSignInButton: Bool
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["passkey"] = .init(
      enabled: true,
      required: false,
      usedForFirstFactor: passkeyIsFirstFactor,
      firstFactors: passkeyIsFirstFactor ? ["passkey"] : [],
      usedForSecondFactor: false,
      secondFactors: [],
      verifications: ["passkey"],
      verifyAtSignUp: false
    )
    environment.userSettings.passkeySettings = .init(
      allowAutofill: false,
      showSignInButton: showSignInButton
    )
    return environment
  }

  @Test
  func visibleInSignInModeWhenEnabled() {
    #expect(AuthStartView.shouldShowPasskeySignInButton(
      environment: environment(showSignInButton: true),
      mode: .signIn,
      lockedInitialIdentifierIsActive: false
    ))
  }

  @Test
  func visibleInSignInOrUpModeWhenEnabled() {
    #expect(AuthStartView.shouldShowPasskeySignInButton(
      environment: environment(showSignInButton: true),
      mode: .signInOrUp,
      lockedInitialIdentifierIsActive: false
    ))
  }

  @Test
  func hiddenWhenDashboardSettingIsDisabled() {
    #expect(!AuthStartView.shouldShowPasskeySignInButton(
      environment: environment(showSignInButton: false),
      mode: .signIn,
      lockedInitialIdentifierIsActive: false
    ))
  }

  @Test
  func hiddenInSignUpMode() {
    #expect(!AuthStartView.shouldShowPasskeySignInButton(
      environment: environment(showSignInButton: true),
      mode: .signUp,
      lockedInitialIdentifierIsActive: false
    ))
  }

  @Test
  func hiddenWhenPasskeysAreRegistrationOnly() {
    #expect(!AuthStartView.shouldShowPasskeySignInButton(
      environment: environment(
        passkeyIsFirstFactor: false,
        showSignInButton: true
      ),
      mode: .signIn,
      lockedInitialIdentifierIsActive: false
    ))
  }

  @Test
  func hiddenForALockedPrefilledIdentifier() {
    #expect(!AuthStartView.shouldShowPasskeySignInButton(
      environment: environment(showSignInButton: true),
      mode: .signIn,
      lockedInitialIdentifierIsActive: true
    ))
  }
}
