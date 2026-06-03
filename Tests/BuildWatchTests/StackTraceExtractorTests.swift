import BuildWatch
import XCTest

final class StackTraceExtractorTests: XCTestCase {
    func testExtractsCompilerFileLineAndSymbol() {
        let log = "Sources/MediaDecoder.swift:142:17: use of unresolved identifier 'AVAssetTrackSegment'"
        let frames = StackTraceExtractor().extract(from: log)

        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].file, "Sources/MediaDecoder.swift")
        XCTAssertEqual(frames[0].line, 142)
        XCTAssertTrue(frames[0].symbol.contains("unresolved identifier"))
    }

    func testExtractsCrashStyleFrame() {
        let log = "0   MediaFramework 0x0000000100abc123 specialized MediaPipeline.decode(frame:) + 88"
        let frames = StackTraceExtractor().extract(from: log)

        XCTAssertEqual(frames.count, 1)
        XCTAssertTrue(frames[0].symbol.contains("MediaFramework"))
        XCTAssertTrue(frames[0].symbol.contains("decode"))
    }
}
