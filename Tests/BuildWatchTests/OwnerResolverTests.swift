import BuildWatch
import XCTest

final class OwnerResolverTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("buildwatch-owner-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func write(_ contents: String, relativeTo relativePath: String) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    func testDirectCodeownersMatchResolvesWithHighConfidence() throws {
        try write("Sources/Media/** @media-team\n", relativeTo: ".github/CODEOWNERS")

        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [StackFrame(file: "Sources/Media/Decoder.swift", line: 42, symbol: "decode", raw: "raw")],
            git: .unavailable,
            repoRoot: tempDir
        )

        XCTAssertEqual(result.owner, "@media-team")
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.source, .codeowners)
        XCTAssertTrue(result.evidence.contains("Sources/Media/Decoder.swift"))
        XCTAssertTrue(result.evidence.contains("CODEOWNERS"))
    }

    func testNoCodeownersFileFallsBackCleanly() throws {
        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [],
            git: GitContext(branch: "main", sha: "abc", changedFiles: ["Sources/Rendering/Compositor.swift"]),
            repoRoot: tempDir
        )

        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.source, .gitHistoryHeuristic)
        XCTAssertEqual(result.owner, "Rendering")
    }

    func testCodeownersPresentButNoPatternMatchesFallsThroughToHeuristic() throws {
        try write("Sources/Networking/** @net-team\n", relativeTo: "CODEOWNERS")

        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [StackFrame(file: "Sources/Media/Decoder.swift", line: 1, symbol: "decode", raw: "raw")],
            git: .unavailable,
            repoRoot: tempDir
        )

        XCTAssertNotEqual(result.source, .codeowners)
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertEqual(result.owner, "Media")
    }

    func testLaterPatternOverridesEarlierMatch() throws {
        try write(
            """
            Sources/** @platform-team
            Sources/Media/** @media-team
            """,
            relativeTo: ".github/CODEOWNERS"
        )

        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [StackFrame(file: "Sources/Media/Decoder.swift", line: 1, symbol: "decode", raw: "raw")],
            git: .unavailable,
            repoRoot: tempDir
        )

        XCTAssertEqual(result.owner, "@media-team")
        XCTAssertEqual(result.confidence, .high)
    }

    func testMalformedLinesDoNotCrashAndCorrectPatternStillWins() throws {
        try write(
            """
            # default owners

            *   @default-owner

            \t
            Sources/Media/** @media-team
            """,
            relativeTo: ".github/CODEOWNERS"
        )

        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [StackFrame(file: "Sources/Media/Decoder.swift", line: 1, symbol: "decode", raw: "raw")],
            git: .unavailable,
            repoRoot: tempDir
        )

        XCTAssertEqual(result.owner, "@media-team")
        XCTAssertEqual(result.confidence, .high)
    }

    func testExplicitConfigOverridesCodeowners() throws {
        try write("Sources/Media/** @media-team\n", relativeTo: ".github/CODEOWNERS")
        try write(
            """
            {"overrides": [{"pattern": "Sources/Media/**", "owner": "Media Platform Team (explicit)"}]}
            """,
            relativeTo: ".buildwatch-owners.json"
        )

        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [StackFrame(file: "Sources/Media/Decoder.swift", line: 1, symbol: "decode", raw: "raw")],
            git: .unavailable,
            repoRoot: tempDir
        )

        XCTAssertEqual(result.owner, "Media Platform Team (explicit)")
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.source, .explicitConfig)
    }

    func testNoSignalAtAllResolvesToUnknownWithoutFabricating() throws {
        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [],
            git: .unavailable,
            repoRoot: tempDir
        )

        XCTAssertEqual(result.owner, "unknown")
        XCTAssertEqual(result.confidence, .none)
        XCTAssertEqual(result.source, .none)
    }

    func testNilRepoRootSkipsCodeownersAndUsesHeuristic() throws {
        let result = OwnerResolver().resolve(
            evidence: [],
            stackFrames: [],
            git: GitContext(branch: "main", sha: "abc", changedFiles: ["Sources/Networking/Client.swift"]),
            repoRoot: nil
        )

        XCTAssertEqual(result.source, .gitHistoryHeuristic)
    }

    func testOversizedCodeownersFileIsSkippedNotCrashed() throws {
        try write("Sources/Media/** @media-team\n", relativeTo: ".github/CODEOWNERS")

        let result = OwnerResolver(maxFileBytes: 4).resolve(
            evidence: [],
            stackFrames: [StackFrame(file: "Sources/Media/Decoder.swift", line: 1, symbol: "decode", raw: "raw")],
            git: .unavailable,
            repoRoot: tempDir
        )

        XCTAssertNotEqual(result.source, .codeowners)
    }
}
