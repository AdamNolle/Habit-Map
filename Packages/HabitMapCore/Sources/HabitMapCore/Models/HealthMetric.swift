public enum HealthMetric: String, Codable, Sendable {
    case stepCount, workouts, mindfulMinutes, sleep, standHours,
         activeEnergy, hydration, distanceWalkingRunning, heartRate
}
