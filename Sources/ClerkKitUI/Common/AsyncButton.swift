//
//  AsyncButton.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct AsyncButton<ActionContext, Label: View>: View {
  @Environment(\.authFlowRequestOwnerId) private var authFlowRequestOwnerId
  @State private var isRunning = false

  let role: ButtonRole?
  let onStart: @MainActor () -> ActionContext
  let action: @MainActor (ActionContext) async -> Void
  let label: (_ isRunning: Bool) -> Label

  var onIsRunningChanged: ((Bool) -> Void)?

  init(
    role: ButtonRole? = nil,
    action: @escaping @MainActor () async -> Void,
    @ViewBuilder label: @escaping (_ isRunning: Bool) -> Label
  ) where ActionContext == Void {
    self.role = role
    onStart = {}
    self.action = { _ in await action() }
    self.label = label
  }

  init(
    role: ButtonRole? = nil,
    onStart: @escaping @MainActor () -> ActionContext,
    action: @escaping @MainActor (ActionContext) async -> Void,
    @ViewBuilder label: @escaping (_ isRunning: Bool) -> Label
  ) {
    self.role = role
    self.onStart = onStart
    self.action = action
    self.label = label
  }

  var body: some View {
    Button(role: role) {
      guard !isRunning else { return }
      isRunning = true
      let actionContext = onStart()

      Task { @MainActor in
        defer { isRunning = false }
        await AuthFlowRequestScope.withOwner(authFlowRequestOwnerId) {
          await action(actionContext)
        }
      }
    } label: {
      label(isRunning)
    }
    .animation(.default, value: isRunning)
    .onChange(of: isRunning) {
      onIsRunningChanged?($1)
    }
  }
}

extension AsyncButton {
  func onIsRunningChanged(_ action: @escaping (Bool) -> Void) -> Self {
    var view = self
    view.onIsRunningChanged = action
    return view
  }
}

#Preview {
  #if os(iOS)
  VStack(spacing: 20) {
    AsyncButton {
      do {
        try await Task.sleep(for: .seconds(2))
      } catch {
        dump(error)
      }
    } label: { isRunning in
      Text("Button")
        .overlayProgressView(isActive: isRunning)
    }
    .buttonStyle(.primary())

    AsyncButton {
      do {
        try await Task.sleep(for: .seconds(2))
      } catch {
        dump(error)
      }
    } label: { isRunning in
      Text("Button")
        .padding(12)
        .frame(maxWidth: .infinity)
        .overlayProgressView(isActive: isRunning)
        .overlay {
          RoundedRectangle(cornerRadius: 6)
            .stroke(.secondary, lineWidth: 1)
        }
    }
  }
  .padding()
  #endif
}

#endif
