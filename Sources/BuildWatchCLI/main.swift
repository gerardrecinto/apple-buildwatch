import BuildWatch
import Foundation

@main
struct BuildWatchCLI {
    static func main() throws {
        var args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "help"
        if !args.isEmpty { args.removeFirst() }

        switch command {
        case "analyze":
            try analyze(args)
        case "run":
            try run(args)
        case "compare":
            try compare(args)
        case "simulate":
            simulate(args)
        case "version":
            print("buildwatch \(Self.version) (\(Self.architecture); \(ProcessInfo.processInfo.operatingSystemVersionString))")
        default:
            print(help)
        }
    }

    private static func analyze(_ args: [String]) throws {
        guard let path = args.first else { throw BuildWatchError.missingArgument("log path") }
        let format = value(after: "--format", in: args) ?? "terminal"
        let ownersMode = value(after: "--owners", in: args) ?? "auto"
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { throw BuildWatchError.fileNotFound(path) }

        let log = try String(contentsOf: url, encoding: .utf8)
        let gitProvider = GitContextProvider()
        let git = gitProvider.readGitContext()
        let repoRoot = ownersMode == "off" ? nil : gitProvider.repositoryRoot()
        let analysis = LogClassifier().analyze(log: log, git: git, repoRoot: repoRoot)
        let writer = ReportWriter()

        switch format {
        case "json":
            print(try writer.json(analysis))
        case "markdown":
            print(writer.markdown(analysis))
        default:
            print(writer.terminal(analysis))
        }
    }

    private static func run(_ args: [String]) throws {
        guard !args.isEmpty else { throw BuildWatchError.missingArgument("command") }
        let format = value(after: "--format", in: args) ?? "terminal"
        let ownersMode = value(after: "--owners", in: args) ?? "auto"
        let command = args.split(separator: "--").last.map(Array.init) ?? args.filter { $0 != "--format" && $0 != format && $0 != "--owners" && $0 != ownersMode }
        let result = try BuildRunner().run(command: command)
        let gitProvider = GitContextProvider()
        let git = gitProvider.readGitContext()
        let repoRoot = ownersMode == "off" ? nil : gitProvider.repositoryRoot()
        let analysis = LogClassifier().analyze(log: result.log, git: git, repoRoot: repoRoot)
        let writer = ReportWriter()

        switch format {
        case "json":
            print(try writer.json(analysis))
        case "markdown":
            print(writer.markdown(analysis))
        default:
            print(writer.terminal(analysis))
        }

        if result.exitCode != 0 {
            Foundation.exit(result.exitCode)
        }
    }

    // Compares two `analyze --format json` snapshots (typically yesterday's
    // build against today's) into one build-over-build transition: newly
    // failing, recovered, the same failure persisting, or a different
    // failure kind now that the build is still red. Positional args are
    // parsed with `positionalArgs` rather than `run`'s `!= format` filter
    // above, since a real file path could collide with a flag's value.
    private static func compare(_ args: [String]) throws {
        let format = value(after: "--format", in: args) ?? "terminal"
        let positional = positionalArgs(args)
        guard positional.count >= 2 else {
            throw BuildWatchError.missingArgument("previous.json and current.json")
        }

        let previous = try loadAnalysis(path: positional[0])
        let current = try loadAnalysis(path: positional[1])
        let comparison = BuildComparator().compare(previous: previous, current: current)
        let writer = ReportWriter()

        switch format {
        case "json":
            print(try writer.json(comparison))
        case "markdown":
            print(writer.markdown(comparison))
        default:
            print(writer.terminal(comparison))
        }

        // CI-gate friendliness, matching `run`'s exitCode passthrough above:
        // a regression should be visible in the process exit code too, not
        // just in the printed report.
        if comparison.transition == .regressed {
            Foundation.exit(1)
        }
    }

    private static func loadAnalysis(path: String) throws -> BuildAnalysis {
        guard FileManager.default.fileExists(atPath: path) else { throw BuildWatchError.fileNotFound(path) }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(BuildAnalysis.self, from: data)
    }

    private static func positionalArgs(_ args: [String], flagsWithValues: Set<String> = ["--format", "--owners"]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < args.count {
            if flagsWithValues.contains(args[i]) {
                i += 2
                continue
            }
            result.append(args[i])
            i += 1
        }
        return result
    }

    private static func simulate(_ args: [String]) {
        let workerCount = value(after: "--workers", in: args).flatMap(Int.init) ?? 3
        let result = SchedulerSimulation().run(jobs: SchedulerSimulation.sampleJobs, workerCount: workerCount)
        print("""
        buildwatch scheduler simulation
        workers: \(result.workerCount)
        total_seconds: \(result.totalSeconds)
        critical_path: \(result.criticalPath.joined(separator: " -> "))
        retried_infra_jobs: \(result.retriedJobs.isEmpty ? "none" : result.retriedJobs.joined(separator: ", "))
        """)
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    static let version = "1.2.1"

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private static let help = """
    buildwatch

    Commands:
      buildwatch analyze <log-path> [--format terminal|json|markdown] [--owners auto|off]
      buildwatch run -- <command> [args...] [--format terminal|json|markdown] [--owners auto|off]
      buildwatch compare <previous.json> <current.json> [--format terminal|json|markdown]
      buildwatch simulate [--workers N]
      buildwatch version

    compare diffs two `analyze --format json` snapshots into one
    build-over-build transition: regressed, resolved, persisting (same
    failure kind both times), changed (still failing, different kind), or
    stable. Exits 1 on a regressed transition, for CI gating.

    --owners auto (default) resolves the likely owner from an explicit
    .buildwatch-owners.json override, then CODEOWNERS, then a git-history
    heuristic. --owners off skips the config/CODEOWNERS lookup and only
    uses the heuristic fallback.

    simulate models the sample job graph across a fixed worker pool
    (--workers, default 3). Fewer workers than concurrently-ready jobs
    forces some jobs to queue, which can push total_seconds past what the
    dependency graph alone would require.

    Examples:
      buildwatch analyze fixtures/xcodebuild-test-failure.log --format markdown
      buildwatch analyze fixtures/make-linker-error.log
      buildwatch analyze fixtures/xcodebuild-test-failure.log --owners auto
      buildwatch analyze build.log --format json > today.json
      buildwatch compare yesterday.json today.json
      buildwatch simulate
      buildwatch simulate --workers 1
    """
}
