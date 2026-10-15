import SwiftUI

enum Theme {
    static let ground = Color(hex: 0xEEF2F7)
    static let surface = Color.white
    static let ink = Color(hex: 0x0F1B2D)
    static let inkSecondary = Color(hex: 0x53627A)
    static let inkTertiary = Color(hex: 0x7B8AA3)
    static let line = Color(hex: 0xDCE3EE)
    static let fillQuiet = Color(hex: 0xF2F5FA)
    static let accent = Color(hex: 0x2F5BEA)
    static let accentText = Color(hex: 0x1F46C9)
    static let accentTint = Color(hex: 0xE4ECFF)
    static let danger = Color(hex: 0xB3261E)
    static let warning = Color(hex: 0x8A3E08)

    /// Soft fills used to tell found words apart on the board and in the word list.
    static let wordColors: [Color] = [
        Color(hex: 0xBFD7FF), Color(hex: 0xFFD9B8), Color(hex: 0xC9F0D8), Color(hex: 0xFFC9D6),
        Color(hex: 0xE2D1FF), Color(hex: 0xFFF0A8), Color(hex: 0xBDEBEF), Color(hex: 0xD9E4A8)
    ]

    static func wordColor(at index: Int) -> Color {
        wordColors[((index % wordColors.count) + wordColors.count) % wordColors.count]
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? Theme.accent : Theme.inkTertiary.opacity(0.5))
            )
            .shadow(color: Theme.accent.opacity(isEnabled ? 0.3 : 0), radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink
    var filled = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(isEnabled ? tint : Theme.inkTertiary)
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(filled ? Theme.surface : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(filled ? Color.clear : Color(hex: 0xCBD5E4), lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Building blocks

struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(1)
            .foregroundStyle(Theme.inkSecondary)
    }
}

extension View {
    /// Capitalizes each word as the user types on iOS; a no-op on macOS, which has no such API.
    @ViewBuilder
    func capitalizesWords(_ enabled: Bool = true) -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(enabled ? .words : .never)
        #else
        self
        #endif
    }

    func card(cornerRadius: CGFloat = 24, padding: CGFloat = 0) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
    }
}

struct BankBadge: View {
    let name: String
    var size: CGFloat = 44

    private static let palette: [(bg: UInt32, fg: UInt32)] = [
        (0xBDEBEF, 0x0B5560), (0xFFD9B8, 0x8A3E08), (0xC9F0D8, 0x146236),
        (0xE2D1FF, 0x4A2A92), (0xFFC9D6, 0x8C1F3D), (0xFFF0A8, 0x6B5400)
    ]

    var body: some View {
        let seed = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let colors = Self.palette[seed % Self.palette.count]

        Text(String(name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"))
            .font(Theme.display(size * 0.45))
            .foregroundStyle(Color(hex: colors.fg))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Color(hex: colors.bg))
            )
    }
}

struct IconTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String?
    var fill: Color = Theme.ground
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.inkTertiary)
            }
            TextField(placeholder, text: $text)
                                .autocorrectionDisabled(true)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .font(.system(size: 17, weight: .medium))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fill)
        )
    }
}
