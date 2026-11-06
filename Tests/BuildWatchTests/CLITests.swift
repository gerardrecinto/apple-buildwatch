import XCTest

final class CLITests: XCTestCase {
    private struct Output {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private func buildwatch(_ args: [String]) throws -> Output {
        let binary = Bundle(for: CLITests.self).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("buildwatch")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary.path), "missing \(binary.path)")

        let process = Process()
        process.executableURL = binary
        process.arguments = args
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Output(
            status: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }

    func testRunWithColonSyntaxFailsWithMessage() throws {
        let result = try buildwatch(["run:", "echo", "hi"])

        XCTAssertEqual(result.status, 1)
        XCTAssertTrue(result.stderr.contains("error: Unknown command: run:"))
    }

    func testRunWithoutSeparatorFailsWithMessage() throws {
        let result = try buildwatch(["run", "echo", "hi"])

        XCTAssertEqual(result.status, 1)
        XCTAssertTrue(result.stderr.contains("error: run needs `--`"))
    }

    func testRunWithEmptyCommandFailsWithMessage() throws {
        let result = try buildwatch(["run", "--"])

        XCTAssertEqual(result.status, 1)
        XCTAssertTrue(result.stderr.contains("error: run needs a command"))
    }

    func testRunWithSeparatorAnalyzesOutput() throws {
        let result = try buildwatch(["run", "--format", "json", "--", "echo", "** TEST FAILED **"])

        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.stdout.contains("test_failure"))
    }

    func testAnalyzeMissingFileExitsOneWithPlainError() throws {
        let result = try buildwatch(["analyze", "/nonexistent/build.log"])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stderr, "error: File not found: /nonexistent/build.log.\n")
        XCTAssertFalse(result.stderr.contains("Fatal error"))
    }
}
