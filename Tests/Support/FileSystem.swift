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

/// Test witness for file system operations.
@Witness
public struct FileSystem: Sendable {
    public var open: @Sendable (_ path: String, _ flags: Int) async throws -> Int
    public var read: @Sendable (_ descriptor: Int, _ count: Int) async throws -> [UInt8]
    public var close: @Sendable (_ descriptor: Int) async throws -> Void
}
