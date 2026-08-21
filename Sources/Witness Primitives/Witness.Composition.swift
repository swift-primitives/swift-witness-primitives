extension Witness {

    public enum Composition: Sendable, Hashable {

        case sequential

        case racing

        case fallback
    }
}
