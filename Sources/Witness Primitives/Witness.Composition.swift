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
    /// Strategies for composing multiple witness implementations.
    ///
    /// When combining witnesses (e.g., for middleware or layered behavior),
    /// the composition strategy determines how multiple implementations interact.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Sequential composition for middleware patterns
    /// let loggingAPI = apiClient.compose(with: loggingMiddleware, strategy: .sequential)
    ///
    /// // Fallback composition for redundancy
    /// let resilientAPI = primaryClient.compose(with: backupClient, strategy: .fallback)
    /// ```
    ///
    /// ## Composition Strategies
    ///
    /// - ``sequential``: Execute first, then second (middleware pattern)
    /// - ``racing``: Execute both concurrently, first result wins
    /// - ``fallback``: Execute first, use second if first throws
    public enum Composition: Sendable, Hashable {
        /// Execute first witness, then second witness sequentially.
        ///
        /// Use for middleware patterns where order matters:
        /// - Logging before and after operations
        /// - Authentication then authorization
        /// - Validation then processing
        ///
        /// ```swift
        /// let logged = api.compose(with: logger, strategy: .sequential)
        /// // logger.log called, then api.fetch called
        /// ```
        case sequential

        /// Execute both witnesses concurrently, returning the first result.
        ///
        /// Use for performance optimization where fastest wins:
        /// - Multiple cache backends
        /// - Parallel service queries
        /// - Load balancing
        ///
        /// ```swift
        /// let fast = cache1.compose(with: cache2, strategy: .racing)
        /// // Both called concurrently, first response returned
        /// ```
        case racing

        /// Execute first witness; if it throws, execute second witness.
        ///
        /// Use for redundancy and fallback patterns:
        /// - Primary with backup
        /// - Network with local cache
        /// - Remote with default values
        ///
        /// ```swift
        /// let resilient = network.compose(with: localCache, strategy: .fallback)
        /// // network.fetch called; if throws, localCache.fetch called
        /// ```
        case fallback
    }
}
