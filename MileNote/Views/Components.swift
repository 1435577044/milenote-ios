import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 通用视图组件

extension Color {
    init(hex: String) {
        let text = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: text).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

func categoryColor(_ name: String, theme: String) -> Color {
    let raw = Categories.color(theme: theme, name: name)
    if raw.hasPrefix("#") { return Color(hex: raw) }
    let parts = raw
        .replacingOccurrences(of: "hsl(", with: "")
        .replacingOccurrences(of: ")", with: "")
        .replacingOccurrences(of: "%", with: "")
        .split(separator: " ")
    if parts.count >= 3,
       let h = Double(parts[0]), let s = Double(parts[1]), let l = Double(parts[2]) {
        return Color(uiColor: UIColor(
            hue: CGFloat(h) / 360,
            saturation: CGFloat(s) / 100,
            brightness: CGFloat(l) / 100,
            alpha: 1
        ))
    }
    return .gray
}

struct StatCard: View {
    let title: String
    let value: String
    let caption: String?
    let tint: Color

    init(title: String, value: String, caption: String? = nil, tint: Color = .accentColor) {
        self.title = title
        self.value = value
        self.caption = caption
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption = caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct EmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "car.2")
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

struct VerticalBarChart: View {
    let items: [(label: String, value: Double, color: Color)]

    var body: some View {
        let upper = items.map { $0.value }.max() ?? 1
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<items.count, id: \.self) { index in
                let item = items[index]
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Color(.tertiarySystemFill)
                            .frame(height: 100)
                            .cornerRadius(5)
                        item.color
                            .frame(height: upper > 0 ? CGFloat(max(4, item.value / upper * 100)) : 4)
                            .cornerRadius(5)
                    }
                    Text(item.label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 140)
    }
}

struct HorizontalBars: View {
    let items: [CategoryTotal]
    let theme: String

    var body: some View {
        let upper = items.map { $0.amount }.max() ?? 1
        VStack(spacing: 10) {
            ForEach(items.prefix(8)) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.category)
                            .font(.subheadline)
                        Spacer()
                        Text(moneyText(item.amount))
                            .font(.subheadline.weight(.medium))
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Color(.tertiarySystemFill)
                                .frame(height: 8)
                                .cornerRadius(4)
                            categoryColor(item.category, theme: theme)
                                .frame(width: upper > 0 ? geometry.size.width * CGFloat(item.amount / upper) : 0, height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
