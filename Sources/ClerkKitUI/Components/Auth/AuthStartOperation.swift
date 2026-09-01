//
//  AuthStartOperation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation

@MainActor
final class AuthStartOperation {
  struct Token: Equatable {
    fileprivate let generation: UInt64
  }

  private var generation: UInt64 = 0
  private var task: Task<Void, Never>?

  func begin() -> Token {
    cancel()
    return Token(generation: generation)
  }

  func run(
    _ operation: @escaping @MainActor (Token) async -> Void
  ) async {
    let token = begin()
    await run(token: token, operation)
  }

  func run(
    token: Token,
    _ operation: @escaping @MainActor (Token) async -> Void
  ) async {
    guard isCurrent(token) else { return }

    let task = Task { @MainActor in
      guard isCurrent(token) else { return }
      await operation(token)
    }
    self.task = task

    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }

    if token.generation == generation {
      self.task = nil
    }
  }

  func cancel() {
    generation &+= 1
    task?.cancel()
    task = nil
  }

  func isCurrent(_ token: Token) -> Bool {
    !Task.isCancelled && token.generation == generation
  }
}

struct AuthStartPasskeySignInState {
  private(set) var automaticSignInRestartID = 0
  private(set) var automaticSignInHasStarted = false
  private var automaticSignInIsArmed = true
  private var explicitOperationToken: AuthStartOperation.Token?

  var automaticSignInCanStart: Bool {
    automaticSignInIsArmed && explicitOperationToken == nil
  }

  mutating func beginExplicitOperation(
    _ operationToken: AuthStartOperation.Token,
    marksAutomaticSignInStarted: Bool = false
  ) {
    explicitOperationToken = operationToken
    automaticSignInIsArmed = false
    if marksAutomaticSignInStarted {
      automaticSignInHasStarted = true
    }
  }

  @discardableResult
  mutating func finishExplicitOperation(
    _ operationToken: AuthStartOperation.Token,
    shouldRestartAutomaticSignIn: Bool,
    automaticSignInIsEnabled: Bool
  ) -> Bool {
    guard explicitOperationToken == operationToken else { return false }

    explicitOperationToken = nil
    if shouldRestartAutomaticSignIn {
      restartAutomaticSignInIfNeeded(isEnabled: automaticSignInIsEnabled)
    }
    return true
  }

  mutating func cancelExplicitOperation() {
    explicitOperationToken = nil
  }

  mutating func markAutomaticSignInStarted() {
    automaticSignInHasStarted = true
  }

  mutating func restartAutomaticSignInIfNeeded(isEnabled: Bool) {
    automaticSignInIsArmed = true
    guard isEnabled else { return }
    automaticSignInRestartID += 1
  }

  mutating func rearmAutomaticSignInAfterAppearanceIfNeeded(isEnabled: Bool) {
    guard explicitOperationToken == nil, !automaticSignInIsArmed else { return }
    restartAutomaticSignInIfNeeded(isEnabled: isEnabled)
  }

  mutating func restartAutomaticSignInAfterEnvironmentRefreshIfNeeded(
    isEnabled: Bool,
    taskIsActive: Bool
  ) {
    guard automaticSignInCanStart,
          !automaticSignInHasStarted,
          !taskIsActive
    else { return }

    restartAutomaticSignInIfNeeded(isEnabled: isEnabled)
  }
}

#endif
