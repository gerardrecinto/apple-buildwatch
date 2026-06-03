import Foundation

public struct StackTraceExtractor: Sendable {
    public init() {}

    public func extract(from log: String) -> [StackFrame] {
        let lines = log.components(separatedBy: .newlines)
        let fileLinePattern = #"([A-Za-z0-9_./-]+\.(swift|m|mm|h|c|cc|cpp)):(\d+)(?::\d+)?:\s*(.*)"#
        let framePattern = #"^\s*(\d+)\s+([A-Za-z0-9_.-]+)\s+0x[0-9a-fA-F]+\s+(.+)$"#
        let fileRegex = try? NSRegularExpression(pattern: fileLinePattern)
        let frameRegex = try? NSRegularExpression(pattern: framePattern)

        return lines.compactMap { line in
            if let fileRegex, let match = fileRegex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) {
                let file = substring(line, match.range(at: 1))
                let lineNumber = Int(substring(line, match.range(at: 3)))
                let symbol = substring(line, match.range(at: 4))
                return StackFrame(file: file, line: lineNumber, symbol: symbol.isEmpty ? "compiler diagnostic" : symbol, raw: line)
            }

            if let frameRegex, let match = frameRegex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) {
                let module = substring(line, match.range(at: 2))
                let symbol = substring(line, match.range(at: 3))
                return StackFrame(file: nil, line: nil, symbol: "\(module) \(symbol)", raw: line)
            }

            return nil
        }
    }

    private func substring(_ line: String, _ nsRange: NSRange) -> String {
        guard let range = Range(nsRange, in: line) else { return "" }
        return String(line[range])
    }
}
