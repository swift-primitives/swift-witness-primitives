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

extension Witness {
    /// Marker protocol for struct-with-closures types that represent capabilities.
    ///
    /// Conforming types are "protocol witnesses"—structs where each stored property
    /// is a closure representing an operation. The `@Witness` macro automatically
    /// generates conformance along with:
    /// - Methods with argument labels (for closures with labeled parameters)
    /// - An `Action` enum for observation and middleware
    /// - An `observe` accessor for wrapping with observers
    ///
    /// > Note: Test-aware `unimplemented` witnesses are provided by `swift-witnesses`.
    ///
    /// ## Manual Conformance
    ///
    /// While the `@Witness` macro is recommended, you can conform manually:
    ///
    /// ```swift
    /// struct MyClient: Witness.Protocol {
    ///     var fetch: (String) async throws -> Data
    /// }
    /// ```
    public protocol `Protocol` {}
}
