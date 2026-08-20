import Foundation

struct AlertFilter {
    private enum Operator {
        case equals
        case notEquals
        case matches
        case notMatches
    }

    private struct Matcher {
        let label: String
        let operation: Operator
        let value: String
        let regex: NSRegularExpression?
    }

    private let matchers: [Matcher]
    private let freeText: String?

    init(_ query: String) throws {
        var query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            matchers = []
            freeText = nil
            return
        }

        if query.hasPrefix("{") && query.hasSuffix("}") {
            query.removeFirst()
            query.removeLast()
        }

        if !query.contains("=") {
            matchers = []
            freeText = query.lowercased()
            return
        }

        freeText = nil
        matchers = try Self.splitMatchers(query).map(Self.parseMatcher)
    }

    func matches(_ alert: MonitoredAlert) -> Bool {
        if let freeText {
            let searchable = ([alert.ruleName] + alert.labels.flatMap { [$0.key, $0.value] }).joined(separator: " ").lowercased()
            return searchable.contains(freeText)
        }

        return matchers.allSatisfy { matcher in
            let actual = value(for: matcher.label, in: alert)
            switch matcher.operation {
            case .equals: return actual == matcher.value
            case .notEquals: return actual != matcher.value
            case .matches:
                guard let actual, let regex = matcher.regex else { return false }
                let range = NSRange(actual.startIndex..<actual.endIndex, in: actual)
                return regex.firstMatch(in: actual, range: range)?.range == range
            case .notMatches:
                guard let actual else { return true }
                guard let regex = matcher.regex else { return false }
                let range = NSRange(actual.startIndex..<actual.endIndex, in: actual)
                return regex.firstMatch(in: actual, range: range)?.range != range
            }
        }
    }

    private func value(for label: String, in alert: MonitoredAlert) -> String? {
        if label == "name" || label == "alertname" {
            return alert.labels[label] ?? alert.ruleName
        }
        return alert.labels[label]
    }

    private static func splitMatchers(_ query: String) throws -> [String] {
        var parts: [String] = []
        var current = ""
        var quoted = false
        var escaped = false

        for character in query {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                current.append(character)
                escaped = true
            } else if character == "\"" {
                current.append(character)
                quoted.toggle()
            } else if character == "," && !quoted {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if quoted { throw RadarError.invalidFilter("Unterminated quoted value") }
        parts.append(current)
        return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static func parseMatcher(_ source: String) throws -> Matcher {
        let pattern = #"^\s*([A-Za-z_][A-Za-z0-9_.-]*)\s*(!=|=~|!~|=)\s*\"((?:\\.|[^\"])*)\"\s*$"#
        let parser = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = parser.firstMatch(in: source, range: range), match.range == range,
              let labelRange = Range(match.range(at: 1), in: source),
              let operatorRange = Range(match.range(at: 2), in: source),
              let valueRange = Range(match.range(at: 3), in: source) else {
            throw RadarError.invalidFilter("Invalid matcher: \(source.trimmingCharacters(in: .whitespaces))")
        }

        let label = String(source[labelRange])
        let operatorText = String(source[operatorRange])
        let value = String(source[valueRange])
            .replacingOccurrences(of: #"\""#, with: "\"")
            .replacingOccurrences(of: #"\\"#, with: #"\"#)
        let operation: Operator
        switch operatorText {
        case "!=": operation = .notEquals
        case "=~": operation = .matches
        case "!~": operation = .notMatches
        default: operation = .equals
        }

        let regex: NSRegularExpression?
        if operation == .matches || operation == .notMatches {
            do { regex = try NSRegularExpression(pattern: value) }
            catch { throw RadarError.invalidFilter("Invalid regular expression for \(label)") }
        } else {
            regex = nil
        }
        return Matcher(label: label, operation: operation, value: value, regex: regex)
    }
}
