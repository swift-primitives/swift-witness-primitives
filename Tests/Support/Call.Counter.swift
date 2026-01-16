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

extension Call {
    /// Counts invocations for testing.
    ///
    /// Use this actor to count how many times an operation was called.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let counter = Call.Counter()
    ///
    /// let client = APIClient.live.observe { _ in
    ///     Task { await counter.increment() }
    /// }
    ///
    /// try await client.fetchUser(id: 1)
    /// try await client.fetchUser(id: 2)
    ///
    /// let count = await counter.count  // 2
    /// ```
    public actor Counter {
        private var _count: Int = 0

        public init() {}

        public var count: Int {
            _count
        }

        public func increment() {
            _count += 1
        }

        public func reset() {
            _count = 0
        }
    }
}
