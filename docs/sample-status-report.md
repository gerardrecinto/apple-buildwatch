# Sample Status Report

| Field | Value |
|---|---|
| Status | failed |
| Failure | test_failure |
| Confidence | 91% |
| Branch | feature/media-cache |
| SHA | abc1234 |
| Likely owner | Media |

## Summary

XCTest reported a product or test assertion failure.

## Suggested Action

Open the failing test, compare recent git changes, and confirm whether the failure reproduces locally.

## Evidence

- line 3: `Sources/MediaPlaybackTests.swift:88: error: -[MediaPlaybackTests testSegmentOrdering] : XCTAssertEqual failed`
- line 4: `Test Case '-[MediaPlaybackTests testSegmentOrdering]' failed (2.3 seconds).`

## Stack Context

- `Sources/MediaPlaybackTests.swift:88` error: -[MediaPlaybackTests testSegmentOrdering] : XCTAssertEqual failed
