import XCTest

/// Base class for host-rendered pixel-snapshot tests.
///
/// Snapshot images are environment-sensitive — GPU, CoreGraphics, and font
/// antialiasing differ across machines — so they are deliberately **not** part
/// of the blocking CI gate. The CI logic scheme (`HabitMap-CI`) sets
/// `HABITMAP_SKIP_SNAPSHOTS=1`, which makes every test in a `SnapshotTestCase`
/// subclass report as skipped. The full scheme (local runs + the non-blocking
/// CI snapshot job) leaves it unset, so snapshots execute normally.
///
/// Convention: any `XCTestCase` that calls `assertSnapshot` should subclass this
/// instead, so new snapshot tests inherit the skip automatically.
class SnapshotTestCase: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["HABITMAP_SKIP_SNAPSHOTS"] == "1",
            "Pixel-snapshot tests are host-rendered and excluded from the CI logic gate."
        )
    }
}
