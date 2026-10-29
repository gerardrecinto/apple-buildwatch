import BuildWatch
import XCTest

final class LogClassifierTests: XCTestCase {
    func testClassifiesXCTestFailure() throws {
        let log = try fixture("xcodebuild-test-failure.log")
        let result = LogClassifier().analyze(
            log: log,
            git: GitContext(branch: "feature/media-cache", sha: "abc1234", changedFiles: ["Tests/MediaPlaybackTests.swift"])
        )

        XCTAssertEqual(result.failureKind, .testFailure)
        XCTAssertGreaterThan(result.confidence, 0.80)
        XCTAssertEqual(result.likelyOwner.owner, "Media")
        XCTAssertEqual(result.likelyOwner.confidence, .medium)
        XCTAssertEqual(result.likelyOwner.source, .gitHistoryHeuristic)
        XCTAssertFalse(result.evidence.isEmpty)
        XCTAssertFalse(result.stackFrames.isEmpty)
    }

    func testClassifiesMakeLinkerError() throws {
        let log = try fixture("make-linker-error.log")
        let result = LogClassifier().analyze(log: log)

        XCTAssertEqual(result.failureKind, .linkerError)
        XCTAssertTrue(result.summary.localizedCaseInsensitiveContains("link"))
    }

    func testClassifiesSimulatorFailureBeforeGenericTimeout() throws {
        let log = try fixture("xcodebuild-simulator-timeout.log")
        let result = LogClassifier().analyze(log: log)

        XCTAssertEqual(result.failureKind, .simulatorFailure)
        XCTAssertTrue(result.suggestedAction.localizedCaseInsensitiveContains("simulator"))
    }

    func testMarkdownReportContainsActionableFields() throws {
        let log = try fixture("xcodebuild-compiler-error.log")
        let result = LogClassifier().analyze(log: log)
        let markdown = ReportWriter().markdown(result)

        XCTAssertTrue(markdown.contains("| Failure | compiler_error |"))
        XCTAssertTrue(markdown.contains("## Suggested Action"))
        XCTAssertTrue(markdown.contains("MediaDecoder.swift"))
    }

    func testClassifiesBuildTimeout() throws {
        let log = try fixture("xcodebuild-build-timeout.log")
        let result = LogClassifier().analyze(log: log)

        XCTAssertEqual(result.failureKind, .timeout)
        XCTAssertTrue(result.suggestedAction.localizedCaseInsensitiveContains("worker"))
    }

    func testClassifiesBareTestFailedBanner() {
        let result = LogClassifier().analyze(log: "** TEST FAILED **\n")

        XCTAssertEqual(result.failureKind, .testFailure)
    }

    func testDurationsDoNotLookLikeHttpErrors() {
        let result = LogClassifier().analyze(log: "Executed 12 tests in 0.403 seconds\n")

        XCTAssertNotEqual(result.failureKind, .networkFailure)
    }

    func testSimulatorPathDoesNotOverrideCompilerError() throws {
        let log = try fixture("xcodebuild-compiler-error-simulator-path.log")
        let result = LogClassifier().analyze(log: log)

        XCTAssertEqual(result.failureKind, .compilerError)
    }

    func testTestFailureWinsOverFlakyWording() throws {
        let log = try fixture("xcodebuild-test-failure-with-timeout-wording.log")
        let result = LogClassifier().analyze(log: log)

        XCTAssertEqual(result.failureKind, .testFailure)
    }

    func testSigningWinsOverGenericCompilerErrorLine() {
        let log = "error: Signing for \"App\" requires a development team.\n"
        XCTAssertEqual(LogClassifier().analyze(log: log).failureKind, .codeSigningFailure)
    }

    func testLinkerWinsOverClangErrorPrefix() throws {
        let log = try fixture("make-linker-error.log")
        XCTAssertEqual(LogClassifier().analyze(log: log).failureKind, .linkerError)
    }

    func testSimulatorTimeoutWinsOverGenericTimeout() throws {
        let log = try fixture("xcodebuild-simulator-timeout.log")
        XCTAssertEqual(LogClassifier().analyze(log: log).failureKind, .simulatorFailure)
    }

    func testEveryRuleIsCoveredDirectly() {
        let samples: [(FailureKind, String)] = [
            (.codeSigningFailure, "No signing certificate \"iOS Development\" found"),
            (.simulatorFailure, "simctl boot failed: timeout waiting for device"),
            (.testFailure, "** TEST FAILED **"),
            (.flakyTestCandidate, "async operation did not complete"),
            (.linkerError, "ld: symbol(s) not found for architecture arm64"),
            (.compilerError, "Foo.swift:3:1: error: cannot find type Foo in scope"),
            (.missingDependency, "package resolution failed for https://example.com/pkg.git"),
            (.networkFailure, "curl: TLS handshake timeout"),
            (.timeout, "Build timed out after 3600 seconds"),
            (.infrastructureFailure, "cp: write failed, No space left on device")
        ]

        XCTAssertEqual(Set(samples.map(\.0)).count, 10)
        for (kind, log) in samples {
            XCTAssertEqual(LogClassifier().analyze(log: log + "\n").failureKind, kind, log)
        }
    }

    func testCoreSimulatorPathAloneIsNotASimulatorFailure() {
        let log = "Writing to /Users/ci/Library/Developer/CoreSimulator/Devices/ABC/data\n"
        XCTAssertNotEqual(LogClassifier().analyze(log: log).failureKind, .simulatorFailure)
    }

    private func fixture(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("fixtures")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
