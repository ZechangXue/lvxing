import SwiftUI

enum Pastel {
    static let background = Color(hex: "#FFFAF4")
    static let peach = Color(hex: "#FFBE98")
    static let peachStrong = Color(hex: "#F28A5C")
    static let yellow = Color(hex: "#FFE49A")
    static let mint = Color(hex: "#9DDCD2")
    static let blue = Color(hex: "#A9D8FF")
    static let lavender = Color(hex: "#DCCEF3")
    static let text = Color(hex: "#49352C")
    static let secondary = Color(hex: "#8B7B70")
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View { content.background(.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).shadow(color: Pastel.text.opacity(0.09), radius: 10, y: 5) }
}
extension View { func pastelCard() -> some View { modifier(CardStyle()) } }

struct PastelButton: View {
    let title: String; let icon: String; var color: Color = Pastel.peach; let action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: icon).font(.headline).foregroundStyle(Pastel.text).frame(maxWidth: .infinity).padding(.vertical, 14).background(color).clipShape(Capsule()) }.buttonStyle(.plain) }
}

struct PastelTag: View {
    let text: String; var color: Color = Pastel.yellow
    var body: some View { Text(text).font(.caption.weight(.semibold)).foregroundStyle(Pastel.text).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.7)).clipShape(Capsule()) }
}

struct SectionHeader: View {
    let title: String; var subtitle: String? = nil
    var body: some View { HStack(alignment: .firstTextBaseline) { Text(title).font(.title3.bold()).foregroundStyle(Pastel.text); Spacer(); if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Pastel.secondary) } } }
}

struct EmptyStateView: View {
    var image: String = "pigEmpty"; let title: String; let message: String; var buttonTitle: String?; var action: (() -> Void)?
    var body: some View { VStack(spacing: 14) { Image(image).resizable().scaledToFit().frame(height: 180).accessibilityHidden(true); Text(title).font(.title3.bold()).foregroundStyle(Pastel.text); Text(message).font(.subheadline).foregroundStyle(Pastel.secondary).multilineTextAlignment(.center); if let buttonTitle, let action { PastelButton(title: buttonTitle, icon: "plus", action: action).frame(maxWidth: 260) } }.padding(24) }
}

struct RoundedIconButton: View {
    let icon: String; var color: Color = Pastel.yellow; let action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: icon).font(.headline).foregroundStyle(Pastel.text).frame(width: 44, height: 44).background(color).clipShape(Circle()) }.buttonStyle(.plain) }
}

