# Runbook

## Local build

```bash
swift build
swift test
```

## Analyze a saved log

```bash
swift run buildwatch analyze fixtures/xcodebuild-test-failure.log
swift run buildwatch analyze fixtures/xcodebuild-test-failure.log --format markdown
swift run buildwatch analyze fixtures/make-linker-error.log --format json
```

## Run a command through buildwatch

```bash
swift run buildwatch run -- make test
swift run buildwatch run -- xcodebuild test -scheme DemoApp
```

The command wrapper captures stdout, stderr, exit code, duration, git branch, git SHA, and changed files.

## Triage procedure

1. Check the failure class.
2. Read the evidence lines.
3. Check stack context.
4. Compare against recent git changes.
5. Decide whether this is product code, test code, worker infra, simulator, signing, dependency, or network.
6. Write a short status update with owner and next action.

## Status update template

```text
Build failed in <stage>.
Primary failure: <failure_kind>.
Evidence: <file/line or log line>.
Likely owner: <team/component>.
Next action: <one concrete step>.
Retry: <yes/no and why>.
```
