# Witness Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Witness primitives for capability protocols in Swift, supporting Carrier, Mutator, and similar capability types — with zero platform dependencies.

---

## Quick Start

A protocol witness is a struct whose stored properties are closures, each representing one operation of a capability. Instead of a `protocol` with method requirements, the interface is a value you can construct, swap, and compose at runtime — platform implementations, test doubles, and middleware all become ordinary values of the same type.

This package supplies the shared vocabulary: the `Witness.Protocol` marker that tags such a struct, and the `Witness.Composition` strategy that describes how two implementations combine.

```swift
import Witness_Primitives

// A capability expressed as a struct of closures, tagged with the marker protocol.
struct FileSystem: Witness.`Protocol` {
    var read: @Sendable (_ path: String) async throws -> [UInt8]
    var write: @Sendable (_ path: String, _ bytes: [UInt8]) async throws -> Void
}

// Implementations are ordinary values — swap them freely.
let live = FileSystem(
    read: { path in /* real read */ [] },
    write: { path, bytes in /* real write */ }
)

// Generic code accepts any witness via the marker constraint.
func mount<W: Witness.`Protocol`>(_ witness: W) { /* ... */ }
mount(live)

// Composition strategy describes how two witnesses combine.
let strategy: Witness.Composition = .fallback   // .sequential | .racing | .fallback
```

`Witness.Protocol` is a pure marker — it adds no requirements, so any struct-of-closures conforms with a single annotation. `Witness.Composition` is a three-case enum (`.sequential`, `.racing`, `.fallback`) that higher layers consume to layer logging, fan out concurrent calls, or fall back to a backup. The `@Witness` macro and test-aware `unimplemented` witnesses build on this vocabulary in the `swift-witnesses` foundations layer.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-witness-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Witness Primitives", package: "swift-witness-primitives"),
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux / Windows toolchain).

---

## Architecture

Two library products, one dependency.

| Product | Target | Purpose |
|---------|--------|---------|
| `Witness Primitives` | `Sources/Witness Primitives/` | The `Witness` namespace, the `Witness.Protocol` marker for struct-of-closures capabilities, and the `Witness.Composition` strategy (`.sequential` / `.racing` / `.fallback`). |
| `Witness Primitives Test Support` | `Tests/Support/` | Re-exports the main target for test consumers. |

Foundation-free.

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 26 | Full support |
| Linux | Full support |
| Windows | Full support |
| iOS / tvOS / watchOS / visionOS | Supported |
| Swift Embedded | Supported |

---

## Community

<!-- BEGIN: discussion -->
<!-- Discussion thread created at publication. -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
