import BuildWatch
import XCTest

final class CodeOwnersParserTests: XCTestCase {
    func testParsesPatternAndOwners() {
        let contents = "Sources/Media/** @media-team @av-owner\n"
        let entries = CodeOwnersParser.parse(contents: contents)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].pattern, "Sources/Media/**")
        XCTAssertEqual(entries[0].owners, ["@media-team", "@av-owner"])
        XCTAssertEqual(entries[0].lineNumber, 1)
    }

    func testSkipsCommentsAndBlankLinesWithoutCrashing() {
        let contents = """
        # top level owners
        * @default-owner

        # media
        Sources/Media/** @media-team

        \t
        """
        let entries = CodeOwnersParser.parse(contents: contents)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].pattern, "*")
        XCTAssertEqual(entries[1].pattern, "Sources/Media/**")
    }

    func testLineWithPatternButNoOwnersDoesNotCrash() {
        let contents = "Sources/Media/**\n"
        let entries = CodeOwnersParser.parse(contents: contents)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].pattern, "Sources/Media/**")
        XCTAssertTrue(entries[0].owners.isEmpty)
    }

    func testEmptyContentsProducesNoEntries() {
        XCTAssertTrue(CodeOwnersParser.parse(contents: "").isEmpty)
    }
}
