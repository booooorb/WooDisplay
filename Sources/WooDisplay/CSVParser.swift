import Foundation

enum CSVParserError: LocalizedError {
    case unreadableFile
    case missingRequiredColumns([String])
    case emptyCatalogue

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The selected file could not be read as a UTF-8 CSV."
        case let .missingRequiredColumns(columns):
            return "This does not look like a WooCommerce product export. Missing: \(columns.joined(separator: ", "))."
        case .emptyCatalogue:
            return "The CSV does not contain any published products."
        }
    }
}

struct CSVTable {
    let headers: [String]
    let rows: [[String: String]]
}

enum CSVParser {
    static func parse(url: URL) throws -> CSVTable {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else {
            throw CSVParserError.unreadableFile
        }

        if text.hasPrefix("\u{feff}") {
            text.removeFirst()
        }

        let records = parseRecords(text)
        guard let first = records.first else {
            throw CSVParserError.emptyCatalogue
        }

        let headers = first.map(normalizeHeader)
        let required = ["Type", "Name", "Published"]
        let missing = required.filter { !headers.contains($0) }
        guard missing.isEmpty else {
            throw CSVParserError.missingRequiredColumns(missing)
        }

        let rows = records.dropFirst().compactMap { values -> [String: String]? in
            guard values.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }

            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                row[header] = index < values.count ? values[index] : ""
            }
            return row
        }

        return CSVTable(headers: headers, rows: rows)
    }

    static func parseRecords(_ input: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var insideQuotes = false
        var index = input.startIndex

        func finishField() {
            record.append(field)
            field = ""
        }

        func finishRecord() {
            finishField()
            records.append(record)
            record = []
        }

        while index < input.endIndex {
            let character = input[index]
            let nextIndex = input.index(after: index)

            if insideQuotes {
                if character == "\"" {
                    if nextIndex < input.endIndex, input[nextIndex] == "\"" {
                        field.append("\"")
                        index = input.index(after: nextIndex)
                        continue
                    }
                    insideQuotes = false
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    insideQuotes = true
                case ",":
                    finishField()
                case "\n":
                    finishRecord()
                case "\r":
                    if nextIndex >= input.endIndex || input[nextIndex] != "\n" {
                        finishRecord()
                    }
                default:
                    field.append(character)
                }
            }

            index = nextIndex
        }

        if !field.isEmpty || !record.isEmpty {
            finishRecord()
        }

        return records
    }

    private static func normalizeHeader(_ header: String) -> String {
        header
            .replacingOccurrences(of: "\u{feff}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
