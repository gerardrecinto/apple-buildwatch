import BuildWatch
import XCTest

final class SchedulerSimulationTests: XCTestCase {
    func testComputesCriticalPathAndRetriesInfraFailures() {
        let jobs = [
            BuildJob(name: "resolve", durationSeconds: 10),
            BuildJob(name: "compile-a", durationSeconds: 40, dependencies: ["resolve"]),
            BuildJob(name: "compile-b", durationSeconds: 20, dependencies: ["resolve"]),
            BuildJob(name: "test", durationSeconds: 30, dependencies: ["compile-a", "compile-b"], canFailInfrastructure: true),
            BuildJob(name: "archive", durationSeconds: 10, dependencies: ["test"])
        ]

        let result = SchedulerSimulation().run(jobs: jobs, workerCount: 2)

        XCTAssertEqual(result.workerCount, 2)
        XCTAssertEqual(result.retriedJobs, ["test"])
        XCTAssertEqual(result.criticalPath, ["resolve", "compile-a", "test", "archive"])
        XCTAssertGreaterThan(result.totalSeconds, 90)
    }
}
