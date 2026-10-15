import Foundation

enum WordBankRules {
    static let maxWordLength = 24
    static let maxGridSize = 24
}

struct WordSubjectValidation: Equatable {
    let rawValue: String
    let normalizedValue: String
    let isEmpty: Bool
    let isDuplicate: Bool

    var canSubmit: Bool {
        !isEmpty && !isDuplicate
    }

    var statusMessage: String {
        if isEmpty {
            return "Subject name cannot be empty."
        }

        if isDuplicate {
            return "A subject with that name already exists."
        }

        if normalizedValue != rawValue {
            return "Will use \"\(normalizedValue)\"."
        }

        return "Ready."
    }
}

enum WordSubjectNameValidator {
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validate(_ raw: String, existingNames: Set<String>) -> WordSubjectValidation {
        let normalized = normalize(raw)
        let isEmpty = normalized.isEmpty
        let isDuplicate = !isEmpty && existingNames.contains(normalized)

        return WordSubjectValidation(
            rawValue: raw,
            normalizedValue: normalized,
            isEmpty: isEmpty,
            isDuplicate: isDuplicate
        )
    }
}

enum WordBankWordValidationIssue: Equatable {
    case empty
    case duplicate
    case tooLong(limit: Int, actual: Int)
}

extension WordBankWordValidationIssue {
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    var isDuplicate: Bool {
        if case .duplicate = self { return true }
        return false
    }

    var isTooLong: Bool {
        if case .tooLong = self { return true }
        return false
    }
}

struct WordBankWordValidation: Identifiable, Equatable {
    let id = UUID()
    let rawValue: String
    let trimmedValue: String
    let sanitizedValue: String
    let issues: [WordBankWordValidationIssue]

    static func == (lhs: WordBankWordValidation, rhs: WordBankWordValidation) -> Bool {
        lhs.rawValue == rhs.rawValue &&
        lhs.trimmedValue == rhs.trimmedValue &&
        lhs.sanitizedValue == rhs.sanitizedValue &&
        lhs.issues == rhs.issues
    }

    var isAccepted: Bool {
        issues.isEmpty
    }

    var isEmpty: Bool {
        issues.contains(where: { $0.isEmpty })
    }

    var isDuplicate: Bool {
        issues.contains(where: { $0.isDuplicate })
    }

    var isTooLong: Bool {
        issues.contains(where: { $0.isTooLong })
    }

    var sanitizedPreview: String? {
        let normalizedInput = trimmedValue.uppercased()
        guard !sanitizedValue.isEmpty, sanitizedValue != normalizedInput else { return nil }
        return sanitizedValue
    }

    var displayValue: String {
        if trimmedValue.isEmpty {
            return "Empty entry"
        }
        return trimmedValue
    }

    var statusMessage: String {
        if isEmpty {
            return "Skipped empty entry."
        }

        if isDuplicate {
            return "Skipped duplicate."
        }

        if isTooLong {
            return "Too long for a 24x24 puzzle."
        }

        if let sanitizedPreview {
            return "Will import as \"\(sanitizedPreview)\"."
        }

        return "Ready to import."
    }
}

struct WordBankBulkImportReport: Equatable {
    let entries: [WordBankWordValidation]
    let acceptedWords: [String]
    let cleanedCount: Int
    let duplicateCount: Int
    let emptyCount: Int
    let tooLongCount: Int

    var statusMessage: String {
        if acceptedWords.isEmpty {
            if entries.isEmpty {
                return "Paste comma- or newline-separated words to begin."
            }

            return issueSummary(prefix: "No words were added")
        }

        return issueSummary(prefix: "Added \(acceptedWords.count) word\(acceptedWords.count == 1 ? "" : "s")")
    }

    var detailMessage: String? {
        let parts = detailParts
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private var detailParts: [String] {
        var parts: [String] = []

        if cleanedCount > 0 {
            parts.append("\(cleanedCount) cleaned")
        }

        if duplicateCount > 0 {
            parts.append("\(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s") skipped")
        }

        if emptyCount > 0 {
            parts.append("\(emptyCount) empty entr\(emptyCount == 1 ? "y" : "ies") skipped")
        }

        if tooLongCount > 0 {
            parts.append("\(tooLongCount) too long for 24x24")
        }

        return parts
    }

    private func issueSummary(prefix: String) -> String {
        let parts = detailParts
        guard !parts.isEmpty else { return "\(prefix)." }
        return "\(prefix). \(parts.joined(separator: ". "))."
    }
}

enum WordBankValidator {
    static func sanitize(_ raw: String) -> String {
        WordSearchGenerator.sanitizeWord(raw)
    }

    static func tokenize(_ raw: String) -> [String] {
        let trimmedInput = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return [] }

        return raw.components(separatedBy: CharacterSet(charactersIn: ",").union(.newlines))
    }

    static func validateWord(_ raw: String, existingWords: Set<String>, maxLength: Int = WordBankRules.maxWordLength) -> WordBankWordValidation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = sanitize(raw)
        var issues: [WordBankWordValidationIssue] = []

        if trimmed.isEmpty || sanitized.isEmpty {
            issues.append(.empty)
        }

        if sanitized.count > maxLength {
            issues.append(.tooLong(limit: maxLength, actual: sanitized.count))
        }

        if issues.allSatisfy({ !$0.isEmpty && !$0.isTooLong }) && existingWords.contains(sanitized) {
            issues.append(.duplicate)
        }

        return WordBankWordValidation(
            rawValue: raw,
            trimmedValue: trimmed,
            sanitizedValue: sanitized,
            issues: issues
        )
    }

    static func validateBulkImport(
        _ raw: String,
        existingWords: Set<String>,
        maxLength: Int = WordBankRules.maxWordLength
    ) -> WordBankBulkImportReport {
        let tokens = tokenize(raw)
        guard !tokens.isEmpty else {
            return WordBankBulkImportReport(
                entries: [],
                acceptedWords: [],
                cleanedCount: 0,
                duplicateCount: 0,
                emptyCount: 0,
                tooLongCount: 0
            )
        }

        var seenWords = existingWords
        var entries: [WordBankWordValidation] = []
        var acceptedWords: [String] = []
        var cleanedCount = 0
        var duplicateCount = 0
        var emptyCount = 0
        var tooLongCount = 0

        for token in tokens {
            let validation = validateWord(token, existingWords: seenWords, maxLength: maxLength)
            entries.append(validation)

            if validation.isAccepted {
                acceptedWords.append(validation.sanitizedValue)
                seenWords.insert(validation.sanitizedValue)

                if validation.sanitizedPreview != nil {
                    cleanedCount += 1
                }
                continue
            }

            if validation.isEmpty {
                emptyCount += 1
            }

            if validation.isTooLong {
                tooLongCount += 1
            }

            if validation.isDuplicate {
                duplicateCount += 1
            }
        }

        return WordBankBulkImportReport(
            entries: entries,
            acceptedWords: acceptedWords,
            cleanedCount: cleanedCount,
            duplicateCount: duplicateCount,
            emptyCount: emptyCount,
            tooLongCount: tooLongCount
        )
    }
}

