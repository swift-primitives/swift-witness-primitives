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

public import Dependency_Primitives

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
    ///
    /// ## Dependency Injection
    ///
    /// Witnesses that have live/test variants can also conform to
    /// ``Dependency/Key`` for formal dependency injection support:
    ///
    /// ```swift
    /// struct FileSystem: Witness.Protocol, Dependency.Key {
    ///     var read: (String) async throws -> Data
    ///     var write: (String, Data) async throws -> Void
    ///
    ///     static var liveValue: Self { .darwin }
    ///     static var testValue: Self { .mock }
    /// }
    ///
    /// // Usage with Dependency.Scope
    /// Dependency.Scope.with { values in
    ///     values[FileSystem.self] = .mock
    /// } operation: {
    ///     let fs = Dependency.Scope.current[FileSystem.self]
    ///     // Uses .mock
    /// }
    /// ```
    public protocol `Protocol`: Sendable {}

    /// Type alias for dependency injection key protocol.
    ///
    /// Use `Witness.DependencyKey` or `Dependency.Key` interchangeably for
    /// witnesses that support dependency injection.
    ///
    /// > Note: Renamed from `Key` to avoid conflict with `Witness.Key` protocol
    /// > defined in swift-witnesses.
    public typealias DependencyKey = Dependency.Key
}
