//
//  AuthStartPasskeySignInOperation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation

@MainActor
final class AuthStartPasskeySignInOperation {
  struct Token: Equatable {
    fileprivate let generation: UInt64
  }

  private var generation: UInt64 = 0
  private var task: Task<Void, Never>?

  func run(
    _ operation: @escaping @MainActor (Token) async -> Void
  ) async {
    cancel()
    let token = Token(generation: generation)
    let task = Task { @MainActor in
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

#endif
