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

/// Test witness for API client patterns.
@Witness
public struct API: Sendable {
    public var fetchUser: @Sendable (_ id: Int) async throws -> String
    public var deleteUser: @Sendable (_ id: Int) async throws -> Void
}
