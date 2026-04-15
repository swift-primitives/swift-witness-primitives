# Audit History

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-witness-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=1, MEDIUM=1, LOW=8, INFO=4
Finding IDs: IMPL-040, PATTERN-052, WIT-001, WIT-002, WIT-003, WIT-004

| ID | Severity | Rule | File | Description |
|----|----------|------|------|-------------|
| WIT-001 | LOW | [API-ERR-001] | Witness.swift:26-28 | Doc example closures use untyped `throws` |
| WIT-002 | LOW | [API-ERR-001] | Witness.Protocol.swift:33,44-45 | Doc example closures use untyped `throws` |
| WIT-003 | LOW | [PRIM-FOUND-001] | Witness.Protocol.swift:33,44-45 | Doc examples reference Foundation `Data` type |
| WIT-004 | INFO | [API-IMPL-005] | Witness.swift | File contains one enum + one typealias (borderline) |
