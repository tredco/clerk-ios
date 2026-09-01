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

#endif
