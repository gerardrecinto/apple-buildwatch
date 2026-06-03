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
        XCTAssertEqual(result.likelyOwner, "Media")
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

    private func fixture(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("fixtures")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
