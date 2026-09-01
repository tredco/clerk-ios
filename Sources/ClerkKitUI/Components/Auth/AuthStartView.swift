//
//  AuthStartView.swift
//  Clerk
//

// swiftlint:disable file_length

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct AuthStartView: View {
  // MARK: - Environment

  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState
  @Environment(\.authFlowRequestOwnerId) private var authFlowRequestOwnerId
  @Environment(\.dismissKeyboard) private var dismissKeyboard

  // MARK: - State

  @State private var fieldError: Error?
  @State private var generalError: Error?
  @State private var automaticPasskeySignInTask: Task<Void, Never>?
  @State private var automaticPasskeySignInTaskGeneration = 0
  @State private var automaticPasskeySignInRestartID = 0
  @State private var automaticPasskeySignInHasStarted = false
  @State private var authStartOperation = AuthStartOperation()
  @State private var biometricCredentialAvailability: BiometricCredentialAvailability?
  @State private var biometryDisplayName: BiometryDisplayName?

  // MARK: - Configuration

  var emailIsEnabled: Bool {
    clerk.environment?.enabledFirstFactorAttributes
      .contains("email_address") ?? false
  }

  var usernameIsEnabled: Bool {
    clerk.environment?.enabledFirstFactorAttributes
      .contains("username") ?? false
  }

  var phoneNumberIsEnabled: Bool {
    clerk.environment?.enabledFirstFactorAttributes
      .contains("phone_number") ?? false
  }

  var phoneNumberFieldIsActive: Bool {
    authState.authStartPhoneNumberFieldIsActive
  }

  var showIdentifierField: Bool {
    emailIsEnabled || usernameIsEnabled || phoneNumberIsEnabled
  }

  var showIdentifierSwitcher: Bool {
    (emailIsEnabled || usernameIsEnabled) && phoneNumberIsEnabled
  }

  var showOrDivider: Bool {
    hasAlternativeAuthMethods && showIdentifierField
  }

  var phoneNumberInputIsActive: Bool {
    phoneNumberIsEnabled && (phoneNumberFieldIsActive || !(emailIsEnabled || usernameIsEnabled))
  }

  var activeIdentifier: String {
    phoneNumberInputIsActive ? authState.authStartPhoneNumber : authState.authStartIdentifier
  }

  var shouldStartOnPhoneNumber: Bool {
    guard phoneNumberIsEnabled else { return false }

    if !(emailIsEnabled || usernameIsEnabled) {
      return true
    }

    if !authState.authStartPhoneNumber.isEmpty, authState.authStartIdentifier.isEmpty {
      return true
    }

    return false
  }

  var passkeySignInIsAvailable: Bool {
    passkeySignInIsAvailable(environment: clerk.environment)
  }

  var shouldShowPasskeySignInButton: Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    Self.shouldShowPasskeySignInButton(
      environment: clerk.environment,
      mode: authState.mode,
      lockedInitialIdentifierIsActive: lockedInitialIdentifierIsActive
    )
    #else
    false
    #endif
  }

  static func shouldShowPasskeySignInButton(
    environment: Clerk.Environment?,
    mode: AuthView.Mode,
    lockedInitialIdentifierIsActive: Bool
  ) -> Bool {
    guard mode != .signUp, !lockedInitialIdentifierIsActive else { return false }
    return environment?.passkeyFirstFactorIsEnabled == true &&
      environment?.userSettings.passkeySettings?.showSignInButton == true
  }

  func passkeySignInIsAvailable(environment: Clerk.Environment?) -> Bool {
    switch authState.mode {
    case .signIn, .signInOrUp:
      environment?.passkeyFirstFactorIsEnabled == true &&
        !lockedInitialIdentifierIsActive
    case .signUp:
      false
    }
  }

  var lockedInitialIdentifierIsActive: Bool {
    authState.prefilledFieldsAreLocked && authState.hasInitialIdentifier
  }

  func passkeyAutomaticModalIsEnabled(environment: Clerk.Environment) -> Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    // Clerk's AutoFill setting controls the no-interaction modal, not iOS's text-field AutoFill request.
    return passkeySignInIsAvailable(environment: environment) &&
      environment.userSettings.passkeySettings?.allowAutofill == true
    #else
    false
    #endif
  }

  var passkeySignInIsEnabled: Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    passkeySignInIsAvailable
    #else
    false
    #endif
  }

  var passkeySignInTaskIsEnabled: Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    passkeySignInIsEnabled && navigation.path.isEmpty
    #else
    false
    #endif
  }

  var passkeyAutoFillFallbackIsEnabled: Bool {
    passkeyAutoFillFallbackIsEnabled(environment: clerk.environment)
  }

  func passkeyAutoFillFallbackIsEnabled(environment: Clerk.Environment?) -> Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    let enabledAttributes = environment?.enabledFirstFactorAttributes ?? []
    return passkeySignInIsAvailable(environment: environment) &&
      !phoneNumberInputIsActive &&
      (enabledAttributes.contains("email_address") || enabledAttributes.contains("username"))
    #else
    false
    #endif
  }

  private var passkeySignInTaskID: PasskeySignInTaskID? {
    guard passkeySignInTaskIsEnabled, let authFlowRequestOwnerId else {
      return nil
    }

    return PasskeySignInTaskID(
      restartId: automaticPasskeySignInRestartID,
      ownerId: authFlowRequestOwnerId
    )
  }

  private var socialProvidersMinusLastUsed: [OAuthProvider] {
    guard let lastUsedSocialProvider = lastUsedAuth?.socialProvider else { return socialProviders }
    return socialProviders.filter { $0 != lastUsedSocialProvider }
  }

  private var socialProviders: [OAuthProvider] {
    clerk.environment?.authenticatableSocialProviders ?? []
  }

  private var lastUsedAuth: LastUsedAuth? {
    guard authState.persistsIdentifiers else { return nil }
    return LastUsedAuth(
      environment: clerk.environment,
      biometricSignInIsVisible: shouldShowBiometricSignIn
    )
  }

  private var hasSocialProviders: Bool {
    !(clerk.environment?.authenticatableSocialProviders ?? []).isEmpty
  }

  private var hasAlternativeAuthMethods: Bool {
    shouldShowPasskeySignInButton || hasSocialProviders || shouldShowBiometricSignIn
  }

  // MARK: - Display Strings

  private var titleString: LocalizedStringKey {
    switch authState.mode {
    case .signIn, .signInOrUp:
      if let appName = clerk.environment?.displayConfig.applicationName {
        "Continue to \(appName)"
      } else {
        "Continue"
      }
    case .signUp:
      "Create your account"
    }
  }

  private var subtitleString: LocalizedStringKey {
    switch authState.mode {
    case .signIn, .signInOrUp:
      "Welcome! Sign in to continue"
    case .signUp:
      "Welcome! Please fill in the details to get started."
    }
  }

  private var identifierSwitcherString: LocalizedStringKey {
    if phoneNumberFieldIsActive {
      if emailIsEnabled, usernameIsEnabled {
        "Use email address or username"
      } else if emailIsEnabled {
        "Use email address"
      } else if usernameIsEnabled {
        "Use username"
      } else {
        ""
      }
    } else {
      "Use phone number"
    }
  }

  private var emailOrUsernamePlaceholder: LocalizedStringKey {
    switch (emailIsEnabled, usernameIsEnabled) {
    case (true, false):
      "Enter your email"
    case (false, true):
      "Enter your username"
    default:
      "Enter your email or username"
    }
  }

  // MARK: - Body

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()

        headerSection

        VStack(spacing: 24) {
          if showIdentifierField {
            identifierInputSection

            continueButton

            if showIdentifierSwitcher {
              identifierSwitcherButton
            }
          }

          if showOrDivider {
            TextDivider(string: "or")
          }

          if hasAlternativeAuthMethods {
            alternativeAuthMethodsSection
          }
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    #if os(iOS)
    .scrollDismissesKeyboard(.interactively)
    #endif
    .clerkErrorPresenting($generalError)
    .background(theme.colors.background)
    .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
      $1 != nil
    }
    .onFirstAppear {
      if authState.hasInitialIdentifier {
        authState.authStartPhoneNumberFieldIsActive = shouldStartOnPhoneNumber
      } else if shouldStartOnPhoneNumber {
        authState.authStartPhoneNumberFieldIsActive = true
      }
    }
    .onDisappear {
      cancelAuthStartOperation()
    }
    #if os(iOS) && !targetEnvironment(macCatalyst)
    .task(id: passkeySignInTaskID) {
      guard let passkeySignInTaskID else { return }
      let includeAutomaticModal = !automaticPasskeySignInHasStarted
      automaticPasskeySignInTaskGeneration += 1
      let taskGeneration = automaticPasskeySignInTaskGeneration
      let task = Task {
        await AuthFlowRequestScope.withOwner(passkeySignInTaskID.ownerId) {
          await startPasskeySignIn(includeAutomaticModal: includeAutomaticModal)
        }
      }
      automaticPasskeySignInTask = task
      await withTaskCancellationHandler {
        await task.value
      } onCancel: {
        task.cancel()
      }
      if automaticPasskeySignInTaskGeneration == taskGeneration {
        automaticPasskeySignInTask = nil
      }
    }
    .onChange(of: clerk.environmentRefreshCheckpoint) { _, _ in
      restartAutomaticPasskeySignInAfterEnvironmentRefreshIfNeeded()
    }
    #endif
    .task(id: biometricCredentialAvailabilityRefreshState) {
      await refreshBiometricCredentialAvailability()
    }
  }
}

private struct PasskeySignInTaskID: Equatable {
  let restartId: Int
  let ownerId: UUID
}

enum AuthStartBiometricCredentialRefreshState: Equatable {
  case disabled
  case signedOut(clientID: String?)

  static func state(
    biometricCredentialFeatureIsEnabled: Bool,
    activeSessionID: String?,
    clientID: String?
  ) -> Self {
    guard biometricCredentialFeatureIsEnabled else {
      return .disabled
    }
    guard activeSessionID == nil else {
      return .disabled
    }
    return .signedOut(clientID: clientID)
  }
}

extension AuthStartView {
  private var biometricCredentialFeatureIsEnabled: Bool {
    guard let nativeSettings = clerk.environment?.authConfig.nativeSettings else {
      return false
    }

    return nativeSettings.apiEnabled &&
      nativeSettings.biometricSignInEnabled
  }

  private var shouldShowBiometricSignIn: Bool {
    biometricCredentialFeatureIsEnabled &&
      authState.mode != .signUp &&
      biometricCredentialAvailability?.isAvailable == true &&
      biometryDisplayName?.isSupported == true
  }

  private var biometricCredentialAvailabilityRefreshState: AuthStartBiometricCredentialRefreshState {
    .state(
      biometricCredentialFeatureIsEnabled: biometricCredentialFeatureIsEnabled,
      activeSessionID: clerk.session?.status == .active ? clerk.session?.id : nil,
      clientID: clerk.client?.id
    )
  }
}

// MARK: - Subviews

extension AuthStartView {
  private var headerSection: some View {
    VStack(spacing: 8) {
      HeaderView(style: .title, text: titleString)
      HeaderView(style: .subtitle, text: subtitleString)
    }
    .padding(.bottom, 32)
  }

  private var identifierInputSection: some View {
    VStack(spacing: 4) {
      identifierField
      fieldErrorView
    }
  }

  @ViewBuilder
  private var identifierField: some View {
    @Bindable var authState = authState

    if phoneNumberInputIsActive {
      ClerkPhoneNumberField(
        "Enter your phone number",
        text: $authState.authStartPhoneNumber,
        fieldState: fieldError != nil ? .error : .default,
        isEnabled: !authState.authStartPhoneNumberIsLocked,
        accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.Start.phoneNumber
      )
      .transition(.blurReplace)
      .lastUsedAuthBadgeOverlay(lastUsedAuth?.showsPhoneBadge ?? false)
    } else {
      VStack {
        ClerkTextField(
          emailOrUsernamePlaceholder,
          text: $authState.authStartIdentifier,
          fieldState: fieldError != nil ? .error : .default,
          isEnabled: !authState.authStartIdentifierIsLocked,
          accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.Start.identifier
        )
        .textContentType(.username)
        .autocorrectionDisabled()
        #if os(iOS)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        #endif
        .lastUsedAuthBadgeOverlay(lastUsedAuth?.showsEmailUsernameBadge ?? false)
      }
      .transition(.blurReplace)
    }
  }

  @ViewBuilder
  private var fieldErrorView: some View {
    if let fieldError {
      ErrorText(error: fieldError, alignment: .leading)
        .font(theme.fonts.subheadline)
        .transition(.blurReplace.animation(.default.speed(2)))
        .id(fieldError.localizedDescription)
    }
  }

  private var continueButton: some View {
    @Bindable var authState = authState

    return AsyncButton(onStart: beginIdentifierAuthStartOperation) { operationToken in
      await startAuth(operationToken: operationToken)
    } label: { isRunning in
      ContinueButtonLabelView(isActive: isRunning)
    }
    .buttonStyle(.primary())
    .disabled(activeIdentifier.isEmpty)
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.continueButton)
    .simultaneousGesture(TapGesture())
  }

  private var identifierSwitcherButton: some View {
    Button {
      cancelAuthStartOperation()
      cancelAutomaticPasskeySignIn()
      withAnimation(.default.speed(2)) {
        authState.authStartPhoneNumberFieldIsActive.toggle()
      }
      restartAutomaticPasskeySignInIfNeeded()
    } label: {
      Text(identifierSwitcherString, bundle: .module)
        .id(phoneNumberFieldIsActive)
    }
    .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.identifierSwitcherButton)
    .simultaneousGesture(TapGesture())
  }

  @ViewBuilder
  private var biometricSignInButton: some View {
    if let biometryDisplayName {
      BiometricSignInButton(
        biometryDisplayName: biometryDisplayName,
        onStart: beginAlternativeAuthStartOperation
      ) { operationToken in
        await signInWithBiometrics(operationToken: operationToken)
      }
      .lastUsedAuthBadgeOverlay(lastUsedAuth?.showsBiometricCredentialBadge == true)
      .simultaneousGesture(TapGesture())
    }
  }

  private var alternativeAuthMethodsSection: some View {
    VStack(spacing: 16) {
      if shouldShowPasskeySignInButton {
        passkeySignInButton
      }

      if shouldShowBiometricSignIn {
        biometricSignInButton
      }

      if hasSocialProviders {
        socialButtonsSection
      }
    }
  }

  private var passkeySignInButton: some View {
    AsyncButton(onStart: beginInteractivePasskeySignInOperation) { operationToken in
      await signInWithPasskeyButton(operationToken: operationToken)
    } label: { isRunning in
      StrategyOptionButton(
        iconName: "icon-fingerprint",
        text: "Sign in with your passkey"
      )
      .overlayProgressView(isActive: isRunning)
    }
    .buttonStyle(.secondary())
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.passkeySignInButton)
    .simultaneousGesture(TapGesture())
  }

  private var socialButtonsSection: some View {
    VStack(spacing: 8) {
      if lastUsedAuth?.socialProvider != nil || !socialProvidersMinusLastUsed.isEmpty {
        SocialButtonGroup(
          providers: socialProviders,
          lastUsedProvider: lastUsedAuth?.socialProvider
        ) { provider, showsTitle, isLastUsed in
          SocialButton(
            provider: provider,
            transferable: authState.transferable,
            unsafeMetadata: authState.unsafeMetadata,
            showsTitle: showsTitle,
            onStart: beginAlternativeAuthStartOperation
          ) { operationToken in
            await signInWithSocialProvider(
              provider,
              operationToken: operationToken
            )
          }
          .lastUsedAuthBadgeOverlay(isLastUsed)
          .simultaneousGesture(TapGesture())
        }
      }
    }
  }
}

// MARK: - Actions

extension AuthStartView {
  private enum PasskeySignInResult {
    case completed
    case continueWithAutofill
    case stopped
  }

  func startAuth(operationToken: AuthStartOperation.Token) async {
    await authStartOperation.run(token: operationToken) { operationToken in
      guard authStartOperation.isCurrent(operationToken) else { return }

      let shouldRestartPasskeySignIn = switch authState.mode {
      case .signInOrUp: await signIn(withSignUp: true, operationToken: operationToken)
      case .signIn: await signIn(withSignUp: false, operationToken: operationToken)
      case .signUp: await signUp(operationToken: operationToken)
      }

      guard authStartOperation.isCurrent(operationToken) else { return }
      if shouldRestartPasskeySignIn {
        restartAutomaticPasskeySignInIfNeeded()
      }
    }
  }

  private func cancelAutomaticPasskeySignIn() {
    automaticPasskeySignInTaskGeneration += 1
    automaticPasskeySignInTask?.cancel()
    automaticPasskeySignInTask = nil
  }

  private func cancelAuthStartOperation() {
    authStartOperation.cancel()
  }

  private func beginAlternativeAuthStartOperation() -> AuthStartOperation.Token {
    let operationToken = authStartOperation.begin()
    cancelAutomaticPasskeySignIn()
    return operationToken
  }

  private func beginIdentifierAuthStartOperation() -> AuthStartOperation.Token {
    let operationToken = beginAlternativeAuthStartOperation()
    dismissKeyboard()
    return operationToken
  }

  private func beginInteractivePasskeySignInOperation() -> AuthStartOperation.Token {
    automaticPasskeySignInHasStarted = true
    return beginIdentifierAuthStartOperation()
  }

  private func restartAutomaticPasskeySignInIfNeeded() {
    guard passkeySignInTaskIsEnabled else { return }
    automaticPasskeySignInRestartID += 1
  }

  private func restartAutomaticPasskeySignInAfterEnvironmentRefreshIfNeeded() {
    guard !automaticPasskeySignInHasStarted, automaticPasskeySignInTask == nil else { return }
    restartAutomaticPasskeySignInIfNeeded()
  }

  private func signIn(
    withSignUp: Bool,
    operationToken: AuthStartOperation.Token
  ) async -> Bool {
    fieldError = nil

    do {
      // Store the identifier type for "last used" badge disambiguation
      storeIdentifierType()

      let signIn = try await clerk.auth.signIn(activeIdentifier)
      guard authStartOperation.isCurrent(operationToken) else { return false }

      if signIn.startingFirstFactor?.strategy == .enterpriseSSO {
        let result = try await signIn.authenticateWithEnterpriseSSO(
          transferable: authState.transferable,
          unsafeMetadata: authState.unsafeMetadata
        )
        guard authStartOperation.isCurrent(operationToken) else { return false }
        handleTransferFlowResult(result)
        return false
      }

      navigation.setToStepForStatus(signIn: signIn)
      return signInStatusStaysOnStart(signIn.status)
    } catch {
      guard authStartOperation.isCurrent(operationToken), !error.isCancellationError else {
        return false
      }
      if withSignUp, let clerkApiError = error as? ClerkAPIError, ["form_identifier_not_found", "invitation_account_not_exists"].contains(clerkApiError.code) {
        return await signUp(operationToken: operationToken)
      } else {
        fieldError = error
        return true
      }
    }
  }

  private func createPasskeySignIn(
    presentsErrors: Bool = false,
    operationToken: AuthStartOperation.Token? = nil
  ) async -> SignIn? {
    do {
      return try await clerk.auth.createPasskeySignIn()
    } catch {
      if !passkeySignInOperationIsCurrent(operationToken) || error.isCancellationError {
        return nil
      }
      guard navigation.path.isEmpty else { return nil }

      if presentsErrors {
        generalError = error
      }
      ClerkLogger.error("Failed to create passkey sign-in", error: error)
      return nil
    }
  }

  /// Presents an actionable failure from a passkey sign-in.
  ///
  /// The automatic modal and the AutoFill fallback both start without user intent, so
  /// failures from stages before credential selection and authorization ceremony failures
  /// are logged instead of presented. Other errors, such as the server rejecting a
  /// credential the user selected, remain actionable and are presented.
  private func presentPasskeyError(
    _ failure: PasskeyAuthenticationFailure,
    isUserInitiated: Bool
  ) {
    guard Self.shouldPresentPasskeyError(
      at: failure.stage,
      isUserInitiated: isUserInitiated
    ) else { return }
    generalError = failure.underlyingError
  }

  static func shouldPresentPasskeyError(
    at stage: PasskeyAuthenticationFailure.Stage,
    isUserInitiated: Bool
  ) -> Bool {
    isUserInitiated || stage == .attemptingFirstFactor
  }

  @discardableResult
  private func authenticateWithPasskey(
    signIn: SignIn,
    autofill: Bool,
    preferImmediatelyAvailableCredentials: Bool,
    isUserInitiated: Bool = false,
    operationToken: AuthStartOperation.Token? = nil
  ) async -> PasskeySignInResult {
    do {
      let signIn = try await signIn.authenticateWithPasskeyWithFailureContext(
        autofill: autofill,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )

      guard passkeySignInOperationIsCurrent(operationToken) else { return .stopped }
      generalError = nil
      guard navigation.path.isEmpty else { return .stopped }
      navigation.setToStepForStatus(signIn: signIn)
      return .completed
    } catch {
      let underlyingError = error.underlyingError
      if !passkeySignInOperationIsCurrent(operationToken) || underlyingError.isCancellationError {
        return .stopped
      }
      if underlyingError.isUserCancelledError { return .continueWithAutofill }
      guard navigation.path.isEmpty else { return .stopped }

      presentPasskeyError(error, isUserInitiated: isUserInitiated)
      if autofill {
        ClerkLogger.error("Failed to authenticate with passkey autofill", error: underlyingError)
      } else {
        ClerkLogger.error("Failed to authenticate with passkey", error: underlyingError)
      }
      // Keep iOS text-field AutoFill armed after a modal error so users can
      // pick another passkey without a second modal.
      return autofill ? .stopped : .continueWithAutofill
    }
  }

  private func signInWithPasskeyButton(operationToken: AuthStartOperation.Token) async {
    await authStartOperation.run(token: operationToken) { operationToken in
      guard authStartOperation.isCurrent(operationToken) else { return }

      guard let signIn = await createPasskeySignIn(
        presentsErrors: true,
        operationToken: operationToken
      ) else {
        guard authStartOperation.isCurrent(operationToken) else { return }
        restartAutomaticPasskeySignInIfNeeded()
        return
      }

      guard authStartOperation.isCurrent(operationToken) else { return }

      let result = await authenticateWithPasskey(
        signIn: signIn,
        autofill: false,
        preferImmediatelyAvailableCredentials: false,
        isUserInitiated: true,
        operationToken: operationToken
      )
      guard authStartOperation.isCurrent(operationToken) else { return }
      guard case .completed = result else {
        restartAutomaticPasskeySignInIfNeeded()
        return
      }
    }
  }

  private func passkeySignInOperationIsCurrent(
    _ operationToken: AuthStartOperation.Token?
  ) -> Bool {
    guard !Task.isCancelled else { return false }
    guard let operationToken else { return true }
    return authStartOperation.isCurrent(operationToken)
  }

  #if os(iOS) && !targetEnvironment(macCatalyst)
  private func startPasskeySignIn(includeAutomaticModal: Bool) async {
    guard navigation.path.isEmpty else { return }
    let checkpoint = authState.environmentRefreshCheckpoint(for: clerk)
    guard let environment = try? await clerk.ensureEnvironmentRefreshed(after: checkpoint) else { return }
    guard !Task.isCancelled, navigation.path.isEmpty else { return }
    if includeAutomaticModal {
      automaticPasskeySignInHasStarted = true
    }

    let shouldPresentAutomaticModal = includeAutomaticModal && passkeyAutomaticModalIsEnabled(environment: environment)
    let shouldStartAutoFillFallback = passkeyAutoFillFallbackIsEnabled(environment: environment)
    guard shouldPresentAutomaticModal || shouldStartAutoFillFallback else { return }

    guard let signIn = await createPasskeySignIn() else { return }
    guard !Task.isCancelled, navigation.path.isEmpty else { return }

    if shouldPresentAutomaticModal {
      let result = await authenticateWithPasskey(
        signIn: signIn,
        autofill: false,
        preferImmediatelyAvailableCredentials: true
      )
      guard case .continueWithAutofill = result else { return }
    }

    guard shouldStartAutoFillFallback, navigation.path.isEmpty else { return }
    // Clerk's AutoFill setting gates the automatic modal above; this keeps
    // iOS text-field AutoFill available when a visible identifier field can
    // surface suggestions.
    await authenticateWithPasskey(
      signIn: signIn,
      autofill: true,
      preferImmediatelyAvailableCredentials: true
    )
  }
  #endif

  private func signUp(operationToken: AuthStartOperation.Token) async -> Bool {
    fieldError = nil

    do {
      let signUp = try await signUpParams()
      guard authStartOperation.isCurrent(operationToken) else { return false }
      navigation.setToStepForStatus(signUp: signUp)
      return signUpStatusStaysOnStart(signUp.status)
    } catch {
      guard authStartOperation.isCurrent(operationToken), !error.isCancellationError else {
        return false
      }
      fieldError = error
      return true
    }
  }

  private func signUpParams() async throws -> SignUp {
    if phoneNumberInputIsActive {
      try await clerk.auth.signUp(
        phoneNumber: authState.authStartPhoneNumber,
        unsafeMetadata: authState.unsafeMetadata
      )
    } else if authState.authStartIdentifier.isEmailAddress {
      try await clerk.auth.signUp(
        emailAddress: authState.authStartIdentifier,
        unsafeMetadata: authState.unsafeMetadata
      )
    } else {
      try await clerk.auth.signUp(
        username: authState.authStartIdentifier,
        unsafeMetadata: authState.unsafeMetadata
      )
    }
  }

  private func handleTransferFlowResult(_ result: TransferFlowResult) {
    switch result {
    case .signIn(let signIn):
      navigation.setToStepForStatus(signIn: signIn)
    case .signUp(let signUp):
      navigation.setToStepForStatus(signUp: signUp)
    }
  }

  private func storeIdentifierType() {
    if phoneNumberInputIsActive {
      authState.storeLastUsedIdentifierType(.phone)
    } else if authState.authStartIdentifier.isEmailAddress {
      authState.storeLastUsedIdentifierType(.email)
    } else {
      authState.storeLastUsedIdentifierType(.username)
    }
  }

  private func signInStatusStaysOnStart(_ status: SignIn.Status) -> Bool {
    switch status {
    case .needsIdentifier, .unknown:
      true
    default:
      false
    }
  }

  private func signUpStatusStaysOnStart(_ status: SignUp.Status) -> Bool {
    switch status {
    case .abandoned, .unknown:
      true
    default:
      false
    }
  }

  private func refreshBiometricCredentialAvailability() async {
    guard authState.mode != .signUp, biometricCredentialFeatureIsEnabled else {
      biometricCredentialAvailability = nil
      return
    }

    guard clerk.session?.status != .active else {
      biometricCredentialAvailability = nil
      return
    }

    guard let localAvailability = try? clerk.biometricCredentials.localAvailability() else {
      biometricCredentialAvailability = nil
      return
    }

    if localAvailability.isAvailable, biometryDisplayName == nil {
      biometryDisplayName = .current()
    }
    biometricCredentialAvailability = localAvailability
    guard localAvailability.isAvailable else { return }

    let validationResult = await clerk.biometricCredentials.validateLocalCredentialIfPossible()
    guard !Task.isCancelled else { return }

    switch validationResult {
    case .valid:
      biometricCredentialAvailability = .available
    case let .invalid(reason):
      biometricCredentialAvailability = .unavailable(reason)
    case .inconclusive:
      break
    }
  }

  private func signInWithSocialProvider(
    _ provider: OAuthProvider,
    operationToken: AuthStartOperation.Token
  ) async {
    await authStartOperation.run(token: operationToken) { operationToken in
      guard authStartOperation.isCurrent(operationToken) else { return }

      do {
        let result: TransferFlowResult = if provider == .apple {
          try await clerk.auth.signInWithApple(
            transferable: authState.transferable,
            unsafeMetadata: authState.unsafeMetadata
          )
        } else {
          try await clerk.auth.signInWithOAuth(
            provider: provider,
            transferable: authState.transferable,
            unsafeMetadata: authState.unsafeMetadata
          )
        }

        guard authStartOperation.isCurrent(operationToken) else { return }
        handleTransferFlowResult(result)
      } catch {
        guard authStartOperation.isCurrent(operationToken), !error.isCancellationError else {
          return
        }
        if !error.isUserCancelledError {
          generalError = error
        }
        restartAutomaticPasskeySignInIfNeeded()
      }
    }
  }

  private func signInWithBiometrics(operationToken: AuthStartOperation.Token) async {
    await authStartOperation.run(token: operationToken) { operationToken in
      guard authStartOperation.isCurrent(operationToken) else { return }
      generalError = nil

      do {
        let signIn = try await clerk.auth.signInWithBiometrics()
        guard authStartOperation.isCurrent(operationToken), navigation.path.isEmpty else { return }
        navigation.setToStepForStatus(signIn: signIn)
      } catch {
        guard authStartOperation.isCurrent(operationToken), !error.isCancellationError else {
          return
        }
        if error.isUserCancelledError {
          restartAutomaticPasskeySignInIfNeeded()
          return
        }

        generalError = error
        await refreshBiometricCredentialAvailability()
        guard authStartOperation.isCurrent(operationToken) else { return }
        restartAutomaticPasskeySignInIfNeeded()
      }
    }
  }
}

#Preview {
  AuthStartView()
    .clerkPreview()
}

#Preview("Clerk Theme") {
  AuthStartView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#Preview("Localized") {
  AuthStartView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
    .environment(\.locale, .init(identifier: "es"))
}

#endif
