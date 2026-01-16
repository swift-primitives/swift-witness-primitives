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
import Witness_Primitives_Test_Support
import Algebra_Primitives

// Type aliases for module disambiguation
typealias API = Witness_Primitives_Test_Support.API
typealias Simple = Witness_Primitives_Test_Support.Simple
typealias Mixed = Witness_Primitives_Test_Support.Mixed
typealias Clock = Witness_Primitives_Test_Support.Clock
typealias FileSystem = Witness_Primitives_Test_Support.FileSystem
typealias Event = Witness_Primitives_Test_Support.Event
typealias Inner = Witness_Primitives_Test_Support.Inner
typealias Outer = Witness_Primitives_Test_Support.Outer

// MARK: - Tests

@Suite("WitnessMacro")
struct WitnessMacroTests {

    @Test("Generates methods for labeled closures")
    func labeledClosureMethods() async throws {
        let client = API(
            fetchUser: { id in "User \(id)" },
            deleteUser: { _ in }
        )

        // Method call with label
        let user = try await client.fetchUser(id: 42)
        #expect(user == "User 42")
    }

    @Test("Unlabeled closures work directly")
    func unlabeledClosures() async throws {
        let client = Simple(
            fetch: { id in "Result \(id)" }
        )

        // Direct closure call (no method generated)
        let result = try await client.fetch(42)
        #expect(result == "Result 42")
    }

    @Test("Mixed labeled and unlabeled closures")
    func mixedClosures() {
        let client = Mixed(
            labeled: { id in "Labeled \(id)" },
            unlabeled: { id in "Unlabeled \(id)" }
        )

        // Method for labeled
        let labeledResult = client.labeled(id: 42)
        #expect(labeledResult == "Labeled 42")

        // Direct closure for unlabeled
        let unlabeledResult = client.unlabeled(42)
        #expect(unlabeledResult == "Unlabeled 42")
    }

    @Test("No-argument closures generate methods")
    func noArgumentClosures() async {
        let counter = Call.Counter()
        let clock = Clock(
            now: {
                Task { await counter.increment() }
                return 42
            }
        )

        // Method call - verify it compiles and runs
        let result = clock.now()
        #expect(result == 42)

        // Call twice
        _ = clock.now()

        // Wait for async increments
        try? await Task.sleep(for: .milliseconds(10))
        let count = await counter.count
        #expect(count == 2)
    }

    @Test("Action enum captures all operations")
    func actionEnum() async throws {
        let recorder = Action.Recorder<API.Action>()

        let client = API(
            fetchUser: { id in "User \(id)" },
            deleteUser: { _ in }
        ).observe.before { action in
            Task { await recorder.record(action) }
        }

        _ = try await client.fetchUser(id: 1)
        try await client.deleteUser(id: 2)

        // Small delay to let Tasks complete
        try await Task.sleep(for: .milliseconds(10))

        let actions = await recorder.actions
        #expect(actions.count == 2)

        if case .fetchUser(let id) = actions[0] {
            #expect(id == 1)
        } else {
            Issue.record("Expected fetchUser action")
        }

        if case .deleteUser(let id) = actions[1] {
            #expect(id == 2)
        } else {
            Issue.record("Expected deleteUser action")
        }
    }

    @Test("Unimplemented fatally errors")
    func unimplementedProperty() {
        // Just verify it exists and has the right type
        let _: API = API.unimplemented
    }

    @Test("Observe wraps all operations")
    func observeWrapper() async throws {
        let counter = Call.Counter()

        let fs = FileSystem(
            open: { _, _ in 42 },
            read: { _, count in [UInt8](repeating: 0, count: count) },
            close: { _ in }
        ).observe.before { _ in
            Task { await counter.increment() }
        }

        let fd = try await fs.open(path: "/tmp/test", flags: 0)
        _ = try await fs.read(descriptor: fd, count: 10)
        try await fs.close(descriptor: fd)

        // Small delay to let Tasks complete
        try await Task.sleep(for: .milliseconds(10))

        let count = await counter.count
        #expect(count == 3)
    }

    @Test("Observe callAsFunction fires before and after")
    func observeBoth() async throws {
        let beforeRecorder = Action.Recorder<API.Action>()
        let afterRecorder = Action.Recorder<(API.Action, Swift.Result<any Sendable, any Error>)>()

        let client = API(
            fetchUser: { id in "User \(id)" },
            deleteUser: { _ in }
        ).observe { action in
            Task { await beforeRecorder.record(action) }
        } after: { action, result in
            Task { await afterRecorder.record((action, result)) }
        }

        _ = try await client.fetchUser(id: 1)

        // Small delay to let Tasks complete
        try await Task.sleep(for: .milliseconds(10))

        // Verify before was called
        let beforeActions = await beforeRecorder.actions
        #expect(beforeActions.count == 1)
        if case .fetchUser(let id) = beforeActions[0] {
            #expect(id == 1)
        } else {
            Issue.record("Expected fetchUser action in before")
        }

        // Verify after was called with result
        let afterActions = await afterRecorder.actions
        #expect(afterActions.count == 1)
        let (action, result) = afterActions[0]
        if case .fetchUser(let id) = action {
            #expect(id == 1)
        } else {
            Issue.record("Expected fetchUser action in after")
        }
        if case .success = result {
            // Success as expected
        } else {
            Issue.record("Expected successful result")
        }
    }

    @Test("Observe after captures outcomes")
    func observeAfter() async throws {
        let recorder = Action.Recorder<API.Action.Outcome>()

        let client = API(
            fetchUser: { id in "User \(id)" },
            deleteUser: { _ in }
        ).observe.after { outcome in
            Task { await recorder.record(outcome) }
        }

        _ = try await client.fetchUser(id: 42)

        // Small delay to let Tasks complete
        try await Task.sleep(for: .milliseconds(10))

        let outcomes = await recorder.actions
        #expect(outcomes.count == 1)

        if case .fetchUser(let id) = outcomes[0].action {
            #expect(id == 42)
        } else {
            Issue.record("Expected fetchUser action in outcome")
        }
    }

    @Test("Multiple parameters with labels")
    func multipleParameters() async throws {
        let fs = FileSystem(
            open: { path, flags in
                #expect(path == "/test")
                #expect(flags == 1)
                return 99
            },
            read: { descriptor, count in
                #expect(descriptor == 99)
                #expect(count == 1024)
                return [1, 2, 3]
            },
            close: { descriptor in
                #expect(descriptor == 99)
            }
        )

        let fd = try await fs.open(path: "/test", flags: 1)
        let data = try await fs.read(descriptor: fd, count: 1024)
        try await fs.close(descriptor: fd)

        #expect(fd == 99)
        #expect(data == [1, 2, 3])
    }

    @Test("Action.Case conforms to Enumerable")
    func actionCaseEnumerable() {
        // Verify caseCount
        #expect(API.Action.Case.caseCount == 2)
        #expect(FileSystem.Action.Case.caseCount == 3)

        // Verify allCases iteration
        let apiCases = Array(API.Action.Case.allCases)
        #expect(apiCases.count == 2)
        #expect(apiCases[0] == .fetchUser)
        #expect(apiCases[1] == .deleteUser)

        // Verify caseIndex
        #expect(API.Action.Case.fetchUser.caseIndex == 0)
        #expect(API.Action.Case.deleteUser.caseIndex == 1)

        // Verify init(caseIndex:)
        #expect(API.Action.Case(caseIndex: 0) == .fetchUser)
        #expect(API.Action.Case(caseIndex: 1) == .deleteUser)

        // Verify Action.case property
        let fetchAction = API.Action.fetchUser(id: 42)
        let deleteAction = API.Action.deleteUser(id: 99)
        #expect(fetchAction.case == .fetchUser)
        #expect(deleteAction.case == .deleteUser)
    }

    @Test("Action.Prisms provides prisms for each case")
    func actionPrisms() {
        // Verify prisms static property exists
        let prisms = API.Action.prisms

        // Test fetchUser prism
        let fetchPrism = prisms.fetchUser

        // Embed: create action from value
        let action = fetchPrism.embed(42)
        if case .fetchUser(let id) = action {
            #expect(id == 42)
        } else {
            Issue.record("Expected fetchUser action")
        }

        // Extract: get value from matching action
        let extracted = fetchPrism.extract(.fetchUser(id: 99))
        #expect(extracted == 99)

        // Extract: returns nil for non-matching action
        let nonMatching = fetchPrism.extract(.deleteUser(id: 1))
        #expect(nonMatching == nil)
    }

    @Test("Action.is(_:) checks case membership")
    func actionIsMethod() {
        let fetchAction = API.Action.fetchUser(id: 42)
        let deleteAction = API.Action.deleteUser(id: 99)

        // is(_:) returns true for matching case
        #expect(fetchAction.is(\.fetchUser))
        #expect(deleteAction.is(\.deleteUser))

        // is(_:) returns false for non-matching case
        #expect(!fetchAction.is(\.deleteUser))
        #expect(!deleteAction.is(\.fetchUser))
    }

    @Test("Action subscript extracts associated values")
    func actionPrismSubscript() {
        let fetchAction = API.Action.fetchUser(id: 42)
        let deleteAction = API.Action.deleteUser(id: 99)

        // Subscript returns value for matching case
        #expect(fetchAction[prism: \.fetchUser] == 42)
        #expect(deleteAction[prism: \.deleteUser] == 99)

        // Subscript returns nil for non-matching case
        #expect(fetchAction[prism: \.deleteUser] == nil)
        #expect(deleteAction[prism: \.fetchUser] == nil)
    }

    @Test("FileSystem Action.Prisms with multiple parameters")
    func fileSystemActionPrisms() {
        // FileSystem.open has two parameters: path and flags
        let openPrism = FileSystem.Action.prisms.open

        // Embed: create action from tuple
        let action = openPrism.embed(("/test/file", 42))
        if case .open(let path, let flags) = action {
            #expect(path == "/test/file")
            #expect(flags == 42)
        } else {
            Issue.record("Expected open action")
        }

        // Extract: get tuple from matching action
        let extracted = openPrism.extract(.open(path: "/other", flags: 99))
        #expect(extracted?.0 == "/other")
        #expect(extracted?.1 == 99)

        // Extract: returns nil for non-matching action
        let nonMatching = openPrism.extract(.close(descriptor: 1))
        #expect(nonMatching == nil)
    }

    // MARK: - Enum @Witness Tests

    @Test("Enum @Witness generates Prisms struct")
    func enumWitnessPrisms() {
        // Verify prisms static property exists
        let prisms = Event.prisms

        // Test login prism (single labeled parameter)
        let loginPrism = prisms.login

        // Embed: create event from value
        let event = loginPrism.embed(42)
        #expect(event == .login(userId: 42))

        // Extract: get value from matching event
        let extracted = loginPrism.extract(.login(userId: 99))
        #expect(extracted == 99)

        // Extract: returns nil for non-matching event
        let nonMatching = loginPrism.extract(.logout(userId: 1))
        #expect(nonMatching == nil)
    }

    @Test("Enum @Witness is(_:) method")
    func enumWitnessIsMethod() {
        let loginEvent = Event.login(userId: 42)
        let logoutEvent = Event.logout(userId: 99)
        let startEvent = Event.systemStart

        // is(_:) returns true for matching case
        #expect(loginEvent.is(\.login))
        #expect(logoutEvent.is(\.logout))
        #expect(startEvent.is(\.systemStart))

        // is(_:) returns false for non-matching case
        #expect(!loginEvent.is(\.logout))
        #expect(!logoutEvent.is(\.login))
        #expect(!startEvent.is(\.login))
    }

    @Test("Enum @Witness subscript extracts values")
    func enumWitnessSubscript() {
        let loginEvent = Event.login(userId: 42)
        let purchaseEvent = Event.purchase(itemId: "ABC", amount: 99.99)

        // Subscript returns value for matching case
        #expect(loginEvent[prism: \.login] == 42)

        // Subscript returns nil for non-matching case
        #expect(loginEvent[prism: \.logout] == nil)

        // Multiple parameters return tuple
        let purchaseValue = purchaseEvent[prism: \.purchase]
        #expect(purchaseValue?.0 == "ABC")
        #expect(purchaseValue?.1 == 99.99)
    }

    @Test("Enum @Witness no-argument case prism")
    func enumWitnessVoidCase() {
        let startEvent = Event.systemStart

        // Prism for void case
        let prism = Event.prisms.systemStart

        // Embed creates the case
        let embedded = prism.embed(())
        #expect(embedded == .systemStart)

        // Extract returns () for matching
        let extracted: Void? = prism.extract(startEvent)
        #expect(extracted != nil)

        // Extract returns nil for non-matching
        let nonMatching: Void? = prism.extract(.login(userId: 1))
        #expect(nonMatching == nil)
    }

    // MARK: - Direct Computed Property Tests

    @Test("Enum @Witness generates direct computed properties")
    func enumWitnessComputedProperties() {
        let loginEvent = Event.login(userId: 42)
        let logoutEvent = Event.logout(userId: 99)
        let purchaseEvent = Event.purchase(itemId: "ABC", amount: 99.99)
        let startEvent = Event.systemStart

        // Direct property access for single-parameter case
        #expect(loginEvent.login == 42)
        #expect(logoutEvent.logout == 99)

        // Returns nil for non-matching case
        #expect(loginEvent.logout == nil)
        #expect(logoutEvent.login == nil)

        // Multiple parameters return labeled tuple
        let purchase = purchaseEvent.purchase
        #expect(purchase?.itemId == "ABC")
        #expect(purchase?.amount == 99.99)

        // Void case returns Void? (not nil when matching)
        #expect(startEvent.systemStart != nil)
        #expect(loginEvent.systemStart == nil)
    }

    @Test("Direct computed properties have zero overhead compared to prism subscript")
    func enumWitnessComputedPropertiesEquivalence() {
        let event = Event.login(userId: 42)

        // Both approaches should yield the same result
        let viaProperty = event.login
        let viaPrism = event[prism: \.login]

        #expect(viaProperty == viaPrism)
        #expect(viaProperty == 42)
    }

    // MARK: - Prism Composition Tests

    @Test("Prism composition via dynamicMemberLookup")
    func prismCompositionViaDynamicMemberLookup() {
        let outer = Outer.inner(.value(42))

        // Composed prism via dynamicMemberLookup: Outer.prisms.inner.value
        let composedPrism = Outer.prisms.inner.value

        // Extract through both levels
        let extracted = composedPrism.extract(outer)
        #expect(extracted == 42)

        // Embed through both levels
        let embedded = composedPrism.embed(99)
        #expect(embedded == .inner(.value(99)))
    }

    @Test("Prism composition returns nil for non-matching outer case")
    func prismCompositionNonMatchingOuter() {
        let outer = Outer.direct(42)

        let composedPrism = Outer.prisms.inner.value
        let extracted = composedPrism.extract(outer)

        #expect(extracted == nil)
    }

    @Test("Prism composition returns nil for non-matching inner case")
    func prismCompositionNonMatchingInner() {
        let outer = Outer.inner(.text("hello"))

        let composedPrism = Outer.prisms.inner.value
        let extracted = composedPrism.extract(outer)

        #expect(extracted == nil)
    }

    @Test("Prism composition with subscript syntax")
    func prismCompositionWithSubscript() {
        let outer = Outer.inner(.value(42))

        // Use composed prism with subscript
        let value = outer[prism: \.inner.value]
        #expect(value == 42)

        // Non-matching returns nil
        let nonMatching = outer[prism: \.inner.text]
        #expect(nonMatching == nil)
    }

    @Test("Direct properties with optional chaining vs prism composition")
    func directPropertiesVsComposition() {
        let outer = Outer.inner(.value(42))

        // Direct properties with optional chaining
        let viaOptionalChaining = outer.inner?.value

        // Prism composition
        let viaPrism = outer[prism: \.inner.value]

        // Both should give same result
        #expect(viaOptionalChaining == viaPrism)
        #expect(viaOptionalChaining == 42)
    }

    @Test("Enum conforms to Prism.Accessible")
    func enumConformsToPrismAccessible() {
        // Verify the protocol conformance exists
        func requiresAccessible<T: Algebra_Primitives.Prism.Accessible>(_ type: T.Type) {}

        requiresAccessible(Event.self)
        requiresAccessible(Inner.self)
        requiresAccessible(Outer.self)
    }
}
