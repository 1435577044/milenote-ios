import SwiftUI

struct ReportView: View {
    @EnvironmentObject var store: GarageStore

    @State private var mode = 0
    @State private var monthOffset = 0
    @State private var useMoM = true

    private var car: Ledger? { store.activeCar }

    private var calendar: Calendar { Calendar.current }
    private var periodStart: Date {
        let now = Date()
        switch mode {
        case 0:
            let components = calendar.dateComponents([.year, .month], from: now)
            let base = calendar.date(from: components) ?? now
            return calendar.date(byAdding: .month, value: monthOffset, to: base) ?? now
        case 1:
            let components = calendar.dateComponents([.year], from: now)
            let base = calendar.date(from: components) ?? now
            return calendar.date(byAdding: .year, value: monthOffset, to: base) ?? now
        default:
            return calendar.date(byAdding: .year, value: -50, to: now) ?? now
        }
    }
    private var periodEnd: Date {
        switch mode {
        case 0: return calendar.date(byAdding: .month, value: 1, to: periodStart) ?? Date()
        case 1: return calendar.date(byAdding: .year, value: 1, to: periodStart) ?? Date()
        default: return Date()
        }
    }

    private var records: [Record] {
        guard let car = car else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return car.records.filter { record in
            guard let date = formatter.date(from: record.date) else { return false }
            return date >= periodStart && date < periodEnd
        }
    }

    private var previousRecords: [Record] {
        guard let car = car else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let from = useMoM ? calendar.date(byAdding: .month, value: -1, to: periodStart) ?? periodStart
                          : calendar.date(byAdding: .year, value: -1, to: periodStart) ?? periodStart
        let to = useMoM ? periodStart : calendar.date(byAdding: .year, value: -1, to: periodEnd) ?? periodStart
        return car.records.filter { record in
            guard let date = formatter.date(from: record.date) else { return false }
            return date >= from && date < to
        }
    }

    private var total: Double { records.reduce(0) { $0 + $1.amount } }
    private var previousTotal: Double { previousRecords.reduce(0) { $0 + $1.amount } }
    private var distance: Double {
        guard let car = car else { return 0 }
        let odos = records.compactMap { $0.odometer }.sorted()
        if odos.count > 1 { return odos.last! - odos.first! }
        if let start = car.vehicle.startKm { return max(0, car.vehicle.currentKm - start) }
        return 0
    }
    private var previousDistance: Double {
        let odos = previousRecords.compactMap { $0.odometer }.sorted()
        return odos.count > 1 ? odos.last! - odos.first! : 0
    }
    private var daily: Double {
        let days = max(1, calendar.dateComponents([.day], from: periodStart, to: min(periodEnd, Date())).day ?? 1)
        return total / Double(days)
    }
    private var previousDaily: Double {
        let days = max(1, calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 1)
        return previousTotal / Double(days)
    }
    private var perKm: Double { distance > 0 ? total / distance : 0 }
    private var previousPerKm: Double { previousDistance > 0 ? previousTotal / previousDistance : 0 }

    private var periodTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch mode {
        case 0:
            formatter.dateFormat = "yyyy 年 M 月"
            return formatter.string(from: periodStart)
        case 1:
            formatter.dateFormat = "yyyy 年"
            return formatter.string(from: periodStart)
        default:
            return "累计"
        }
    }

    private var categoryTotals: [(title: String, amount: Double, color: Color)] {
        var values: [String: Double] = [:]
        for record in records {
            let name = Categories.normalize(record.category).isEmpty ? "未分类" : Categories.normalize(record.category)
            values[name, default: 0] += record.amount
        }
        return values
            .sorted { $0.value > $1.value }
            .map { (title: $0.key, amount: $0.value, color: MN.categoryColor($0.key)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MNDetailTopBar(title: "用车报告")

                HStack(spacing: 8) {
                    Picker("", selection: $mode) {
                        Text("月报").tag(0)
                        Text("年报").tag(1)
                        Text("累计").tag(2)
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        Button { monthOffset -= 1 } label: {
                            Image(systemName: "chevron.left")
                        }
                        Text(periodTitle)
                            .font(.system(size: 13, weight: .medium))
                        Button { monthOffset += 1 } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .foregroundColor(MN.onSurface)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .cornerRadius(18)
                }

                if let car = car {
                    ZStack(alignment: .leading) {
                        MN.gradient(car.vehicle.theme)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("\(car.vehicle.name) · \(car.vehicle.plate)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                MNPill(text: "进行中", foreground: .white, background: .white.opacity(0.18))
                            }
                            Text("本期支出")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                            Text(String(format: "¥%.2f", total))
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(.white)
                            Divider().background(Color.white.opacity(0.25))
                            HStack {
                                ReportMetric(title: "里程", value: "\(Int(distance)) 公里")
                                ReportMetric(title: "每公里", value: String(format: "%.2f 元", perKm))
                                ReportMetric(title: "日均", value: String(format: "%.1f 元", daily))
                            }
                        }
                        .padding(18)
                    }
                    .frame(height: 280)
                    .cornerRadius(28)

                    MNCard {
                        HStack {
                            Text("对比")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Picker("", selection: $useMoM) {
                                Text("环比").tag(true)
                                Text("同比").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(MN.primary).frame(width: 8, height: 8)
                                Text("本期").font(.system(size: 11)).foregroundColor(MN.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "C1C7CC")).frame(width: 8, height: 8)
                                Text(useMoM ? "上月同期" : "去年同期").font(.system(size: 11)).foregroundColor(MN.secondary)
                            }
                        }
                        CompareRow(title: "支出", current: total, previous: previousTotal, unit: "¥", digits: 2)
                        CompareRow(title: "日均", current: daily, previous: previousDaily, unit: "¥", digits: 2)
                        CompareRow(title: "每公里", current: perKm, previous: previousPerKm, unit: "¥", digits: 2)
                        CompareRow(title: "里程", current: distance, previous: previousDistance, unit: "", digits: 0)
                    }

                    MNCard {
                        HStack {
                            Text("费用构成")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Text("\(categoryTotals.count) 个分类")
                                .font(.system(size: 12))
                                .foregroundColor(MN.secondary)
                        }
                        MNDonutChart(items: categoryTotals)
                    }
                }
            }
            .padding(16)
        }
        .background(MN.surface)
    }
}

private struct ReportMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompareRow: View {
    let title: String
    let current: Double
    let previous: Double
    let unit: String
    let digits: Int

    var body: some View {
        let upper = max(current, previous, 1)
        return VStack(spacing: 4) {
            HStack {
                Text(title).font(.system(size: 14)).foregroundColor(MN.onSurface)
                Spacer()
                Text("\(unit)\(String(format: "%.\(digits)f", current))")
                    .font(.system(size: 13, weight: .medium))
                Text("\(unit)\(String(format: "%.\(digits)f", previous))")
                    .font(.system(size: 11))
                    .foregroundColor(MN.secondary)
            }
            HStack(spacing: 4) {
                GeometryReader { geo in
                    Capsule().fill(MN.primary)
                        .frame(width: geo.size.width * CGFloat(current / upper), height: 7)
                }
                .frame(height: 7)
                GeometryReader { geo in
                    Capsule().fill(Color(hex: "C1C7CC"))
                        .frame(width: geo.size.width * CGFloat(previous / upper), height: 7)
                }
                .frame(height: 7)
            }
        }
        .padding(.vertical, 5)
    }
}

extension Vehicle {
    var theme: String { "blue" }
}
