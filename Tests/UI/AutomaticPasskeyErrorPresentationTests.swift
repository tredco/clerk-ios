import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct AutomaticPasskeyErrorPresentationTests {
  @Test(arguments: [
    PasskeyAuthenticationFailure.Stage.preparingFirstFactor,
    .requestingAuthorization,
  ])
  func errorsBeforeFirstFactorAttemptAreNotPresented(
    _ stage: PasskeyAuthenticationFailure.Stage
  ) {
    #expect(!AuthStartView.shouldPresentPasskeyError(at: stage, isUserInitiated: false))
  }

  @Test
  func firstFactorAttemptErrorIsPresented() {
    #expect(AuthStartView.shouldPresentPasskeyError(
      at: .attemptingFirstFactor,
      isUserInitiated: false
    ))
  }

  @Test(arguments: [
    PasskeyAuthenticationFailure.Stage.preparingFirstFactor,
    .requestingAuthorization,
    .attemptingFirstFactor,
  ])
  func userInitiatedErrorsArePresented(
    _ stage: PasskeyAuthenticationFailure.Stage
  ) {
    #expect(AuthStartView.shouldPresentPasskeyError(at: stage, isUserInitiated: true))
  }
}
