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
import Testing_Extras
@testable import Witness_Primitives

extension Witness {
    #TestSuites
}

// MARK: - Unit Tests

extension Witness.Test.Unit {
    @Test("namespace exists and can be used for type containment")
    func namespaceExists() {
        func acceptWitnessProtocol<T: Witness.`Protocol`>(_ type: T.Type) {}

        struct ManualWitness: Witness.`Protocol` {
            var operation: @Sendable () -> Void
        }

        acceptWitnessProtocol(ManualWitness.self)
    }

    @Test("Witness.Protocol is a marker protocol with no requirements beyond Sendable")
    func protocolIsMarker() {
        struct MinimalWitness: Witness.`Protocol` {}

        let witness: any Sendable = MinimalWitness()
        _ = witness
    }
}

// MARK: - Edge Cases

extension Witness.Test.EdgeCase {
    @Test("__WitnessProtocol typealias exists for macro use")
    func typealiasExists() {
        func accept<T: __WitnessProtocol>(_ type: T.Type) {}
        struct TestWitness: __WitnessProtocol {}
        accept(TestWitness.self)
    }
}
