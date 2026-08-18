import BuildWatch
import XCTest

final class OwnershipGlobTests: XCTestCase {
    func testDoubleStarMatchesNestedFile() {
        XCTAssertTrue(OwnershipGlob.matches(pattern: "Sources/Media/**", path: "Sources/Media/Decoder.swift"))
        XCTAssertTrue(OwnershipGlob.matches(pattern: "Sources/Media/**", path: "Sources/Media/Nested/Deep/File.swift"))
    }

    func testDoubleStarDoesNotMatchSiblingDirectory() {
        XCTAssertFalse(OwnershipGlob.matches(pattern: "Sources/Media/**", path: "Sources/Networking/Client.swift"))
    }

    func testUnanchoredExtensionPatternMatchesAtAnyDepth() {
        XCTAssertTrue(OwnershipGlob.matches(pattern: "*.md", path: "README.md"))
        XCTAssertTrue(OwnershipGlob.matches(pattern: "*.md", path: "docs/guides/setup.md"))
        XCTAssertFalse(OwnershipGlob.matches(pattern: "*.md", path: "docs/guides/setup.mdx"))
    }

    func testLeadingSlashAnchorsToRepoRoot() {
        XCTAssertTrue(OwnershipGlob.matches(pattern: "/Sources/Media/Decoder.swift", path: "Sources/Media/Decoder.swift"))
        XCTAssertFalse(OwnershipGlob.matches(pattern: "/Sources/Media/Decoder.swift", path: "Vendor/Sources/Media/Decoder.swift"))
    }

    func testTrailingSlashMatchesDirectoryContents() {
        XCTAssertTrue(OwnershipGlob.matches(pattern: "docs/", path: "docs/runbook.md"))
        XCTAssertTrue(OwnershipGlob.matches(pattern: "docs/", path: "nested/docs/runbook.md"))
    }

    func testEmptyPatternNeverMatches() {
        XCTAssertFalse(OwnershipGlob.matches(pattern: "", path: "Sources/Media/Decoder.swift"))
    }
}
