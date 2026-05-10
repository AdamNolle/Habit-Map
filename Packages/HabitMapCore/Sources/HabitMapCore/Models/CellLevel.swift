public enum CellLevel: String, Sendable, CaseIterable {
    case empty, p25, p50, p75, p100, miss, rest, future
}

extension CellLevel {
    /// Maps a 0..1 progress fraction to a quadrant level (excluding miss/rest/future, determined elsewhere).
    public static func from(progress: Double) -> CellLevel {
        switch progress {
        case ..<0.001: return .empty
        case ..<0.26:  return .p25
        case ..<0.51:  return .p50
        case ..<0.76:  return .p75
        default:       return .p100
        }
    }
}
