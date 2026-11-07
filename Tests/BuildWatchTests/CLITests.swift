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

    func testRunOfSuccessfulCommandReportsPassed() throws {
        let result = try buildwatch(["run", "--owners", "off", "--", "echo", "hello"])

        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.stdout.contains("status: passed"), result.stdout)
    }

    func testRunKeepsLogWithInvalidUTF8() throws {
        let result = try buildwatch(["run", "--owners", "off", "--", "sh", "-c", "printf 'caf\\351 error: boom\\n'; exit 2"])

        XCTAssertEqual(result.status, 2)
        XCTAssertTrue(result.stdout.contains("failure: compiler_error"), result.stdout)
    }

    func testAnalyzeAcceptsLogWithInvalidUTF8() throws {
        let path = NSTemporaryDirectory() + "bw-invalid-utf8-\(UUID().uuidString).log"
        try Data([0x63, 0x61, 0x66, 0xE9, 0x20, 0x65, 0x72, 0x72, 0x6F, 0x72, 0x3A, 0x20, 0x78, 0x0A]).write(to: URL(fileURLWithPath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try buildwatch(["analyze", path, "--owners", "off"])

        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertTrue(result.stdout.contains("failure: compiler_error"), result.stdout)
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

    func testAnalyzeDirectoryExitsOneWithPlainError() throws {
        let result = try buildwatch(["analyze", NSTemporaryDirectory()])

        XCTAssertEqual(result.status, 1)
        XCTAssertTrue(result.stderr.contains("is a directory. Pass the path of a build log file."), result.stderr)
        XCTAssertFalse(result.stderr.contains("NSCocoaErrorDomain"))
    }
}
