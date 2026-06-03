import Foundation

public struct SchedulerSimulation: Sendable {
    public init() {}

    public func run(jobs: [BuildJob], workerCount: Int) -> ScheduleResult {
        guard workerCount > 0, !jobs.isEmpty else {
            return ScheduleResult(totalSeconds: 0, criticalPath: [], retriedJobs: [], workerCount: max(workerCount, 0))
        }

        var finishTimes: [String: Int] = [:]
        var pathByJob: [String: [String]] = [:]
        var retried: [String] = []

        for job in jobs {
            let dependencyFinish = job.dependencies.map { finishTimes[$0] ?? 0 }.max() ?? 0
            let retryPenalty = job.canFailInfrastructure ? min(30, max(5, job.durationSeconds / 4)) : 0
            if job.canFailInfrastructure {
                retried.append(job.name)
            }

            finishTimes[job.name] = dependencyFinish + job.durationSeconds + retryPenalty
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
