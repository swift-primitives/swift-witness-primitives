import Testing

@testable import Witness_Primitives

extension Witness {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Witness.Test.Unit {
    @Test
    func `namespace exists and can be used for type containment`() {
        func acceptWitnessProtocol<T: Witness.`Protocol`>(_ type: T.Type) {}

        struct Fixture: Witness.`Protocol` {
            var operation: @Sendable () -> Void
        }

        acceptWitnessProtocol(Fixture.self)
    }

    @Test
    func `Witness.Protocol is a pure marker protocol with no requirements`() {
        struct Fixture: Witness.`Protocol` {}

        let _: any Witness.`Protocol` = Fixture()
    }
}

extension Witness.Test.`Edge Case` {
    @Test
    func `__WitnessProtocol typealias exists for macro use`() {
        func accept<T: __WitnessProtocol>(_ type: T.Type) {}
        struct Fixture: __WitnessProtocol {}
        accept(Fixture.self)
    }
}
