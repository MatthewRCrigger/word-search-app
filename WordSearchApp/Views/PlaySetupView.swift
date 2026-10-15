import SwiftData
import SwiftUI

struct PlaySetupView: View {
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
    let onGeneratePDF: () -> Void
    let onPlay: () -> Void

    private var canPlay: Bool {
        selectedSubjectName != nil && maximumWordCount >= minimumWordCount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if subjects.isEmpty {
                    emptyState
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 28) {
                            controls.frame(width: 420)
                            previewCard.frame(maxWidth: .infinity)
                        }
                        .frame(minWidth: 780)

                        VStack(spacing: 24) {
                            controls
                            previewCard
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.ground)
        .scrollContentBackground(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New puzzle")
                .font(Theme.display(40, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("Pick a word bank and tune the board. Words are shuffled every game.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundStyle(Theme.inkTertiary)
            Text("No word banks yet")
                .font(Theme.display(24))
            Text("Create a word bank to start playing.")
                .foregroundStyle(Theme.inkSecondary)
            Button("Create word bank", action: onCreateWordBank)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .card(cornerRadius: 28)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 24) {
            bankPicker
            gridSizePicker
            wordCountStepper
            rules
        }
    }

    private var bankPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Word bank")
                Spacer()
                Button("Manage", action: onManageWordBanks)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }

            VStack(spacing: 8) {
                ForEach(subjects) { subject in
                    let isSelected = subject.persistentModelID == selectedSubjectID

                    Button {
                        selectedSubjectID = subject.persistentModelID
                    } label: {
                        HStack(spacing: 14) {
                            BankBadge(name: subject.name, size: 36)
                            Text(subject.name)
                                .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(subject.words.count) words")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.inkSecondary)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var gridSizePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Grid size")

            HStack(spacing: 4) {
                ForEach(WordSearchGenerator.allowedGridSizes, id: \.self) { size in
                    let isSelected = selectedGridSize == size

                    Button {
                        selectedGridSize = size
                    } label: {
                        Text("\(size) × \(size)")
                            .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? Theme.ink : Theme.inkSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(isSelected ? Theme.surface : .clear)
                                    .shadow(color: Theme.ink.opacity(isSelected ? 0.15 : 0), radius: 2, y: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.line))
        }
    }

    private var wordCountStepper: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Words in puzzle")

            if maximumWordCount < minimumWordCount {
                Text("Need at least \(minimumWordCount) words that fit this grid size.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.warning)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: 0xFFE9D6)))
            } else {
                HStack(spacing: 12) {
                    Text("\(selectedWordCount)")
                        .font(Theme.display(28, weight: .heavy))
                        .contentTransition(.numericText())
                    Text("of \(maximumWordCount) that fit")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    stepperButton("minus", label: "Fewer words", disabled: selectedWordCount <= minimumWordCount) {
                        selectedWordCount -= 1
                    }
                    stepperButton("plus", label: "More words", disabled: selectedWordCount >= maximumWordCount) {
                        selectedWordCount += 1
                    }
                }
                .padding(.leading, 20)
                .padding(8)
                .frame(minHeight: 64)
                .card(cornerRadius: 16)
                .animation(.snappy, value: selectedWordCount)
            }
        }
    }

    private func stepperButton(_ systemImage: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(disabled ? Theme.inkTertiary.opacity(0.5) : Theme.ink)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.ground))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Rules")

            VStack(spacing: 0) {
                Toggle("Backwards words", isOn: $allowBackwards)
                    .frame(minHeight: 56)
                Divider()
                Toggle("Letter overlap", isOn: $allowOverlap)
                    .frame(minHeight: 56)
            }
            .font(.system(size: 16, weight: .semibold))
            .tint(Theme.accent)
            .padding(.horizontal, 20)
            .card(cornerRadius: 16)
        }
    }

    // MARK: Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel("Preview")
                    Text(selectedSubjectName ?? "Select a word bank")
                        .font(Theme.display(28))
                        .lineLimit(1)
                }
                Spacer()
                pill("\(selectedGridSize) × \(selectedGridSize)")
                pill("\(selectedWordCount) words")
            }

            BoardPreview(size: selectedGridSize)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.warning)
            }

            HStack(spacing: 12) {
                Button(action: onGeneratePDF) {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(action: onPlay) {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .disabled(!canPlay)
        }
        .padding(28)
        .card(cornerRadius: 28)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Theme.ground))
    }
}

/// A quiet, deterministic letter field that shows how big the chosen grid will be.
private struct BoardPreview: View {
    let size: Int

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let padding: CGFloat = 12
            let cell = (side - padding * 2) / CGFloat(size)

            VStack(spacing: 0) {
                ForEach(0..<size, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<size, id: \.self) { column in
                            Text(letter(row: row, column: column))
                                .font(.system(size: max(9, cell * 0.5), weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.inkTertiary)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .padding(padding)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0xF6F8FC)))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func letter(row: Int, column: Int) -> String {
        let letters = Array("ABCDEFGHILMNOPRSTUW")
        let value = (row &* 73 &+ column &* 151 &+ row &* column &* 31 &+ 7) % letters.count
        return String(letters[value])
    }
}
