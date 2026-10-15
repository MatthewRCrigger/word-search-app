import Testing
@testable import WordSearchApp

struct WordBankValidationTests {

    @Test func sanitizeRemovesInvalidCharactersAndUppercases() {
        #expect(WordBankValidator.sanitize(" Cat-42! ") == "CAT")
    }

    @Test func validateWordShowsSanitizedPreviewWhenCharactersAreRemoved() {
        let validation = WordBankValidator.validateWord(" c@t ", existingWords: [])

        #expect(validation.isAccepted)
        #expect(validation.sanitizedValue == "CT")
        #expect(validation.sanitizedPreview == "CT")
        #expect(validation.statusMessage == "Will import as \"CT\".")
    }

    @Test func validateWordRejectsWordsLongerThanTheTwentyFourLetterLimit() {
        let validation = WordBankValidator.validateWord(String(repeating: "A", count: WordBankRules.maxWordLength + 1), existingWords: [])

        #expect(!validation.isAccepted)
        #expect(validation.isTooLong)
        #expect(validation.statusMessage == "Too long for a 24x24 puzzle.")
    }

    @Test func bulkImportTracksDuplicatesEmptiesAndCleanedWords() {
        let report = WordBankValidator.validateBulkImport(
            " c@t, c@t\nbird\n!!! ",
            existingWords: ["BIRD"]
        )

        #expect(report.acceptedWords == ["CT"])
        #expect(report.cleanedCount == 1)
        #expect(report.duplicateCount == 2)
        #expect(report.emptyCount == 1)
        #expect(report.tooLongCount == 0)
        #expect(report.statusMessage.contains("Added 1 word"))
        #expect(report.detailMessage?.contains("1 cleaned") == true)
        #expect(report.detailMessage?.contains("2 duplicates skipped") == true)
        #expect(report.detailMessage?.contains("1 empty entry skipped") == true)
    }

    @Test func subjectNameValidationTrimsAndDetectsDuplicates() {
        let validation = WordSubjectNameValidator.validate("  Science  ", existingNames: ["Science"])

        #expect(validation.normalizedValue == "Science")
        #expect(validation.isDuplicate)
        #expect(!validation.canSubmit)
        #expect(validation.statusMessage == "A subject with that name already exists.")
    }
}

