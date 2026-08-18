import Foundation

public struct BuildRunner: Sendable {
    public struct Result: Sendable {
        public let log: String
        public let exitCode: Int32
        public let duration: TimeInterval
    }

    public init() {}

    public func run(command: [String], workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> Result {
        guard let executable = command.first else {
            throw BuildWatchError.invalidCommand
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + Array(command.dropFirst())
        process.currentDirectoryURL = workingDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let start = Date()
        try process.run()
        // Drain the pipe before waiting: a child that fills the ~64KB pipe
        // buffer blocks on write while we block in waitUntilExit, deadlocking
        // on any real build log.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let log = String(data: data, encoding: .utf8) ?? ""
        return Result(log: log, exitCode: process.terminationStatus, duration: Date().timeIntervalSince(start))
    }
}

public enum BuildWatchError: Error, LocalizedError, Sendable {
    case invalidCommand
    case missingArgument(String)
    case fileNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCommand:
            return "No command was provided."
        case .missingArgument(let name):
            return "Missing required argument: \(name)."
        case .fileNotFound(let path):
            return "File not found: \(path)."
        }
    }
}
