import SwiftData
import SwiftUI

// MARK: - Word entry parsing

/// Accepts a single word or a pasted list (commas / new lines) and reports what happened.
private enum WordEntry {
    static func process(_ raw: String, existing: Set<String>) -> (accepted: [String], message: String) {
        let pieces = raw
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var accepted: [String] = []
        var seen = existing
        var firstProblem: String?
        var skipped = 0

        for piece in pieces {
            let cleaned = WordSearchGenerator.sanitizeWord(piece)

            if cleaned.isEmpty {
                firstProblem = firstProblem ?? "Please enter letters only."
                skipped += 1
            } else if cleaned.count > WordBankRules.maxWordLength {
                firstProblem = firstProblem ?? "\(cleaned) is too long for the puzzle grid."
                skipped += 1
            } else if !seen.insert(cleaned).inserted {
                firstProblem = firstProblem ?? "\(cleaned) is already added."
                skipped += 1
            } else {
                accepted.append(cleaned)
            }
        }

        if accepted.isEmpty {
            return ([], firstProblem ?? "Type a word to add.")
        }

        if accepted.count == 1, skipped == 0 {
            return (accepted, "Added \(accepted[0]).")
        }

        let skippedNote = skipped > 0 ? " Skipped \(skipped)." : ""
        return (accepted, "Added \(accepted.count) words.\(skippedNote)")
    }
}

// MARK: - Shared pieces

private struct WordChip: View {
    let word: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Text(word)
                .font(.system(size: 16, weight: .semibold))
                .tracking(0.5)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(word)")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, onRemove == nil ? 16 : 6)
        .frame(minHeight: 44)
        .background(Capsule().fill(Theme.fillQuiet))
    }
}

private struct FeedbackLine: View {
    let message: String

    var body: some View {
        if !message.isEmpty {
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .transition(.opacity)
        }
    }
}

struct WordChipFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > 0, x + size.width > containerWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            maxWidth = max(maxWidth, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Word banks screen

struct WordBanksView: View {
    @Environment(\.modelContext) private var modelContext
    let subjects: [WordSubject]
    let onCreateWordBank: () -> Void
    let onPlayBank: (WordSubject) -> Void

    @State private var selectedID: PersistentIdentifier?

    private var selectedSubject: WordSubject? {
        subjects.first(where: { $0.persistentModelID == selectedID }) ?? subjects.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            #if os(iOS)
            HStack(alignment: .bottom) {
                Text("Word banks")
                    .font(Theme.display(40, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(action: onCreateWordBank) {
                    Label("New word bank", systemImage: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accent))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            #endif

            if subjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.inkTertiary)
                    Text("No word banks yet")
                        .font(Theme.display(24))
                    Text("Create your first word bank to start playing.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .card(cornerRadius: 28)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        bankList.frame(width: 300)
                        editor
                    }
                    .frame(minWidth: 700)

                    VStack(spacing: 16) {
                        bankStrip
                        editor
                    }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.ground)
    }

    private var bankList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(subjects) { subject in
                    let isSelected = subject.persistentModelID == selectedSubject?.persistentModelID

                    Button {
                        selectedID = subject.persistentModelID
                    } label: {
                        HStack(spacing: 14) {
                            BankBadge(name: subject.name)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subject.name)
                                    .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text("\(subject.words.count) word\(subject.words.count == 1 ? "" : "s")")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(2)
        }
        .scrollIndicators(.hidden)
    }

    private var bankStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(subjects) { subject in
                    let isSelected = subject.persistentModelID == selectedSubject?.persistentModelID

                    Button {
                        selectedID = subject.persistentModelID
                    } label: {
                        HStack(spacing: 10) {
                            BankBadge(name: subject.name, size: 32)
                            Text(subject.name)
                                .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 52)
                        .background(Capsule().fill(Theme.surface))
                        .overlay(Capsule().strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var editor: some View {
        if let subject = selectedSubject {
            WordBankEditorView(
                subject: subject,
                allSubjects: subjects,
                onPlay: { onPlayBank(subject) },
                onDelete: {
                    selectedID = nil
                    modelContext.delete(subject)
                }
            )
            .id(subject.persistentModelID)
        }
    }
}

// MARK: - Editor

private struct WordBankEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var subject: WordSubject
    let allSubjects: [WordSubject]
    let onPlay: () -> Void
    let onDelete: () -> Void

    @State private var wordInput = ""
    @State private var message = ""
    @State private var isShowingRename = false
    @State private var isConfirmingDelete = false

    private var sortedWords: [SubjectWord] {
        subject.words.sorted(by: { $0.text < $1.text })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .font(Theme.display(30))
                        .lineLimit(1)
                    Text("\(subject.words.count) word\(subject.words.count == 1 ? "" : "s")")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Button("Rename") { isShowingRename = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(minHeight: 48)
                Button("Play this bank", action: onPlay)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentTint))
                    .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    IconTextField(
                        placeholder: "Add a word, or paste a list",
                        text: $wordInput,
                        systemImage: "plus",
                        onSubmit: addWords
                    )
                    Button("Add", action: addWords)
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(wordInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                FeedbackLine(message: message)
            }

            ScrollView {
                if sortedWords.isEmpty {
                    Text("No words yet")
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    WordChipFlowLayout(spacing: 10, lineSpacing: 10) {
                        ForEach(sortedWords) { word in
                            WordChip(word: word.text) { remove(word) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .scrollIndicators(.hidden)

            Divider()

            HStack {
                Spacer()
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete word bank", systemImage: "trash")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(cornerRadius: 28)
        .animation(.snappy, value: subject.words.count)
        .sheet(isPresented: $isShowingRename) {
            RenameWordBankView(
                subject: subject,
                existingNames: Set(allSubjects.map(\.name).filter { $0 != subject.name })
            )
            .presentationDetents([.height(360)])
        }
        .confirmationDialog(
            "Delete \(subject.name)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete word bank", role: .destructive, action: onDelete)
        } message: {
            Text("This also deletes its \(subject.words.count) words.")
        }
    }

    private func addWords() {
        let existing = Set(subject.words.map(\.text))
        let result = WordEntry.process(wordInput, existing: existing)

        for text in result.accepted {
            let word = SubjectWord(text: text)
            word.subject = subject
            modelContext.insert(word)
            subject.words.append(word)
        }

        if !result.accepted.isEmpty { wordInput = "" }
        message = result.message
    }

    private func remove(_ word: SubjectWord) {
        subject.words.removeAll(where: { $0.persistentModelID == word.persistentModelID })
        modelContext.delete(word)
    }
}

// MARK: - Rename

private struct RenameWordBankView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var subject: WordSubject
    let existingNames: Set<String>

    @State private var draftName = ""
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeader(title: "Rename word bank", actionTitle: "Save", action: save, onCancel: { dismiss() })

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Name")
                TextField("Word bank name", text: $draftName)
                    .capitalizesWords()
                    .autocorrectionDisabled(true)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2))
                    .onSubmit(save)
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.warning)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .background(Theme.ground.ignoresSafeArea())
        .onAppear { draftName = subject.name }
    }

    private func save() {
        let normalized = WordSubjectNameValidator.normalize(draftName)
        guard !normalized.isEmpty else {
            message = "Name cannot be empty."
            return
        }

        if existingNames.contains(normalized) {
            message = "A word bank with that name already exists."
            return
        }

        subject.name = normalized
        dismiss()
    }
}

// MARK: - Create

struct CreateWordBankView: View {
    @Environment(\.dismiss) private var dismiss

    let existingNames: Set<String>
    let onSave: (_ name: String, _ words: [String]) -> Void

    @State private var nameDraft = ""
    @State private var wordDraft = ""
    @State private var words: [String] = []
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            sheetHeader(
                title: "New word bank",
                actionTitle: "Create",
                actionDisabled: !canSave,
                action: saveWordBank,
                onCancel: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Name")
                TextField("Example: Animals", text: $nameDraft)
                    .capitalizesWords()
                    .autocorrectionDisabled(true)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel("Add words")
                    Spacer()
                    Text("Type one, or paste a list separated by commas")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkTertiary)
                }
                HStack(spacing: 10) {
                    IconTextField(placeholder: "Type or paste words", text: $wordDraft, systemImage: "plus", fill: Theme.surface, onSubmit: addWords)
                    Button("Add", action: addWords)
                        .buttonStyle(SecondaryButtonStyle(filled: true))
                        .disabled(wordDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                FeedbackLine(message: message)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel("Words to save")
                    Spacer()
                    Text("\(words.count) ready")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSecondary)
                }

                ScrollView {
                    if words.isEmpty {
                        Text("No words added yet")
                            .foregroundStyle(Theme.inkTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    } else {
                        WordChipFlowLayout(spacing: 10, lineSpacing: 10) {
                            ForEach(words, id: \.self) { word in
                                WordChip(word: word) { words.removeAll { $0 == word } }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                }
                .frame(maxHeight: .infinity)
                .card(cornerRadius: 16)
            }

            Button(words.isEmpty ? "Create word bank" : "Create with \(words.count) word\(words.count == 1 ? "" : "s")", action: saveWordBank)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
        }
        .padding(28)
        .background(Theme.ground.ignoresSafeArea())
        .animation(.snappy, value: words)
    }

    private var canSave: Bool {
        let normalizedName = WordSubjectNameValidator.normalize(nameDraft)
        return !normalizedName.isEmpty && !words.isEmpty && !existingNames.contains(normalizedName)
    }

    private func addWords() {
        let result = WordEntry.process(wordDraft, existing: Set(words))
        words.append(contentsOf: result.accepted)
        if !result.accepted.isEmpty { wordDraft = "" }
        message = result.message
    }

    private func saveWordBank() {
        let normalizedName = WordSubjectNameValidator.normalize(nameDraft)
        guard !normalizedName.isEmpty else {
            message = "Please add a name."
            return
        }

        if existingNames.contains(normalizedName) {
            message = "A word bank with that name already exists."
            return
        }

        guard !words.isEmpty else {
            message = "Add at least one word."
            return
        }

        onSave(normalizedName, words)
        dismiss()
    }
}

// MARK: - Sheet chrome

private func sheetHeader(
    title: String,
    actionTitle: String,
    actionDisabled: Bool = false,
    action: @escaping () -> Void,
    onCancel: @escaping () -> Void
) -> some View {
    HStack {
        Button("Cancel", action: onCancel)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(minWidth: 80, minHeight: 44, alignment: .leading)

        Spacer()

        Text(title)
            .font(Theme.display(22))

        Spacer()

        Button(actionTitle, action: action)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(actionDisabled ? Theme.inkTertiary : Theme.accentText)
            .disabled(actionDisabled)
            .frame(minWidth: 80, minHeight: 44, alignment: .trailing)
    }
}
