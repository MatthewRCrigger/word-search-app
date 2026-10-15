import Foundation
import SwiftData

@Model
final class WordSubject {
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \SubjectWord.subject)
    var words: [SubjectWord] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class SubjectWord {
    var text: String
    var createdAt: Date
    var subject: WordSubject?

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}
