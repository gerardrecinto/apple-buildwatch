import Foundation

public struct ReportWriter: Sendable {
    public init() {}

    public func terminal(_ analysis: BuildAnalysis) -> String {
        let evidence = analysis.evidence.map { "  line \($0.lineNumber): \($0.text)" }.joined(separator: "\n")
        let frames = analysis.stackFrames.map { frame in
            if let file = frame.file, let line = frame.line {
                return "  \(file):\(line) \(frame.symbol)"
            }
            return "  \(frame.symbol)"
        }.joined(separator: "\n")

        return """
        buildwatch
        status: \(analysis.status)
        failure: \(analysis.failureKind.rawValue)
        confidence: \(Int(analysis.confidence * 100))%
        branch: \(analysis.git.branch)
        sha: \(analysis.git.sha)
        likely_owner: \(analysis.likelyOwner.owner)
        owner_confidence: \(analysis.likelyOwner.confidence.rawValue)
        ownership_source: \(ownershipSourceLabel(analysis.likelyOwner.source))
        ownership_evidence: \(analysis.likelyOwner.evidence)

        summary:
          \(analysis.summary)

        suggested_action:
          \(analysis.suggestedAction)

        evidence:
        \(evidence.isEmpty ? "  none" : evidence)

        stack_context:
        \(frames.isEmpty ? "  none" : frames)
        """
    }

    public func markdown(_ analysis: BuildAnalysis) -> String {
        let evidence = analysis.evidence.map { "- line \($0.lineNumber): `\($0.text)`" }.joined(separator: "\n")
        let frames = analysis.stackFrames.map { frame in
            if let file = frame.file, let line = frame.line {
                return "- `\(file):\(line)` \(frame.symbol)"
            }
            return "- \(frame.symbol)"
        }.joined(separator: "\n")

        return """
        # BuildWatch Report

        | Field | Value |
        |---|---|
        | Status | \(analysis.status) |
        | Failure | \(analysis.failureKind.rawValue) |
        | Confidence | \(Int(analysis.confidence * 100))% |
        | Branch | \(analysis.git.branch) |
        | SHA | \(analysis.git.sha) |
        | Likely owner | \(analysis.likelyOwner.owner) |
        | Owner confidence | \(analysis.likelyOwner.confidence.rawValue) |
        | Ownership source | \(ownershipSourceLabel(analysis.likelyOwner.source)) |

        ## Ownership Evidence

        \(analysis.likelyOwner.evidence)

        ## Summary

        \(analysis.summary)

        ## Suggested Action

        \(analysis.suggestedAction)

        ## Evidence

        \(evidence.isEmpty ? "- none" : evidence)

        ## Stack Context

        \(frames.isEmpty ? "- none" : frames)
        """
    }

    private func ownershipSourceLabel(_ source: OwnershipSource) -> String {
        switch source {
        case .explicitConfig:
            return "\(OwnerConfigFile.fileName) (explicit override)"
        case .codeowners:
            return "CODEOWNERS"
        case .gitHistoryHeuristic:
            return "git-history heuristic"
        case .none:
            return "none (no signal found)"
        }
    }

    public func json(_ analysis: BuildAnalysis) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(analysis)
        return String(decoding: data, as: UTF8.self)
    }
}
