// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-primitives
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Action {
    /// Records actions for testing observation patterns.
    ///
    /// Use this actor to collect actions emitted by a witness's `observe` method.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let recorder = Action.Recorder<APIClient.Action>()
    ///
    /// let client = APIClient.live.observe { action in
    ///     Task { await recorder.record(action) }
    /// }
    ///
    /// try await client.fetchUser(id: 42)
    ///
    /// let actions = await recorder.actions
    /// ```
    public actor Recorder<T: Sendable> {
        private var _actions: [T] = []

        public init() {}

        public var actions: [T] {
            _actions
        }

        public func record(_ action: T) {
            _actions.append(action)
        }

        public func reset() {
            _actions.removeAll()
        }
    }
}
