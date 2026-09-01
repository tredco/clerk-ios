@testable import ClerkKitUI
import Testing

@MainActor
struct AuthStartOperationTests {
  @Test
  func delayedIdentifierResultCannotOverrideNewerPasskeyIntent() async {
    let operation = AuthStartOperation()
    let identifierGate = AuthStartOperationGate()
    var identifierDidNavigate = false
    var identifierDidPresentError = false
    var identifierDidRestartAutomaticSignIn = false
    var identifierObservedCancellation = false
    var passkeyDidNavigate = false

    let identifierTask = Task { @MainActor in
      await operation.run { token in
        await identifierGate.suspend()
        identifierObservedCancellation = Task.isCancelled
        guard operation.isCurrent(token) else { return }

        identifierDidNavigate = true
        identifierDidPresentError = true
        identifierDidRestartAutomaticSignIn = true
      }
    }

    await identifierGate.waitUntilSuspended()
    await operation.run { token in
      guard operation.isCurrent(token) else { return }
      passkeyDidNavigate = true
    }
    await identifierGate.resume()
    await identifierTask.value

    #expect(identifierObservedCancellation)
    #expect(!identifierDidNavigate)
    #expect(!identifierDidPresentError)
    #expect(!identifierDidRestartAutomaticSignIn)
    #expect(passkeyDidNavigate)
  }

  @Test
  func delayedPasskeyResultCannotOverrideNewerIdentifierIntent() async {
    let operation = AuthStartOperation()
    let passkeyGate = AuthStartOperationGate()
    var passkeyDidNavigate = false
    var passkeyDidPresentError = false
    var passkeyDidRestartAutomaticSignIn = false
    var passkeyObservedCancellation = false
    var identifierDidNavigate = false

    let passkeyTask = Task { @MainActor in
      await operation.run { token in
        await passkeyGate.suspend()
        passkeyObservedCancellation = Task.isCancelled
        guard operation.isCurrent(token) else { return }

        passkeyDidNavigate = true
        passkeyDidPresentError = true
        passkeyDidRestartAutomaticSignIn = true
      }
    }

    await passkeyGate.waitUntilSuspended()
    await operation.run { token in
      guard operation.isCurrent(token) else { return }
      identifierDidNavigate = true
    }
    await passkeyGate.resume()
    await passkeyTask.value

    #expect(passkeyObservedCancellation)
    #expect(!passkeyDidNavigate)
    #expect(!passkeyDidPresentError)
    #expect(!passkeyDidRestartAutomaticSignIn)
    #expect(identifierDidNavigate)
  }

  @Test(arguments: AlternativeAuthIntent.allCases)
  func delayedAlternativeResultCannotOverrideNewerPasskeyIntent(
    _: AlternativeAuthIntent
  ) async {
    let operation = AuthStartOperation()
    let alternativeGate = AuthStartOperationGate()
    var alternativeDidApplyEffects = false
    var alternativeObservedCancellation = false
    var passkeyDidNavigate = false

    let alternativeTask = Task { @MainActor in
      await operation.run { token in
        await alternativeGate.suspend()
        alternativeObservedCancellation = Task.isCancelled
        guard operation.isCurrent(token) else { return }

        alternativeDidApplyEffects = true
      }
    }

    await alternativeGate.waitUntilSuspended()
    await operation.run { token in
      guard operation.isCurrent(token) else { return }
      passkeyDidNavigate = true
    }
    await alternativeGate.resume()
    await alternativeTask.value

    #expect(alternativeObservedCancellation)
    #expect(!alternativeDidApplyEffects)
    #expect(passkeyDidNavigate)
  }

  @Test
  func olderClaimCannotStartAfterNewerIntentClaim() async {
    let operation = AuthStartOperation()
    let olderToken = operation.begin()
    let newerToken = operation.begin()
    var olderDidNavigate = false
    var newerDidNavigate = false

    await operation.run(token: olderToken) { _ in
      olderDidNavigate = true
    }
    await operation.run(token: newerToken) { token in
      guard operation.isCurrent(token) else { return }
      newerDidNavigate = true
    }

    #expect(!olderDidNavigate)
    #expect(newerDidNavigate)
  }

  @Test
  func cancelledOperationCannotApplyLateEffects() async {
    let operation = AuthStartOperation()
    let gate = AuthStartOperationGate()
    var didNavigate = false
    var didPresentError = false
    var didRestartAutomaticSignIn = false
    var observedCancellation = false

    let task = Task { @MainActor in
      await operation.run { token in
        await gate.suspend()
        observedCancellation = Task.isCancelled
        guard operation.isCurrent(token) else { return }

        didNavigate = true
        didPresentError = true
        didRestartAutomaticSignIn = true
      }
    }

    await gate.waitUntilSuspended()
    operation.cancel()
    await gate.resume()
    await task.value

    #expect(observedCancellation)
    #expect(!didNavigate)
    #expect(!didPresentError)
    #expect(!didRestartAutomaticSignIn)
  }
}

enum AlternativeAuthIntent: CaseIterable {
  case social
  case biometric
}

private actor AuthStartOperationGate {
  private var isSuspended = false
  private var releaseContinuation: CheckedContinuation<Void, Never>?
  private var suspensionContinuations: [CheckedContinuation<Void, Never>] = []

  func suspend() async {
    isSuspended = true
    let continuations = suspensionContinuations
    suspensionContinuations.removeAll()
    continuations.forEach { $0.resume() }

    await withCheckedContinuation { continuation in
      releaseContinuation = continuation
    }
  }

  func waitUntilSuspended() async {
    guard !isSuspended else { return }
    await withCheckedContinuation { continuation in
      suspensionContinuations.append(continuation)
    }
  }

  func resume() {
    releaseContinuation?.resume()
    releaseContinuation = nil
  }
}
