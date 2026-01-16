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

/// Test witness with both labeled and unlabeled closures.
@Witness
public struct Mixed: Sendable {
    public var labeled: @Sendable (_ id: Int) -> String
    public var unlabeled: @Sendable (Int) -> String
}
