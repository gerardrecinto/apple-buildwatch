# Failure Taxonomy

`apple-buildwatch` keeps classification explicit and testable. The goal is not to guess harder. The goal is to separate product-code failures from build-worker, simulator, signing, dependency, and network failures quickly enough that the right team can act.

| Failure | Common evidence | First action |
|---|---|---|
| compiler_error | Swift or Objective-C file/line diagnostics | Inspect the first compiler error and recent source changes |
| linker_error | undefined symbols, duplicate symbols, linker command failed | Check target membership, linked frameworks, and search paths |
| test_failure | XCTest failure lines, assertion output | Open the failing test and verify local reproduction |
| flaky_test_candidate | async timeout, intermittent signal | Retry once and compare recurrence history |
| simulator_failure | simctl, CoreSimulator, boot timeout | Reset simulator runtime or move to a clean worker |
| code_signing_failure | provisioning profile, signing certificate | Check signing identity, profile, team, and configuration |
| missing_dependency | no such module, package resolution failed | Check package resolution, Makefile target, and artifact availability |
| network_failure | download timeout, TLS, connection reset, HTTP error | Check artifact host, credentials, and retry policy |
| infrastructure_failure | disk full, xcode-select, DerivedData, resource pressure | Check worker health before assigning to product code |

## Why rules first

Rules make the tool easy to test and easy to challenge in a build review. If a rule is wrong, it can be fixed with a fixture and a regression test. That is better for build engineering than hiding the logic behind an opaque service.
