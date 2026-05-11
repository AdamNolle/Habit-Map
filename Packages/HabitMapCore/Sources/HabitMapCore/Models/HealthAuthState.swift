public enum HealthAuthState: Equatable, Sendable {
    case unavailable          // device doesn't support HealthKit (iPad, etc.)
    case undetermined         // never asked
    case authorized
    case denied(timesDenied: Int)
}
