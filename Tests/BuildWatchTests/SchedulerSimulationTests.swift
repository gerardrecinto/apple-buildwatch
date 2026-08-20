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

    func testConstrainedWorkerPoolSerializesJobsThatCouldOtherwiseRunInParallel() {
        let jobs = [
            BuildJob(name: "resolve", durationSeconds: 10),
            BuildJob(name: "compile-a", durationSeconds: 40, dependencies: ["resolve"]),
            BuildJob(name: "compile-b", durationSeconds: 20, dependencies: ["resolve"]),
            BuildJob(name: "test", durationSeconds: 30, dependencies: ["compile-a", "compile-b"], canFailInfrastructure: true),
            BuildJob(name: "archive", durationSeconds: 10, dependencies: ["test"])
        ]

        // compile-a and compile-b are both ready at the same time and could
        // run concurrently. With only one worker they can't -- the total
        // must be strictly longer than with a worker pool big enough to run
        // them in parallel, proving workerCount actually constrains
        // scheduling instead of being accepted and ignored.
        let onePool = SchedulerSimulation().run(jobs: jobs, workerCount: 1)
        let wideOpenPool = SchedulerSimulation().run(jobs: jobs, workerCount: 4)

        XCTAssertGreaterThan(onePool.totalSeconds, wideOpenPool.totalSeconds)
        // Serialized on one worker: every job runs back to back.
        XCTAssertEqual(onePool.totalSeconds, 10 + 40 + 20 + 30 + 7 + 10)
    }
}
