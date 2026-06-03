import Foundation

public enum FailureKind: String, Codable, CaseIterable, Sendable {
    case compilerError = "compiler_error"
    case linkerError = "linker_error"
    case testFailure = "test_failure"
    case flakyTestCandidate = "flaky_test_candidate"
    case simulatorFailure = "simulator_failure"
    case codeSigningFailure = "code_signing_failure"
    case missingDependency = "missing_dependency"
    case timeout = "timeout"
    case networkFailure = "network_failure"
    case infrastructureFailure = "infrastructure_failure"
    case unknown = "unknown"
}

public struct EvidenceLine: Codable, Equatable, Sendable {
    public let lineNumber: Int
    public let text: String

    public init(lineNumber: Int, text: String) {
        self.lineNumber = lineNumber
        self.text = text
    }
}

public struct StackFrame: Codable, Equatable, Sendable {
    public let file: String?
    public let line: Int?
    public let symbol: String
    public let raw: String

    public init(file: String?, line: Int?, symbol: String, raw: String) {
        self.file = file
        self.line = line
        self.symbol = symbol
        self.raw = raw
    }
}

public struct GitContext: Codable, Equatable, Sendable {
    public let branch: String
    public let sha: String
    public let changedFiles: [String]

    public init(branch: String, sha: String, changedFiles: [String]) {
        self.branch = branch
        self.sha = sha
        self.changedFiles = changedFiles
    }

    public static let unavailable = GitContext(branch: "unknown", sha: "unknown", changedFiles: [])
}

public struct BuildAnalysis: Codable, Equatable, Sendable {
    public let status: String
    public let failureKind: FailureKind
    public let confidence: Double
    public let summary: String
    public let suggestedAction: String
    public let evidence: [EvidenceLine]
    public let stackFrames: [StackFrame]
    public let likelyOwner: String?
    public let git: GitContext

    public init(
        status: String,
        failureKind: FailureKind,
        confidence: Double,
        summary: String,
        suggestedAction: String,
        evidence: [EvidenceLine],
        stackFrames: [StackFrame],
        likelyOwner: String?,
        git: GitContext
    ) {
        self.status = status
        self.failureKind = failureKind
        self.confidence = confidence
        self.summary = summary
        self.suggestedAction = suggestedAction
        self.evidence = evidence
        self.stackFrames = stackFrames
        self.likelyOwner = likelyOwner
        self.git = git
    }
}

public struct BuildJob: Codable, Equatable, Sendable {
    public let name: String
    public let durationSeconds: Int
    public let dependencies: [String]
    public let canFailInfrastructure: Bool

    public init(name: String, durationSeconds: Int, dependencies: [String] = [], canFailInfrastructure: Bool = false) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.dependencies = dependencies
        self.canFailInfrastructure = canFailInfrastructure
    }
}

public struct ScheduleResult: Codable, Equatable, Sendable {
    public let totalSeconds: Int
    public let criticalPath: [String]
    public let retriedJobs: [String]
    public let workerCount: Int

    public init(totalSeconds: Int, criticalPath: [String], retriedJobs: [String], workerCount: Int) {
        self.totalSeconds = totalSeconds
        self.criticalPath = criticalPath
        self.retriedJobs = retriedJobs
        self.workerCount = workerCount
    }
}
