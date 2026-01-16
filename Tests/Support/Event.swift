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

import Witness_Macros

/// Test enum for @Witness applied to enums.
@Witness
public enum Event: Sendable, Hashable {
    case login(userId: Int)
    case logout(userId: Int)
    case purchase(itemId: String, amount: Double)
    case viewPage(path: String)
    case systemStart
}

// MARK: - Nested Enum Tests

/// Inner enum for testing prism composition.
@Witness
public enum Inner: Sendable, Hashable {
    case value(Int)
    case text(String)
    case empty
}

/// Outer enum containing Inner for testing prism composition.
@Witness
public enum Outer: Sendable, Hashable {
    case inner(Inner)
    case direct(Int)
}
