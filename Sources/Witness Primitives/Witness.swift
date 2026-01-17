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

/// Namespace for protocol witness types and utilities.
///
/// A protocol witness is a struct with closure properties that represents a capability
/// or interface. This pattern enables:
/// - Platform-specific implementations (darwin, linux, windows)
/// - Test doubles (mock, spy, recorded) - see `swift-witnesses` foundations layer
/// - Middleware composition (logging, tracing, retrying)
///
/// ## Example
///
/// ```swift
/// @Witness
/// struct FileSystem: Sendable {
///     var open: (_ path: String, _ flags: Int) async throws -> Int
///     var read: (_ descriptor: Int, _ count: Int) async throws -> [UInt8]
///     var close: (_ descriptor: Int) async throws -> Void
/// }
///
/// // Platform implementation
/// extension FileSystem {
///     static var darwin: Self {
///         Self(
///             open: { path, flags in Darwin.open(path, flags) },
///             read: { fd, count in Darwin.read(fd, count) },
///             close: { fd in Darwin.close(fd) }
///         )
///     }
/// }
///
/// // Usage
/// let fs = FileSystem.darwin
/// let fd = try await fs.open(path: "/tmp/test", flags: 0)
/// ```
public enum Witness {}

/// Internal typealias to work around macro conformance declaration limitations.
/// Prefer `Witness.`Protocol`` in all other contexts.
public typealias __WitnessProtocol = Witness.`Protocol`
