import SwiftUI

enum ManagementFeedbackStyle {
    case neutral
    case success
    case warning
    case destructive

    var tint: Color {
        switch self {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .destructive:
            return .red
        }
    }
}

struct ManagementFeedbackBanner: View {
    let style: ManagementFeedbackStyle
    let title: String
    let message: String?

    init(style: ManagementFeedbackStyle = .neutral, title: String, message: String? = nil) {
        self.style = style
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style.tint.opacity(0.24), lineWidth: 1)
        )
    }
}

struct SubjectNameEditorSection: View {
    let title: String
    let placeholder: String
    let actionTitle: String
    let helperText: String
    @Binding var draftName: String
    let existingNames: Set<String>
    let onSubmit: (String) -> Void

    init(
        title: String = "Subject",
        placeholder: String = "Subject name",
        actionTitle: String,
        helperText: String = "Keep names short and descriptive.",
        draftName: Binding<String>,
        existingNames: Set<String>,
        onSubmit: @escaping (String) -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.actionTitle = actionTitle
        self.helperText = helperText
        self._draftName = draftName
        self.existingNames = existingNames
        self.onSubmit = onSubmit
    }

    private var validation: WordSubjectValidation {
        WordSubjectNameValidator.validate(draftName, existingNames: existingNames)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField(placeholder, text: $draftName)
                .capitalizesWords()
                .autocorrectionDisabled(true)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button(actionTitle) {
                    onSubmit(validation.normalizedValue)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validation.canSubmit)

                Text(validation.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(validation.canSubmit ? Color.secondary : Color.red)
            }

            Text(helperText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ConfirmedDestructiveButton: View {
    let label: String
    let confirmationTitle: String
    let confirmationMessage: String
    let confirmButtonTitle: String
    let onConfirm: () -> Void

    @State private var isShowingConfirmation = false

    init(
        label: String,
        confirmationTitle: String,
        confirmationMessage: String,
        confirmButtonTitle: String = "Delete",
        onConfirm: @escaping () -> Void
    ) {
        self.label = label
        self.confirmationTitle = confirmationTitle
        self.confirmationMessage = confirmationMessage
        self.confirmButtonTitle = confirmButtonTitle
        self.onConfirm = onConfirm
    }

    var body: some View {
        Button(role: .destructive) {
            isShowingConfirmation = true
        } label: {
            Label(label, systemImage: "trash")
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: $isShowingConfirmation,
            titleVisibility: .visible
        ) {
            Button(confirmButtonTitle, role: .destructive) {
                onConfirm()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }
}

struct WordBankValidationRow: View {
    let validation: WordBankWordValidation

    private var badgeText: String {
        if validation.isEmpty {
            return "Empty"
        }

        if validation.isDuplicate {
            return "Duplicate"
        }

        if validation.isTooLong {
            return "Too long"
        }

        if validation.sanitizedPreview != nil {
            return "Cleaned"
        }

        return "Ready"
    }

    private var badgeTint: Color {
        if validation.isEmpty || validation.isDuplicate || validation.isTooLong {
            return .red
        }

        if validation.sanitizedPreview != nil {
            return .orange
        }

        return .green
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(validation.displayValue)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let sanitizedPreview = validation.sanitizedPreview {
                    Text("Imports as \(sanitizedPreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(validation.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(badgeText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(badgeTint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeTint.opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WordBankBulkImportComposer: View {
    let title: String
    let helperText: String
    let importButtonTitle: String
    @Binding var draftText: String
    let existingWords: Set<String>
    let onImport: (_ acceptedWords: [String], _ report: WordBankBulkImportReport) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingPreview = false

    init(
        title: String = "Word Bank",
        helperText: String = "Add words separated by commas or new lines.",
        importButtonTitle: String = "Add Words",
        draftText: Binding<String>,
        existingWords: Set<String>,
        onImport: @escaping (_ acceptedWords: [String], _ report: WordBankBulkImportReport) -> Void
    ) {
        self.title = title
        self.helperText = helperText
        self.importButtonTitle = importButtonTitle
        self._draftText = draftText
        self.existingWords = existingWords
        self.onImport = onImport
    }

    private var report: WordBankBulkImportReport {
        WordBankValidator.validateBulkImport(draftText, existingWords: existingWords)
    }

    private var addButtonTitle: String {
        let count = report.acceptedWords.count
        guard count > 0 else { return importButtonTitle }
        return "Add \(count) Word\(count == 1 ? "" : "s")"
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text("Step 1: Paste or type your words")
                .font(.subheadline.weight(.semibold))

            TextEditor(text: $draftText)
                .frame(minHeight: isCompact ? 130 : 110)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .capitalizesWords(false)
                .autocorrectionDisabled(true)

            if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Example: cat, dog, bird")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ManagementFeedbackBanner(
                style: report.acceptedWords.isEmpty ? .neutral : .success,
                title: report.statusMessage,
                message: report.detailMessage ?? helperText
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Step 2: Review and add")
                    .font(.subheadline.weight(.semibold))

                Button(addButtonTitle) {
                    let currentReport = report
                    onImport(currentReport.acceptedWords, currentReport)
                }
                .buttonStyle(.borderedProminent)
                .disabled(report.acceptedWords.isEmpty)
            }

            if !report.entries.isEmpty {
                Button(isShowingPreview ? "Hide Import Preview" : "Show Import Preview (\(report.entries.count))") {
                    withAnimation(.easeInOut) {
                        isShowingPreview.toggle()
                    }
                }
                .buttonStyle(.bordered)
            }

            if !report.entries.isEmpty && isShowingPreview {
                ManagementFeedbackBanner(
                    style: .neutral,
                    title: "Import Preview",
                    message: "Check what will be added before importing."
                )

                VStack(alignment: .leading, spacing: 8) {
                    LazyVStack(spacing: 8) {
                        ForEach(report.entries) { entry in
                            WordBankValidationRow(validation: entry)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            isShowingPreview = !isCompact
        }
    }
}
