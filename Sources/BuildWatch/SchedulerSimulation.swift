import Foundation

public struct SchedulerSimulation: Sendable {
    public init() {}

    /// Simulates dependency-ordered job execution across a fixed pool of
    /// `workerCount` workers using greedy list scheduling: `jobs` must
    /// already be given in topological order (each job's dependencies
    /// appear earlier in the array), and each job is assigned, in that
    /// order, to whichever worker frees up soonest. A job still has to
    /// wait for both its dependencies to finish and a worker to be free,
    /// so a constrained worker pool can push the total past the
    /// dependency-only critical path -- this is what makes it a scheduler
    /// simulation rather than a plain critical-path calculation.
    public func run(jobs: [BuildJob], workerCount: Int) -> ScheduleResult {
        guard workerCount > 0, !jobs.isEmpty else {
            return ScheduleResult(totalSeconds: 0, criticalPath: [], retriedJobs: [], workerCount: max(workerCount, 0))
        }

        var workerFreeTimes = [Int](repeating: 0, count: workerCount)
        var finishTimes: [String: Int] = [:]
        var pathByJob: [String: [String]] = [:]
        var retried: [String] = []

        for job in jobs {
            let dependencyFinish = job.dependencies.map { finishTimes[$0] ?? 0 }.max() ?? 0
            let retryPenalty = job.canFailInfrastructure ? min(30, max(5, job.durationSeconds / 4)) : 0
            if job.canFailInfrastructure {
                retried.append(job.name)
            }

            // Assign to whichever worker is free soonest, then wait for the
            // later of "dependencies done" and "worker free."
            let workerIndex = workerFreeTimes.indices.min { workerFreeTimes[$0] < workerFreeTimes[$1] }!
            let startTime = max(dependencyFinish, workerFreeTimes[workerIndex])
            let finish = startTime + job.durationSeconds + retryPenalty
            finishTimes[job.name] = finish
            workerFreeTimes[workerIndex] = finish

            let parent = job.dependencies.max { (finishTimes[$0] ?? 0) < (finishTimes[$1] ?? 0) }
            pathByJob[job.name] = (parent.flatMap { pathByJob[$0] } ?? []) + [job.name]
        }

        let total = finishTimes.values.max() ?? 0
        let criticalJob = finishTimes.max { $0.value < $1.value }?.key
        return ScheduleResult(
            totalSeconds: total,
            criticalPath: criticalJob.flatMap { pathByJob[$0] } ?? [],
            retriedJobs: retried,
            workerCount: workerCount
        )
    }

    public static let sampleJobs: [BuildJob] = [
        BuildJob(name: "resolve-packages", durationSeconds: 40),
        BuildJob(name: "compile-core", durationSeconds: 180, dependencies: ["resolve-packages"]),
        BuildJob(name: "compile-ui", durationSeconds: 150, dependencies: ["resolve-packages"]),
        BuildJob(name: "unit-tests", durationSeconds: 120, dependencies: ["compile-core", "compile-ui"], canFailInfrastructure: true),
        BuildJob(name: "archive", durationSeconds: 90, dependencies: ["unit-tests"])
    ]
}
