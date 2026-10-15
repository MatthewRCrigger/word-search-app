#if os(macOS)
import SwiftData
import SwiftUI

/// Mac version of the play setup: a native grouped form next to a board preview.
struct MacPlaySetupView: View {
    let subjects: [WordSubject]
    @Binding var selectedSubjectID: PersistentIdentifier?
    @Binding var selectedGridSize: Int
    @Binding var selectedWordCount: Int
    @Binding var allowBackwards: Bool
    @Binding var allowOverlap: Bool

    let selectedSubjectName: String?
    let minimumWordCount: Int
    let maximumWordCount: Int
    let statusMessage: String
    let onCreateWordBank: () -> Void
    let onManageWordBanks: () -> Void

    var body: some View {
        if subjects.isEmpty {
            ContentUnavailableView {
                Label("No Word Banks Yet", systemImage: "book.closed")
            } description: {
                Text("Create a word bank to start playing.")
            } actions: {
                Button("New Word Bank…", action: onCreateWordBank)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            HStack(alignment: .top, spacing: 24) {
                form
                    .frame(width: 400)
                previewCard
            }
            .padding(24)
            .background(Theme.ground)
        }
    }

    private var form: some View {
        Form {
            Section("Word Bank") {
                Picker("Word bank", selection: $selectedSubjectID) {
                    ForEach(subjects) { subject in
                        HStack {
                            Text(subject.name)
                            Spacer()
                            Text("\(subject.words.count) words")
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional(subject.persistentModelID))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                Button("Manage Word Banks…", action: onManageWordBanks)
                    .buttonStyle(.link)
            }

            Section {
                Picker("Grid size", selection: $selectedGridSize) {
                    ForEach(WordSearchGenerator.allowedGridSizes, id: \.self) { size in
                        Text("\(size)").tag(size)
                    }
                }
                .pickerStyle(.segmented)

                if maximumWordCount < minimumWordCount {
                    Text("Need at least \(minimumWordCount) words that fit this grid size.")
                        .foregroundStyle(Theme.warning)
                } else {
                    Stepper(value: $selectedWordCount, in: minimumWordCount...maximumWordCount) {
                        LabeledContent("Words in puzzle") {
                            Text("\(selectedWordCount) of \(maximumWordCount) that fit")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Toggle("Backwards words", isOn: $allowBackwards)
                Toggle("Letter overlap", isOn: $allowOverlap)
            } header: {
                Text("Board")
            } footer: {
                Text("Words are shuffled from the bank every game.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedSubjectName ?? "Select a word bank")
                    .font(Theme.display(22, weight: .heavy))
                    .lineLimit(1)
                Spacer()
                Text("\(selectedGridSize) × \(selectedGridSize) · \(selectedWordCount) words")
                    .foregroundStyle(.secondary)
            }

            BoardPreview(size: selectedGridSize)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundStyle(Theme.warning)
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }
}
#endif
