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

@_exported import Witness_Primitives
@_exported import Algebra_Primitives

/// Generates protocol witness infrastructure for a struct with closure properties.
///
/// Apply `@Witness` to a struct containing closure properties to automatically generate:
/// - **Methods** with argument labels for closures that have labeled parameters
/// - **Action enum** with cases for each closure, useful for observation/middleware
/// - **`unimplemented`** static property that fatally errors (for testing)
/// - **`observe`** method to wrap the witness with an observer
///
/// ## Basic Usage
///
/// ```swift
/// @Witness
/// struct APIClient: Sendable {
///     var fetchUser: (_ id: User.ID) async throws -> User
///     var updateUser: (_ id: User.ID, _ name: String) async throws -> User
///     var deleteUser: (_ id: User.ID) async throws -> Void
/// }
/// ```
///
/// This generates methods that can be called with labels:
///
/// ```swift
/// let client = APIClient.live
/// let user = try await client.fetchUser(id: 42)
/// try await client.updateUser(id: 42, name: "New Name")
/// ```
///
/// ## Labeled vs Unlabeled Closures
///
/// - **Labeled** (`(_ id: Int) -> T`): Generates a method with that label, deprecates the closure property
/// - **Unlabeled** (`(Int) -> T`): No method generated, closure remains the only API
///
/// ## Generated Action Enum
///
/// ```swift
/// extension APIClient {
///     enum Action: Sendable {
///         case fetchUser(id: User.ID)
///         case updateUser(id: User.ID, name: String)
///         case deleteUser(id: User.ID)
///     }
/// }
/// ```
///
/// ## Observation
///
/// ```swift
/// let observed = client.observe { action in
///     print("Called: \(action)")
/// }
/// ```
///
/// ## Platform Implementations
///
/// ```swift
/// // In swift-darwin-primitives
/// extension APIClient {
///     static var darwin: Self {
///         Self(
///             fetchUser: { id in /* Darwin implementation */ },
///             updateUser: { id, name in /* Darwin implementation */ },
///             deleteUser: { id in /* Darwin implementation */ }
///         )
///     }
/// }
/// ```
@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(extension, conformances: __WitnessProtocol, Algebra_Primitives.__PrismAccessible)
public macro Witness() = #externalMacro(
    module: "Witness_Macros_Implementation",
    type: "WitnessMacro"
)
