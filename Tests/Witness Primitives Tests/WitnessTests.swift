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

import Testing
import Witness_Primitives

// MARK: - Tests

@Suite("Witness Primitives")
struct WitnessPrimitivesTests {

    @Test("Witness namespace exists")
    func witnessNamespaceExists() {
        // Verify the Witness enum exists and can be used as a namespace
        func acceptWitnessProtocol<T: Witness.`Protocol`>(_ type: T.Type) {}

        // Manual conformance should work
        struct ManualWitness: Witness.`Protocol` {
            var operation: @Sendable () -> Void
        }

        acceptWitnessProtocol(ManualWitness.self)
    }

    @Test("Witness.`Protocol` is a marker protocol")
    func witnessProtocolIsMarker() {
        // Verify the protocol has no requirements beyond Sendable
        struct MinimalWitness: Witness.`Protocol` {}

        // Should compile and be Sendable
        let witness: any Sendable = MinimalWitness()
        _ = witness
    }

    @Test("__WitnessProtocol typealias exists for macro use")
    func witnessProtocolTypealiasExists() {
        // Verify the internal typealias exists
        func acceptWitnessProtocol<T: __WitnessProtocol>(_ type: T.Type) {}

        struct TestWitness: __WitnessProtocol {}
        acceptWitnessProtocol(TestWitness.self)
    }
}
