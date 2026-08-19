import BuildWatch
import XCTest

final class BuildComparatorTests: XCTestCase {

    private func analysis(
        status: String,
        failureKind: FailureKind = .unknown,
        confidence: Double = 0.8,
        owner: String = "unknown",
        branch: String = "main",
        sha: String = "abc1234"
    ) -> BuildAnalysis {
        BuildAnalysis(
            status: status,
            failureKind: failureKind,
            confidence: confidence,
            summary: "summary",
            suggestedAction: "action",
            evidence: [],
            stackFrames: [],
            likelyOwner: OwnershipResult(owner: owner, confidence: .medium, evidence: "evidence", source: .gitHistoryHeuristic),
            git: GitContext(branch: branch, sha: sha, changedFiles: [])
        )
    }

    func testStableWhenBothPassed() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "passed"),
            current: analysis(status: "passed")
        )
        XCTAssertEqual(comparison.transition, .stable)
        XCTAssertNil(comparison.previousFailureKind)
        XCTAssertNil(comparison.currentFailureKind)
    }

    func testRegressedWhenPassedThenFailed() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "passed"),
            current: analysis(status: "failed", failureKind: .compilerError)
        )
        XCTAssertEqual(comparison.transition, .regressed)
        XCTAssertNil(comparison.previousFailureKind)
        XCTAssertEqual(comparison.currentFailureKind, .compilerError)
    }

    func testResolvedWhenFailedThenPassed() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .testFailure),
            current: analysis(status: "passed")
        )
        XCTAssertEqual(comparison.transition, .resolved)
        XCTAssertEqual(comparison.previousFailureKind, .testFailure)
        XCTAssertNil(comparison.currentFailureKind)
    }

    func testPersistingWhenSameFailureKindBothTimes() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .simulatorFailure),
            current: analysis(status: "failed", failureKind: .simulatorFailure)
        )
        XCTAssertEqual(comparison.transition, .persisting)
    }

    func testChangedWhenFailureKindDiffersBothTimesFailing() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .compilerError),
            current: analysis(status: "failed", failureKind: .linkerError)
        )
        XCTAssertEqual(comparison.transition, .changed)
    }

    func testOwnerChangedDetectedOnlyWhenBothFailing() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .testFailure, owner: "Media"),
            current: analysis(status: "failed", failureKind: .testFailure, owner: "Networking")
        )
        XCTAssertTrue(comparison.ownerChanged)
        XCTAssertEqual(comparison.previousOwner, "Media")
        XCTAssertEqual(comparison.currentOwner, "Networking")
    }

    func testOwnerChangeNotReportedWhenTransitionIsResolved() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .testFailure, owner: "Media"),
            current: analysis(status: "passed", owner: "unknown")
        )
        XCTAssertFalse(comparison.ownerChanged)
        XCTAssertNil(comparison.currentOwner)
    }

    func testConfidenceDeltaIsCurrentMinusPrevious() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "failed", confidence: 0.60),
            current: analysis(status: "failed", confidence: 0.90)
        )
        XCTAssertEqual(comparison.confidenceDelta, 0.30, accuracy: 0.0001)
    }

    func testBranchAndSHAChangeDetection() {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "passed", branch: "main", sha: "aaa1111"),
            current: analysis(status: "passed", branch: "release/1.0", sha: "bbb2222")
        )
        XCTAssertTrue(comparison.branchChanged)
        XCTAssertTrue(comparison.shaChanged)
    }

    func testSummaryMentionsOwnerMoveOnlyWhenItChanged() {
        let changed = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .testFailure, owner: "Media"),
            current: analysis(status: "failed", failureKind: .testFailure, owner: "Networking")
        )
        XCTAssertTrue(changed.summary.contains("Media"))
        XCTAssertTrue(changed.summary.contains("Networking"))

        let unchanged = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .testFailure, owner: "Media"),
            current: analysis(status: "failed", failureKind: .testFailure, owner: "Media")
        )
        XCTAssertFalse(unchanged.summary.contains("->"))
    }

    func testComparisonRoundTripsThroughJSON() throws {
        let comparison = BuildComparator().compare(
            previous: analysis(status: "failed", failureKind: .compilerError),
            current: analysis(status: "passed")
        )
        let data = try JSONEncoder().encode(comparison)
        let decoded = try JSONDecoder().decode(BuildComparison.self, from: data)
        XCTAssertEqual(decoded, comparison)
    }
}
