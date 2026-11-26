import SwiftUI

// MARK: - 里程志视觉系统（与 Android 版一致）
enum MN {
    static let surface = Color(hex: "F6FAFC")
    static let onSurface = Color(hex: "191C1E")
    static let secondary = Color(hex: "42484B")
    static let outline = Color(hex: "72787C")
    static let outlineVariant = Color(hex: "C1C7CC")
    static let primary = Color(hex: "446378")
    static let primaryContainer = Color(hex: "D4E5F2")
    static let success = Color(hex: "1F6E43")
    static let warning = Color(hex: "8A5A00")
    static let danger = Color(hex: "B3261E")
    static let info = Color(hex: "35607F")

    static let heroStart = Color(hex: "354F61")
    static let heroEnd = Color(hex: "69899E")

    static let categoryNames = ["油费", "保险", "保养", "过路费", "停车费", "维修", "罚单", "汽车用品", "汽车美容"]
    static let categoryColors: [Color] = [
        Color(hex: "55758B"), Color(hex: "3E7F8F"), Color(hex: "5C8A6A"),
        Color(hex: "38566C"), Color(hex: "8A7B63"), Color(hex: "A0674F"),
        Color(hex: "B07A3C"), Color(hex: "7A8CA6"), Color(hex: "A97BB0"),
    ]

    static func categoryColor(_ name: String) -> Color {
        let normalized = name == "维修保养" ? "保养" : name
        guard let index = categoryNames.firstIndex(of: normalized) else { return secondary }
        return categoryColors[index % categoryColors.count]
    }

    static func gradient(_ theme: String) -> LinearGradient {
        switch theme {
        case "forest": return LinearGradient(colors: [Color(hex: "1F3D32"), Color(hex: "3D6550")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "purple": return LinearGradient(colors: [Color(hex: "3A2D55"), Color(hex: "6E598A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "orange": return LinearGradient(colors: [Color(hex: "533A2C"), Color(hex: "926B4B")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "graphite": return LinearGradient(colors: [Color(hex: "273C49"), Color(hex: "516976")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [heroStart, heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

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

// MARK: - 基础组件

struct MNCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MN.outlineVariant.opacity(0.65), lineWidth: 0.5)
            )
    }
}

struct MNSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(MN.onSurface)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(MN.secondary)
                }
            }
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MN.primary)
                }
            }
        }
    }
}

struct MNMetricsGrid: View {
    let items: [(title: String, value: String, unit: String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14))
                        .foregroundColor(MN.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.value)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(MN.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(item.unit)
                            .font(.system(size: 12))
                            .foregroundColor(MN.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct MNPill: View {
    let text: String
    var foreground: Color = MN.primary
    var background: Color = Color(hex: "EEF2F5")

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .cornerRadius(16)
    }
}

struct MNHeroCard: View {
    let title: String
    let subtitle: String
    let footer: String
    let theme: String

    var body: some View {
        ZStack(alignment: .leading) {
            MN.gradient(theme)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(1)
                Spacer()
                Text(footer)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.78))
            }
            .padding(20)
            HStack {
                Spacer()
                Image(systemName: "car.fill")
                    .font(.system(size: 78))
                    .foregroundColor(.white.opacity(0.16))
                    .offset(y: 12)
            }
            .padding(.trailing, 12)
        }
        .frame(height: 188)
        .cornerRadius(28)
    }
}

// MARK: - 图表

struct MNStackedBarChart: View {
    let months: [(label: String, segments: [(value: Double, color: Color)])]

    private var maxValue: Double {
        months.map { $0.segments.reduce(0) { $0 + $1.value } }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(months.indices, id: \.self) { index in
                let month = months[index]
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "E5E9EB"))
                        VStack(spacing: 0) {
                            ForEach(month.segments.indices, id: \.self) { segmentIndex in
                                let segment = month.segments[segmentIndex]
                                segment.color
                                    .frame(height: maxValue > 0 ? CGFloat(max(2, segment.value / maxValue * 150)) : 2)
                            }
                        }
                        .cornerRadius(6)
                    }
                    .frame(height: 150)
                    Text(month.label)
                        .font(.system(size: 11))
                        .foregroundColor(MN.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct MNLineChart: View {
    let values: [Double]
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                MNPill(text: label, foreground: .white, background: MN.primary)
            }
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let upper = (values.max() ?? 10) * 1.15
                let lower = 0.0
                let points = values.enumerated().map { index, value -> CGPoint in
                    let x = values.count > 1 ? width * CGFloat(index) / CGFloat(values.count - 1) : width / 2
                    let normalized = upper > lower ? (value - lower) / (upper - lower) : 0
                    return CGPoint(x: x, y: height - height * CGFloat(normalized))
                }
                ZStack {
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: height))
                        for point in points { path.addLine(to: point) }
                        if let last = points.last { path.addLine(to: CGPoint(x: last.x, y: height)) }
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [MN.primary.opacity(0.22), MN.primary.opacity(0.01)], startPoint: .top, endPoint: .bottom))

                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(MN.primary, lineWidth: 2)

                    ForEach(points.indices, id: \.self) { index in
                        Circle()
                            .fill(MN.primary)
                            .frame(width: 5, height: 5)
                            .position(points[index])
                    }
                }
            }
            .frame(height: 150)
        }
    }
}

struct MNDonutChart: View {
    let items: [(title: String, amount: Double, color: Color)]

    var body: some View {
        let total = items.reduce(0) { $0 + $1.amount }
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "E5E9EB"), lineWidth: 18)
                if total > 0 {
                    Circle()
                        .trim(from: 0, to: min(1, CGFloat(items.first?.amount ?? 0) / CGFloat(total)))
                        .stroke(items.first?.color ?? MN.primary, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.prefix(5).indices, id: \.self) { index in
                    let item = items[index]
                    HStack(spacing: 6) {
                        Circle().fill(item.color).frame(width: 7, height: 7)
                        Text(item.title).font(.system(size: 13)).foregroundColor(MN.onSurface)
                        Spacer()
                        Text(String(format: "¥%.2f", item.amount)).font(.system(size: 13, weight: .medium)).foregroundColor(MN.onSurface)
                    }
                }
            }
        }
    }
}

struct MNYearPicker: View {
    @Binding var year: Int

    var body: some View {
        Menu {
            ForEach((2020...2035).reversed(), id: \.self) { value in
                Button {
                    year = value
                } label: {
                    HStack {
                        Text("\(value) 年")
                        if value == year { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(year) 年")
                Image(systemName: "chevron.down")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(MN.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "EEF2F5"))
            .cornerRadius(16)
        }
    }
}
