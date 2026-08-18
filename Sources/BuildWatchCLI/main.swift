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
        case "simulate":
            simulate()
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

    private static func simulate() {
        let result = SchedulerSimulation().run(jobs: SchedulerSimulation.sampleJobs, workerCount: 3)
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

    private static let help = """
    buildwatch

    Commands:
      buildwatch analyze <log-path> [--format terminal|json|markdown] [--owners auto|off]
      buildwatch run -- <command> [args...] [--format terminal|json|markdown] [--owners auto|off]
      buildwatch simulate

    --owners auto (default) resolves the likely owner from an explicit
    .buildwatch-owners.json override, then CODEOWNERS, then a git-history
    heuristic. --owners off skips the config/CODEOWNERS lookup and only
    uses the heuristic fallback.

    Examples:
      buildwatch analyze fixtures/xcodebuild-test-failure.log --format markdown
      buildwatch analyze fixtures/make-linker-error.log
      buildwatch analyze fixtures/xcodebuild-test-failure.log --owners auto
      buildwatch simulate
    """
}
