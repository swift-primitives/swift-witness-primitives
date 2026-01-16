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

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - WitnessMacro

public struct WitnessMacro {}

// MARK: - MemberMacro

extension WitnessMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Handle enum declarations
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return expandEnum(enumDecl: enumDecl, node: node, context: context)
        }

        // Handle struct declarations
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: node,
                message: WitnessDiagnostic.requiresStructOrEnum
            ))
            return []
        }

        return expandStruct(structDecl: structDecl, node: node, context: context)
    }

    private static func expandStruct(
        structDecl: StructDeclSyntax,
        node: AttributeSyntax,
        context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let closureProperties = extractClosureProperties(from: structDecl)

        guard !closureProperties.isEmpty else {
            context.diagnose(Diagnostic(
                node: node,
                message: WitnessDiagnostic.noClosureProperties
            ))
            return []
        }

        var members: [DeclSyntax] = []

        // Determine access level
        let isPublic = structDecl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }

        // Generate public initializer if needed
        if isPublic {
            members.append(generatePublicInit(for: closureProperties, structDecl: structDecl))
        }

        // Generate methods for labeled closures
        for property in closureProperties where property.hasLabels {
            if let method = generateMethod(for: property) {
                members.append(method)
            }
        }

        // Generate Action enum
        members.append(generateActionEnum(for: closureProperties))

        // Generate unimplemented static property
        members.append(generateUnimplemented(for: closureProperties, structName: structDecl.name.text))

        // Generate Observe accessor struct and property
        members.append(generateObserveStruct(for: closureProperties, structName: structDecl.name.text))
        members.append(generateObserveProperty())

        return members
    }

    private static func expandEnum(
        enumDecl: EnumDeclSyntax,
        node: AttributeSyntax,
        context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let enumCases = extractEnumCases(from: enumDecl)

        guard !enumCases.isEmpty else {
            context.diagnose(Diagnostic(
                node: node,
                message: WitnessDiagnostic.noEnumCases
            ))
            return []
        }

        let enumName = enumDecl.name.text
        return generateEnumPrismMembers(for: enumCases, enumName: enumName)
    }
}

// MARK: - MemberAttributeMacro

extension WitnessMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // No attributes for enum members
        if declaration.is(EnumDeclSyntax.self) {
            return []
        }

        guard let varDecl = member.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation,
              let functionType = extractFunctionType(from: typeAnnotation.type) else {
            return []
        }

        // Only deprecate if the closure has labeled parameters
        let hasLabels = functionType.parameters.contains { param in
            param.secondName != nil
        }

        guard hasLabels else { return [] }

        let methodSignature = generateMethodSignature(
            name: identifier.identifier.text,
            functionType: functionType
        )

        // Use string parsing for simpler attribute construction
        let attributeString = "@available(*, deprecated, message: \"Use '\(methodSignature)' instead\")"
        let attribute = AttributeSyntax(stringLiteral: attributeString)
        return [attribute]
    }
}

// MARK: - ExtensionMacro

extension WitnessMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        var extensions: [ExtensionDeclSyntax] = []

        // All @Witness types conform to __WitnessProtocol
        let witnessExt = try ExtensionDeclSyntax("extension \(type.trimmed): __WitnessProtocol {}")
        extensions.append(witnessExt)

        // Enums also conform to Prism.Accessible for composition support
        // Uses hoisted __PrismAccessible since Prism.Accessible is a typealias
        if declaration.is(EnumDeclSyntax.self) {
            let prismExt = try ExtensionDeclSyntax("extension \(type.trimmed): Algebra_Primitives.__PrismAccessible {}")
            extensions.append(prismExt)
        }

        return extensions
    }
}

// MARK: - Property Extraction

struct ClosureProperty {
    let name: String
    let functionType: FunctionTypeSyntax
    let parameters: [ClosureParameter]
    let hasLabels: Bool
    let isAsync: Bool
    let isThrowing: Bool
    let returnType: TypeSyntax
}

struct ClosureParameter {
    let label: String?
    let internalName: String
    let type: TypeSyntax
    let isInout: Bool
}

private func extractClosureProperties(from structDecl: StructDeclSyntax) -> [ClosureProperty] {
    var properties: [ClosureProperty] = []

    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              varDecl.bindingSpecifier.tokenKind == .keyword(.var),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation,
              let functionType = extractFunctionType(from: typeAnnotation.type) else {
            continue
        }

        let parameters = extractParameters(from: functionType)
        let hasLabels = parameters.contains { $0.label != nil }

        properties.append(ClosureProperty(
            name: identifier.identifier.text,
            functionType: functionType,
            parameters: parameters,
            hasLabels: hasLabels,
            isAsync: functionType.effectSpecifiers?.asyncSpecifier != nil,
            isThrowing: functionType.effectSpecifiers?.throwsClause != nil,
            returnType: functionType.returnClause.type
        ))
    }

    return properties
}

private func extractFunctionType(from type: TypeSyntax) -> FunctionTypeSyntax? {
    // Direct function type
    if let functionType = type.as(FunctionTypeSyntax.self) {
        return functionType
    }

    // Attributed type (e.g., @Sendable)
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return extractFunctionType(from: attributed.baseType)
    }

    return nil
}

private func extractParameters(from functionType: FunctionTypeSyntax) -> [ClosureParameter] {
    var parameters: [ClosureParameter] = []

    for (index, param) in functionType.parameters.enumerated() {
        let label = param.secondName?.text
        let internalName = label ?? "p\(index)"
        let isInout = param.type.is(AttributedTypeSyntax.self) &&
            param.type.as(AttributedTypeSyntax.self)?.specifiers.contains(where: {
                $0.as(SimpleTypeSpecifierSyntax.self)?.specifier.tokenKind == .keyword(.inout)
            }) == true

        parameters.append(ClosureParameter(
            label: label,
            internalName: internalName,
            type: param.type,
            isInout: isInout
        ))
    }

    return parameters
}

// MARK: - Public Init Generation

private func generatePublicInit(for properties: [ClosureProperty], structDecl: StructDeclSyntax) -> DeclSyntax {
    // Extract full type syntax from the struct's member declarations
    var fullTypes: [String: String] = [:]
    for member in structDecl.memberBlock.members {
        if let varDecl = member.decl.as(VariableDeclSyntax.self),
           let binding = varDecl.bindings.first,
           let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
           let typeAnnotation = binding.typeAnnotation {
            fullTypes[identifier.identifier.text] = typeAnnotation.type.trimmedDescription
        }
    }

    let parameters = properties.map { property in
        let fullType = fullTypes[property.name] ?? "\(property.functionType)"
        return "\(property.name): @escaping \(fullType)"
    }.joined(separator: ",\n        ")

    let assignments = properties.map { property in
        "self.\(property.name) = \(property.name)"
    }.joined(separator: "\n        ")

    return """
        public init(
            \(raw: parameters)
        ) {
            \(raw: assignments)
        }
        """
}

// MARK: - Method Generation

private func generateMethod(for property: ClosureProperty) -> DeclSyntax? {
    guard property.hasLabels else { return nil }

    let parameters = property.parameters.enumerated().map { index, param in
        let label = param.label ?? "_"
        let internalName = "p\(index)"
        return "\(label) \(internalName): \(param.type)"
    }.joined(separator: ", ")

    let effectSpecifiers: String = {
        var specs: [String] = []
        if property.isAsync { specs.append("async") }
        if property.isThrowing { specs.append("throws") }
        return specs.isEmpty ? "" : " " + specs.joined(separator: " ")
    }()

    let returnClause = property.returnType.description.trimmingCharacters(in: .whitespaces) == "Void"
        ? ""
        : " -> \(property.returnType)"

    let callArguments = property.parameters.enumerated().map { index, param in
        let prefix = param.isInout ? "&" : ""
        return "\(prefix)p\(index)"
    }.joined(separator: ", ")

    let awaitKeyword = property.isAsync ? "await " : ""
    let tryKeyword = property.isThrowing ? "try " : ""

    return """
        @inlinable
        public func \(raw: property.name)(\(raw: parameters))\(raw: effectSpecifiers)\(raw: returnClause) {
            \(raw: tryKeyword)\(raw: awaitKeyword)self.\(raw: property.name)(\(raw: callArguments))
        }
        """
}

private func generateMethodSignature(name: String, functionType: FunctionTypeSyntax) -> String {
    let labels = functionType.parameters.enumerated().map { index, param in
        param.secondName?.text ?? "_"
    }

    if labels.isEmpty {
        return "\(name)()"
    }

    let labelString = labels.map { "\($0):" }.joined()
    return "\(name)(\(labelString))"
}

// MARK: - Action Enum Generation

private func generateActionEnum(for properties: [ClosureProperty]) -> DeclSyntax {
    let caseCount = properties.count

    // Generate Action cases (inputs only)
    let actionCases = properties.map { property in
        if property.parameters.isEmpty {
            return "case \(property.name)"
        }

        let associatedValues = property.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): \(param.type)"
            } else {
                return "\(param.type)"
            }
        }.joined(separator: ", ")

        return "case \(property.name)(\(associatedValues))"
    }.joined(separator: "\n            ")

    // Generate Case enum cases (no associated values)
    let caseCases = properties.map { "case \($0.name)" }.joined(separator: "\n                ")

    // Generate Case.caseIndex switch
    let caseIndexCases = properties.enumerated().map { index, property in
        "case .\(property.name): \(index)"
    }.joined(separator: "\n                    ")

    // Generate Case.init(caseIndex:) switch
    let caseInitCases = properties.enumerated().map { index, property in
        "case \(index): self = .\(property.name)"
    }.joined(separator: "\n                    ")

    // Generate Action.case property switch
    let actionCaseCases = properties.map { property in
        "case .\(property.name): .\(property.name)"
    }.joined(separator: "\n                ")

    // Generate Prisms struct properties
    let prismProperties = generatePrismProperties(for: properties)

    // Structure:
    // - Action enum has cases for each closure (inputs only)
    // - Action.Case is the enumerable discriminant (no associated values)
    // - Action.Outcome is a generic struct (action + result)
    // - Action.Prisms provides prisms for each case
    return """
        public enum Action: Sendable {
            \(raw: actionCases)

            /// The enumerable case discriminant (without associated values).
            public enum Case: Finite_Primitives.Finite.Enumerable, Sendable {
                \(raw: caseCases)

                @inlinable
                public static var caseCount: Int { \(raw: caseCount) }

                @inlinable
                public var caseIndex: Int {
                    switch self {
                    \(raw: caseIndexCases)
                    }
                }

                @inlinable
                public init(caseIndex: Int) {
                    switch caseIndex {
                    \(raw: caseInitCases)
                    default: fatalError("Invalid case index \\(caseIndex) for Action.Case")
                    }
                }
            }

            /// This action's case discriminant.
            @inlinable
            public var `case`: Case {
                switch self {
                \(raw: actionCaseCases)
                }
            }

            public struct Outcome: Sendable {
                public let action: Action
                public let result: Swift.Result<any Sendable, any Error>

                @inlinable
                public init(action: Action, result: Swift.Result<any Sendable, any Error>) {
                    self.action = action
                    self.result = result
                }
            }

            /// Prisms for each action case, enabling type-safe case matching and extraction.
            public struct Prisms: Sendable {
                @inlinable
                public init() {}

                \(raw: prismProperties)
            }

            /// Access prisms for each action case.
            @inlinable
            public static var prisms: Prisms { Prisms() }

            /// Checks if this action matches the given prism.
            ///
            /// - Parameter keyPath: A key path to a prism in `Prisms`.
            /// - Returns: `true` if this action matches the prism's case.
            @inlinable
            public func `is`<Value>(_ keyPath: KeyPath<Prisms, Algebra_Primitives.Prism<Action, Value>>) -> Bool {
                Self.prisms[keyPath: keyPath].extract(self) != nil
            }

            /// Extracts the associated value for the given prism, if this action matches.
            ///
            /// - Parameter keyPath: A key path to a prism in `Prisms`.
            /// - Returns: The extracted value, or `nil` if this action doesn't match.
            @inlinable
            public subscript<Value>(prism keyPath: KeyPath<Prisms, Algebra_Primitives.Prism<Action, Value>>) -> Value? {
                Self.prisms[keyPath: keyPath].extract(self)
            }
        }
        """
}

/// Generates prism properties for each closure property.
private func generatePrismProperties(for properties: [ClosureProperty]) -> String {
    properties.map { property in
        generatePrismProperty(for: property)
    }.joined(separator: "\n\n                ")
}

/// Generates a single prism property for a closure property.
private func generatePrismProperty(for property: ClosureProperty) -> String {
    if property.parameters.isEmpty {
        // Case with no associated values - prism to Void
        return """
        public var \(property.name): Algebra_Primitives.Prism<Action, Void> {
                    Algebra_Primitives.Prism(
                        embed: { _ in .\(property.name) },
                        extract: { if case .\(property.name) = $0 { return () } else { return nil } }
                    )
                }
        """
    } else if property.parameters.count == 1 {
        // Single parameter - prism directly to that type
        let param = property.parameters[0]
        let paramType = param.type.description.trimmingCharacters(in: .whitespaces)
        let embedArg = param.label != nil ? "\(param.label!): $0" : "$0"
        let extractPattern = param.label != nil ? "\(param.label!): let v" : "let v"

        return """
        public var \(property.name): Algebra_Primitives.Prism<Action, \(paramType)> {
                    Algebra_Primitives.Prism(
                        embed: { .\(property.name)(\(embedArg)) },
                        extract: { if case .\(property.name)(\(extractPattern)) = $0 { return v } else { return nil } }
                    )
                }
        """
    } else {
        // Multiple parameters - prism to a tuple
        let tupleTypes = property.parameters.map { param in
            param.type.description.trimmingCharacters(in: .whitespaces)
        }.joined(separator: ", ")

        let embedArgs = property.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): $0.\(index)"
            } else {
                return "$0.\(index)"
            }
        }.joined(separator: ", ")

        let extractPatterns = property.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): let v\(index)"
            } else {
                return "let v\(index)"
            }
        }.joined(separator: ", ")

        let extractTuple = property.parameters.indices.map { "v\($0)" }.joined(separator: ", ")

        return """
        public var \(property.name): Algebra_Primitives.Prism<Action, (\(tupleTypes))> {
                    Algebra_Primitives.Prism(
                        embed: { .\(property.name)(\(embedArgs)) },
                        extract: { if case .\(property.name)(\(extractPatterns)) = $0 { return (\(extractTuple)) } else { return nil } }
                    )
                }
        """
    }
}

// MARK: - Unimplemented Generation

private func generateUnimplemented(for properties: [ClosureProperty], structName: String) -> DeclSyntax {
    let closures = properties.map { property in
        let wildcards = property.parameters.isEmpty
            ? ""
            : property.parameters.map { _ in "_" }.joined(separator: ", ")

        let signature = generateMethodSignature(name: property.name, functionType: property.functionType)

        if wildcards.isEmpty {
            return "\(property.name): { fatalError(\"unimplemented: \(structName).\(signature)\") }"
        } else {
            return "\(property.name): { \(wildcards) in fatalError(\"unimplemented: \(structName).\(signature)\") }"
        }
    }.joined(separator: ",\n            ")

    return """
        public static var unimplemented: Self {
            Self(
                \(raw: closures)
            )
        }
        """
}

// MARK: - Observe Accessor Generation

private func generateObserveStruct(for properties: [ClosureProperty], structName: String) -> DeclSyntax {
    // Generate callAsFunction closures (both - before and after with two closures)
    let bothClosures = properties.map { property -> String in
        generateBothObserveClosure(for: property, structName: structName)
    }.joined(separator: ",\n                    ")

    // Generate before closures
    let beforeClosures = properties.map { property -> String in
        generateBeforeObserveClosure(for: property, structName: structName)
    }.joined(separator: ",\n                    ")

    // Generate after closures
    let afterClosures = properties.map { property -> String in
        generateAfterObserveClosure(for: property, structName: structName)
    }.joined(separator: ",\n                    ")

    return """
        public struct Observe: Sendable {
            @usableFromInline
            internal let witness: \(raw: structName)

            @usableFromInline
            internal init(_ witness: \(raw: structName)) {
                self.witness = witness
            }

            @inlinable
            public func callAsFunction(
                _ before: @escaping @Sendable (Action) -> Void,
                after: @escaping @Sendable (Action, Swift.Result<any Sendable, any Error>) -> Void
            ) -> \(raw: structName) {
                \(raw: structName)(
                    \(raw: bothClosures)
                )
            }

            @inlinable
            public func before(
                _ observer: @escaping @Sendable (Action) -> Void
            ) -> \(raw: structName) {
                \(raw: structName)(
                    \(raw: beforeClosures)
                )
            }

            @inlinable
            public func after(
                _ observer: @escaping @Sendable (Action.Outcome) -> Void
            ) -> \(raw: structName) {
                \(raw: structName)(
                    \(raw: afterClosures)
                )
            }
        }
        """
}

private func generateObserveProperty() -> DeclSyntax {
    return """
        public var observe: Observe {
            Observe(self)
        }
        """
}

private func generateBothObserveClosure(for property: ClosureProperty, structName: String) -> String {
    let captureList = "[witness]"
    let parameterNames = property.parameters.enumerated().map { index, param in
        param.label ?? "p\(index)"
    }
    let closureParams = parameterNames.isEmpty ? "" : parameterNames.joined(separator: ", ")
    let callArgs = parameterNames.joined(separator: ", ")
    let actionConstruction = formatActionConstruction(for: property)

    let awaitKeyword = property.isAsync ? "await " : ""

    let returnType = property.returnType.description.trimmingCharacters(in: .whitespaces)
    let hasReturn = returnType != "Void" && returnType != "()"
    let resultValue = hasReturn ? "result" : "()"

    if property.isThrowing {
        if closureParams.isEmpty {
            return """
            \(property.name): { \(captureList) in
                            let action: Action = \(actionConstruction)
                            before(action)
                            do {
                                \(hasReturn ? "let result = " : "")try \(awaitKeyword)witness.\(property.name)()
                                after(action, .success(\(resultValue)))
                                \(hasReturn ? "return result" : "")
                            } catch {
                                after(action, .failure(error))
                                throw error
                            }
                        }
            """
        } else {
            return """
            \(property.name): { \(captureList) \(closureParams) in
                            let action: Action = \(actionConstruction)
                            before(action)
                            do {
                                \(hasReturn ? "let result = " : "")try \(awaitKeyword)witness.\(property.name)(\(callArgs))
                                after(action, .success(\(resultValue)))
                                \(hasReturn ? "return result" : "")
                            } catch {
                                after(action, .failure(error))
                                throw error
                            }
                        }
            """
        }
    } else {
        if closureParams.isEmpty {
            return """
            \(property.name): { \(captureList) in
                            let action: Action = \(actionConstruction)
                            before(action)
                            \(hasReturn ? "let result = " : "")\(awaitKeyword)witness.\(property.name)()
                            after(action, .success(\(resultValue)))
                            \(hasReturn ? "return result" : "")
                        }
            """
        } else {
            return """
            \(property.name): { \(captureList) \(closureParams) in
                            let action: Action = \(actionConstruction)
                            before(action)
                            \(hasReturn ? "let result = " : "")\(awaitKeyword)witness.\(property.name)(\(callArgs))
                            after(action, .success(\(resultValue)))
                            \(hasReturn ? "return result" : "")
                        }
            """
        }
    }
}

private func generateBeforeObserveClosure(for property: ClosureProperty, structName: String) -> String {
    let captureList = "[witness]"
    let parameterNames = property.parameters.enumerated().map { index, param in
        param.label ?? "p\(index)"
    }
    let closureParams = parameterNames.isEmpty ? "" : parameterNames.joined(separator: ", ")
    let callArgs = parameterNames.joined(separator: ", ")
    let actionConstruction = formatActionConstruction(for: property)

    let awaitKeyword = property.isAsync ? "await " : ""
    let tryKeyword = property.isThrowing ? "try " : ""

    let returnType = property.returnType.description.trimmingCharacters(in: .whitespaces)
    let hasReturn = returnType != "Void" && returnType != "()"
    let returnKeyword = hasReturn ? "return " : ""

    if closureParams.isEmpty {
        return """
        \(property.name): { \(captureList) in
                        observer(\(actionConstruction))
                        \(returnKeyword)\(tryKeyword)\(awaitKeyword)witness.\(property.name)()
                    }
        """
    } else {
        return """
        \(property.name): { \(captureList) \(closureParams) in
                        observer(\(actionConstruction))
                        \(returnKeyword)\(tryKeyword)\(awaitKeyword)witness.\(property.name)(\(callArgs))
                    }
        """
    }
}

private func generateAfterObserveClosure(for property: ClosureProperty, structName: String) -> String {
    let captureList = "[witness]"
    let parameterNames = property.parameters.enumerated().map { index, param in
        param.label ?? "p\(index)"
    }
    let closureParams = parameterNames.isEmpty ? "" : parameterNames.joined(separator: ", ")
    let callArgs = parameterNames.joined(separator: ", ")
    let actionConstruction = formatActionConstruction(for: property)

    let awaitKeyword = property.isAsync ? "await " : ""

    let returnType = property.returnType.description.trimmingCharacters(in: .whitespaces)
    let hasReturn = returnType != "Void" && returnType != "()"
    let resultValue = hasReturn ? "result" : "()"

    if property.isThrowing {
        if closureParams.isEmpty {
            return """
            \(property.name): { \(captureList) in
                            let action: Action = \(actionConstruction)
                            do {
                                \(hasReturn ? "let result = " : "")try \(awaitKeyword)witness.\(property.name)()
                                observer(Action.Outcome(action: action, result: .success(\(resultValue))))
                                \(hasReturn ? "return result" : "")
                            } catch {
                                observer(Action.Outcome(action: action, result: .failure(error)))
                                throw error
                            }
                        }
            """
        } else {
            return """
            \(property.name): { \(captureList) \(closureParams) in
                            let action: Action = \(actionConstruction)
                            do {
                                \(hasReturn ? "let result = " : "")try \(awaitKeyword)witness.\(property.name)(\(callArgs))
                                observer(Action.Outcome(action: action, result: .success(\(resultValue))))
                                \(hasReturn ? "return result" : "")
                            } catch {
                                observer(Action.Outcome(action: action, result: .failure(error)))
                                throw error
                            }
                        }
            """
        }
    } else {
        if closureParams.isEmpty {
            return """
            \(property.name): { \(captureList) in
                            let action: Action = \(actionConstruction)
                            \(hasReturn ? "let result = " : "")\(awaitKeyword)witness.\(property.name)()
                            observer(Action.Outcome(action: action, result: .success(\(resultValue))))
                            \(hasReturn ? "return result" : "")
                        }
            """
        } else {
            return """
            \(property.name): { \(captureList) \(closureParams) in
                            let action: Action = \(actionConstruction)
                            \(hasReturn ? "let result = " : "")\(awaitKeyword)witness.\(property.name)(\(callArgs))
                            observer(Action.Outcome(action: action, result: .success(\(resultValue))))
                            \(hasReturn ? "return result" : "")
                        }
            """
        }
    }
}

/// Formats action construction: `.propertyName` or `.propertyName(label: value, ...)`
private func formatActionConstruction(for property: ClosureProperty) -> String {
    if property.parameters.isEmpty {
        return ".\(property.name)"
    }
    let args = property.parameters.enumerated().map { index, param in
        let name = param.label ?? "p\(index)"
        if let label = param.label {
            return "\(label): \(name)"
        } else {
            return name
        }
    }.joined(separator: ", ")
    return ".\(property.name)(\(args))"
}

// MARK: - Enum Case Extraction

struct EnumCase {
    let name: String
    let parameters: [EnumCaseParameter]
}

struct EnumCaseParameter {
    let label: String?
    let type: TypeSyntax
}

private func extractEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCase] {
    var cases: [EnumCase] = []

    for member in enumDecl.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
            continue
        }

        for element in caseDecl.elements {
            let name = element.name.text
            var parameters: [EnumCaseParameter] = []

            if let parameterClause = element.parameterClause {
                for param in parameterClause.parameters {
                    let label = param.firstName?.text
                    parameters.append(EnumCaseParameter(
                        label: label,
                        type: param.type
                    ))
                }
            }

            cases.append(EnumCase(name: name, parameters: parameters))
        }
    }

    return cases
}

// MARK: - Enum Prism Generation

private func generateEnumPrismMembers(for cases: [EnumCase], enumName: String) -> [DeclSyntax] {
    var members: [DeclSyntax] = []

    // Generate direct computed properties for each case (zero-overhead extraction)
    for enumCase in cases {
        members.append(generateEnumComputedProperty(for: enumCase))
    }

    // Generate Prisms struct
    let prismProperties = cases.map { enumCase in
        generateEnumPrismProperty(for: enumCase, enumName: enumName)
    }.joined(separator: "\n\n        ")

    let prismsStruct: DeclSyntax = """
        /// Prisms for each enum case, enabling type-safe case matching and extraction.
        public struct Prisms: Sendable {
            @inlinable
            public init() {}

            \(raw: prismProperties)
        }
        """
    members.append(prismsStruct)

    // Generate prisms static property
    let prismsProperty: DeclSyntax = """
        /// Access prisms for each enum case.
        @inlinable
        public static var prisms: Prisms { Prisms() }
        """
    members.append(prismsProperty)

    // Generate is(_:) method
    let isMethod: DeclSyntax = """
        /// Checks if this value matches the given prism.
        ///
        /// - Parameter keyPath: A key path to a prism in `Prisms`.
        /// - Returns: `true` if this value matches the prism's case.
        @inlinable
        public func `is`<Value>(_ keyPath: KeyPath<Prisms, Algebra_Primitives.Prism<\(raw: enumName), Value>>) -> Bool {
            Self.prisms[keyPath: keyPath].extract(self) != nil
        }
        """
    members.append(isMethod)

    // Generate subscript[prism:]
    let prismSubscript: DeclSyntax = """
        /// Extracts the associated value for the given prism, if this value matches.
        ///
        /// - Parameter keyPath: A key path to a prism in `Prisms`.
        /// - Returns: The extracted value, or `nil` if this value doesn't match.
        @inlinable
        public subscript<Value>(prism keyPath: KeyPath<Prisms, Algebra_Primitives.Prism<\(raw: enumName), Value>>) -> Value? {
            Self.prisms[keyPath: keyPath].extract(self)
        }
        """
    members.append(prismSubscript)

    return members
}

/// Generates a direct computed property for extracting an enum case's associated value.
///
/// This provides zero-overhead extraction compared to prism-based subscripts:
/// ```swift
/// // Generated:
/// var login: Int? {
///     if case .login(let v) = self { v } else { nil }
/// }
///
/// // Usage:
/// let value = status.login  // Direct property access, no indirection
/// ```
private func generateEnumComputedProperty(for enumCase: EnumCase) -> DeclSyntax {
    if enumCase.parameters.isEmpty {
        // Case with no associated values - property returns Void?
        return """
            /// Extracts `Void` if this is the `\(raw: enumCase.name)` case, otherwise `nil`.
            @inlinable
            public var \(raw: enumCase.name): Void? {
                if case .\(raw: enumCase.name) = self { () } else { nil }
            }
            """
    } else if enumCase.parameters.count == 1 {
        // Single parameter - property returns that type directly
        let param = enumCase.parameters[0]
        let paramType = param.type.description.trimmingCharacters(in: .whitespaces)
        let extractPattern = param.label != nil ? "\(param.label!): let v" : "let v"

        return """
            /// Extracts the associated value if this is the `\(raw: enumCase.name)` case, otherwise `nil`.
            @inlinable
            public var \(raw: enumCase.name): \(raw: paramType)? {
                if case .\(raw: enumCase.name)(\(raw: extractPattern)) = self { v } else { nil }
            }
            """
    } else {
        // Multiple parameters - property returns a tuple
        let tupleTypes = enumCase.parameters.map { param in
            if let label = param.label {
                return "\(label): \(param.type.description.trimmingCharacters(in: .whitespaces))"
            } else {
                return param.type.description.trimmingCharacters(in: .whitespaces)
            }
        }.joined(separator: ", ")

        let extractPatterns = enumCase.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): let v\(index)"
            } else {
                return "let v\(index)"
            }
        }.joined(separator: ", ")

        let extractTuple = enumCase.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): v\(index)"
            } else {
                return "v\(index)"
            }
        }.joined(separator: ", ")

        return """
            /// Extracts the associated values if this is the `\(raw: enumCase.name)` case, otherwise `nil`.
            @inlinable
            public var \(raw: enumCase.name): (\(raw: tupleTypes))? {
                if case .\(raw: enumCase.name)(\(raw: extractPatterns)) = self { (\(raw: extractTuple)) } else { nil }
            }
            """
    }
}

private func generateEnumPrismProperty(for enumCase: EnumCase, enumName: String) -> String {
    if enumCase.parameters.isEmpty {
        // Case with no associated values - prism to Void
        return """
        public var \(enumCase.name): Algebra_Primitives.Prism<\(enumName), Void> {
                Algebra_Primitives.Prism(
                    embed: { _ in .\(enumCase.name) },
                    extract: { if case .\(enumCase.name) = $0 { return () } else { return nil } }
                )
            }
        """
    } else if enumCase.parameters.count == 1 {
        // Single parameter - prism directly to that type
        let param = enumCase.parameters[0]
        let paramType = param.type.description.trimmingCharacters(in: .whitespaces)
        let embedArg = param.label != nil ? "\(param.label!): $0" : "$0"
        let extractPattern = param.label != nil ? "\(param.label!): let v" : "let v"

        return """
        public var \(enumCase.name): Algebra_Primitives.Prism<\(enumName), \(paramType)> {
                Algebra_Primitives.Prism(
                    embed: { .\(enumCase.name)(\(embedArg)) },
                    extract: { if case .\(enumCase.name)(\(extractPattern)) = $0 { return v } else { return nil } }
                )
            }
        """
    } else {
        // Multiple parameters - prism to a tuple
        let tupleTypes = enumCase.parameters.map { param in
            param.type.description.trimmingCharacters(in: .whitespaces)
        }.joined(separator: ", ")

        let embedArgs = enumCase.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): $0.\(index)"
            } else {
                return "$0.\(index)"
            }
        }.joined(separator: ", ")

        let extractPatterns = enumCase.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): let v\(index)"
            } else {
                return "let v\(index)"
            }
        }.joined(separator: ", ")

        let extractTuple = enumCase.parameters.indices.map { "v\($0)" }.joined(separator: ", ")

        return """
        public var \(enumCase.name): Algebra_Primitives.Prism<\(enumName), (\(tupleTypes))> {
                Algebra_Primitives.Prism(
                    embed: { .\(enumCase.name)(\(embedArgs)) },
                    extract: { if case .\(enumCase.name)(\(extractPatterns)) = $0 { return (\(extractTuple)) } else { return nil } }
                )
            }
        """
    }
}

// MARK: - Diagnostics

enum WitnessDiagnostic: String, DiagnosticMessage {
    case requiresStructOrEnum
    case noClosureProperties
    case noEnumCases

    var message: String {
        switch self {
        case .requiresStructOrEnum:
            return "@Witness can only be applied to structs or enums"
        case .noClosureProperties:
            return "@Witness requires at least one closure property"
        case .noEnumCases:
            return "@Witness requires at least one enum case"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "WitnessMacro", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
