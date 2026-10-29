# apple-buildwatch

![CI](https://github.com/gerardrecinto/apple-buildwatch/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

*New here? When a software build breaks, this tool reads the error log and tells you what went wrong and who to ask.*

A Swift command-line tool that reads a failed `xcodebuild`, XCTest or `make` log and tells you what kind of failure it was, the lines that show it, who likely owns it, and what to try next. It is for people who triage broken CI builds.

Live demo of the rules in your browser: https://gerardrecinto.github.io/apple-buildwatch/

![demo](docs/assets/demo.gif)

## Try it in 60 seconds

You need macOS 14 or later and a Swift 6 toolchain (Xcode 16 or later). The first run compiles the project, which takes a little while.

```bash
git clone https://github.com/gerardrecinto/apple-buildwatch.git
cd apple-buildwatch
swift run buildwatch analyze fixtures/xcodebuild-test-failure.log
swift run buildwatch analyze fixtures/make-linker-error.log --format markdown
swift test
```

The `fixtures/` folder holds small sample logs, so you can try it without a failing build of your own. To analyze your own log, replace the path.

## Example output

This is the output for the first fixture. Branch and SHA come from whatever git checkout you run it in.

```text
$ swift run buildwatch analyze fixtures/xcodebuild-test-failure.log

buildwatch
status: failed
failure: test_failure
confidence: 91%
branch: main
sha: 773e9e4
likely_owner: Media
owner_confidence: medium
ownership_source: git-history heuristic
ownership_evidence: keyword "media" matched in: Sources/MediaPlaybackTests.swift

summary:
  XCTest reported a product or test assertion failure.

suggested_action:
  Open the failing test, compare recent git changes, and confirm whether the failure reproduces locally.

evidence:
  line 3: Sources/MediaPlaybackTests.swift:88: error: -[MediaPlaybackTests testSegmentOrdering] : XCTAssertEqual failed
  line 4: Test Case '-[MediaPlaybackTests testSegmentOrdering]' failed (2.3 seconds).
  line 5: ** TEST FAILED **

stack_context:
  Sources/MediaPlaybackTests.swift:88 error: -[MediaPlaybackTests testSegmentOrdering] : XCTAssertEqual failed
```

Confidence is a fixed number attached to each rule. It is not a measured accuracy.

## What it does and does not do

It does:

- Match the log against ten ordered rules. The first rule with a matching line wins, and those lines are the evidence.
- Pull out stack frames, file and line, and git branch, SHA and changed files.
- Guess an owner from an override file, CODEOWNERS, or git history, and say `unknown` when nothing matches.
- Print terminal text, Markdown or JSON.
- Compare two JSON reports and exit 1 when a build got worse, so CI can gate on it.

It does not:

- Use machine learning. The rules are regular expressions in `Sources/BuildWatch/LogClassifier.swift`.
- Upload your log anywhere. The CLI reads local files. The web demo runs the same rules in your browser and does not run the owner lookup.
- Know your team. Owner guesses are only as good as your CODEOWNERS file and git history.
- Replace a CI dashboard. It gives a first answer for one failed build.

## More

- [Runbook](docs/runbook.md)
- [Failure taxonomy](docs/failure-taxonomy.md)
- [Sample status report](docs/sample-status-report.md)

<details>
<summary>All commands</summary>

*`compare` checks whether a build got better, got worse, or stayed the same since last time.*

```bash
buildwatch analyze <log-path> [--format terminal|json|markdown] [--owners auto|off]
buildwatch run: <command> [args...] [--format terminal|json|markdown] [--owners auto|off]
buildwatch compare <previous.json> <current.json> [--format terminal|json|markdown]
buildwatch simulate [--workers N]
buildwatch version
```

Examples:

```bash
buildwatch analyze fixtures/xcodebuild-test-failure.log --format markdown
buildwatch analyze fixtures/make-linker-error.log
buildwatch analyze fixtures/xcodebuild-test-failure.log --owners off
buildwatch run: make test
buildwatch simulate
buildwatch simulate --workers 1
buildwatch version

# Build-over-build diff: is last night's failure still the same one?
buildwatch analyze build.log --format json > today.json
buildwatch compare yesterday.json today.json
```

`compare` diffs two `analyze --format json` snapshots into one transition: `regressed` (newly failing), `resolved` (newly passing), `persisting` (same failure kind both times), `changed` (still red, different failure kind than last time), or `stable`. It also flags an owner change between the two runs. Exits 1 on `regressed`, so it drops into a CI gate the same way `run`'s exit-code passthrough does.

</details>

<details>
<summary>Install a binary or build a release</summary>

#### Download binary (macOS)

Download the latest release zip from [Releases](https://github.com/gerardrecinto/apple-buildwatch/releases):

```bash
curl -L https://github.com/gerardrecinto/apple-buildwatch/releases/latest/download/buildwatch-macos.zip -o buildwatch-macos.zip
unzip buildwatch-macos.zip
chmod +x buildwatch
mv buildwatch /usr/local/bin/buildwatch
```

#### Build from source

```bash
git clone https://github.com/gerardrecinto/apple-buildwatch.git
cd apple-buildwatch
swift build -c release
cp .build/release/buildwatch /usr/local/bin/buildwatch
```

Run from source:

```bash
swift run buildwatch analyze fixtures/xcodebuild-compiler-error.log
```

</details>

<details>
<summary>Failure categories</summary>

*These are the ten kinds of problem the tool can name. A flaky test is one that fails sometimes for no clear reason.*

| Category | Example signal |
|---|---|
| `compiler_error` | unresolved identifier, type mismatch, SwiftCompile failed |
| `linker_error` | undefined symbols, duplicate symbol, linker command failed |
| `test_failure` | XCTest assertion or `** TEST FAILED **` |
| `flaky_test_candidate` | async timeout or intermittent signal |
| `simulator_failure` | CoreSimulator or simctl boot timeout |
| `code_signing_failure` | provisioning profile or signing certificate |
| `missing_dependency` | no such module, package resolution failed |
| `timeout` | build or command timed out, SIGKILL |
| `network_failure` | artifact download or remote fetch failure |
| `infrastructure_failure` | disk full, xcode-select, DerivedData, worker pressure |

See [docs/failure-taxonomy.md](docs/failure-taxonomy.md).

</details>

<details>
<summary>Ownership resolution</summary>

*The tool makes its best guess at which team should fix the problem, and says so when it cannot tell.*

`buildwatch` tries to answer "who likely owns this failure," not just "what failed." It resolves an owner in this order, stopping at the first match:

1. **Explicit override**: an optional `.buildwatch-owners.json` file at the repo root, for teams that want to hardcode a friendly owner name for a path.
2. **CODEOWNERS**: `.github/CODEOWNERS`, `CODEOWNERS`, or `docs/CODEOWNERS` (checked in that order; the first one found is used). Patterns are matched against the failure's file path using real CODEOWNERS/gitignore glob semantics: `*`, `**`, anchored vs. unanchored patterns, and **last match wins** when multiple patterns match the same path.
3. **Git-history heuristic**: a lower-confidence fallback: a keyword match (e.g. "media", "network", "test") in the failure evidence or changed files, or, failing that, the directory of the first git-changed file.
4. **Unknown**: when nothing above matches. `buildwatch` reports `unknown` with `none` confidence rather than guessing.

Every resolution reports a `confidence` and an `evidence` trail explaining why:

| Confidence | Meaning |
|---|---|
| `high` | A file path directly matched an explicit override or a CODEOWNERS pattern. |
| `medium` | A keyword heuristic matched failure evidence, stack frames, or changed files. |
| `low` | No path or keyword match; fell back to the directory of the first git-changed file. |
| `none` | No evidence at all; owner is `unknown`. |

Use `--owners auto` (the default) for full resolution, or `--owners off` to skip the config/CODEOWNERS lookup and use only the heuristic fallback:

```bash
buildwatch analyze fixtures/xcodebuild-test-failure.log --owners auto
buildwatch analyze fixtures/xcodebuild-test-failure.log --owners off
```

`.buildwatch-owners.json` format:

```json
{
  "overrides": [
    { "pattern": "Sources/Media/**", "owner": "Media Platform Team" }
  ]
}
```

</details>

<details>
<summary>Feature list</summary>

- `xcodebuild` and XCTest log classification
- Makefile and linker error support
- stack trace and file-line extraction
- git branch, SHA, and changed-file context
- CODEOWNERS-aware ownership resolution with confidence and evidence
- `compare`: build-over-build diff between two JSON reports (regressed/resolved/persisting/changed), exits 1 on regression for CI gating
- Markdown, JSON, and terminal output
- build command wrapper for `make`, `xcodebuild`, or generic shell commands
- distributed build scheduler simulation with a fixed worker pool, critical path, and retry accounting: a constrained worker pool can queue jobs and push the total past the dependency-only critical path
- fixtures for compiler, linker, simulator, and test failures
- Swift XCTest coverage for the classifier, stack parser, and scheduler
- `version` command: prints build version and platform info

</details>

<details>
<summary>Architecture</summary>

```text
xcodebuild / make / saved CI log
          |
          v
BuildRunner or log file input
          |
          v
LogClassifier
  - compiled regular-expression rules
  - confidence scoring
  - failure category
          |
          +--> StackTraceExtractor
          +--> GitContextProvider
          +--> OwnerResolver
                 - .buildwatch-owners.json (explicit override)
                 - CODEOWNERS (glob match, last match wins)
                 - git-history heuristic (fallback)
          |
          v
ReportWriter
  - terminal
  - markdown
  - json
```

The repo also includes `SchedulerSimulation`, a small local model of distributed build execution. It tracks dependencies, retries infrastructure-sensitive jobs, and reports the critical path.

</details>

<details>
<summary>Why this is different from a CI dashboard</summary>

This is not trying to be a dashboard. It is a build engineer's first-response tool. The useful output is a small answer:

- what failed
- why the tool thinks so
- where the evidence is
- who likely owns it
- what to do next

That makes it useful during handoffs, release readiness checks, and build failure triage.

</details>

## Development

```bash
swift build
swift test
```

The browser demo is built from the Swift rule table. To run its automated
sample, failure-recovery, keyboard, and accessibility checks in Chromium,
Firefox, and WebKit, install Node.js 22 or later and Python 3, then run:

```bash
npm ci
npx playwright install --with-deps
npm run test:site
```

## License

MIT
