@testable import ClerkKitUI
import Testing

@MainActor
struct AuthStartPasskeySignInOperationTests {
  @Test
  func supersededOperationCannotApplyLateEffects() async {
    let operation = AuthStartPasskeySignInOperation()
    let gate = PasskeySignInOperationGate()
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

private actor PasskeySignInOperationGate {
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
