//// ===----------------------------------------------------------------------===//
////
//// This source file is part of the swift-primitives open source project
////
//// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-primitives
//// project authors
//// Licensed under Apache License v2.0
////
//// See LICENSE for license information
////
//// ===----------------------------------------------------------------------===//
//
//extension Witness {
//    /// Strategies for composing multiple witness implementations.
//    ///
//    /// When combining witnesses (e.g., for middleware or layered behavior),
//    /// the composition strategy determines how multiple implementations interact.
//    ///
//    /// ## Example
//    ///
//    /// ```swift
//    /// @Witness(composition: .sequential)
//    /// struct Logger: Sendable {
//    ///     var log: (_ message: String) -> Void
//    /// }
//    ///
//    /// let combined = Logger.combine(consoleLogger, fileLogger)
//    /// combined.log(message: "Hello")  // Logs to console, then to file
//    /// ```
//    public enum Composition: Sendable, Hashable {
//        /// Execute first witness, then second witness sequentially.
//        ///
//        /// Use for middleware patterns where order matters:
//        /// - Logging before and after
//        /// - Authentication then authorization
//        /// - Validation then processing
//        case sequential
//
//        /// Execute both witnesses concurrently, returning the first result.
//        ///
//        /// Use for redundancy or fallback patterns:
//        /// - Multiple backends where fastest wins
//        /// - Primary with fallback
//        case racing
//    }
//}
