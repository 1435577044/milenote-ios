import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: GarageStore
    var onNavigate: (MNPage) -> Void

    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var tab = 0

    private var car: Ledger? { store.activeCar }
    private var theme: String { store.garage.theme }

    private var yearRecords: [Record] {
        car?.records.filter { $0.date.hasPrefix("\(year)") } ?? []
    }

    private var totalAmount: Double { yearRecords.reduce(0) { $0 + $1.amount } }
    private var distance: Double {
        guard let car = car else { return 0 }
        if let start = car.vehicle.startKm {
            return max(0, car.vehicle.currentKm - start)
        }
        let odos = car.records.compactMap { $0.odometer }.sorted()
        guard odos.count > 1 else { return 0 }
        return odos.last! - odos.first!
    }
    private var costPerKm: Double { distance > 0 ? totalAmount / distance : 0 }
    private var averageConsumption: Double? {
        guard let car = car else { return nil }
        let kind: EnergyKind = car.vehicle.isElectric ? .electric : .fuel
        let intervals = (energyIntervals(car.records, kind: kind) + manualEnergyIntervals(car.records))
            .filter { $0.date.hasPrefix("\(year)") }
        return averageRate(intervals)
    }

    private var companionDays: Int {
        guard let dateString = car?.vehicle.companionDate else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    private var months: [(label: String, segments: [(value: Double, color: Color)])] {
        guard let car = car else { return [] }
        var result: [(label: String, segments: [(value: Double, color: Color)])] = []
        for month in 1...12 {
            let prefix = String(format: "%d-%02d", year, month)
            let records = car.records.filter { $0.date.hasPrefix(prefix) }
            if records.isEmpty { continue }
            if tab == 0 {
                var totals: [String: Double] = [:]
                for record in records {
                    let name = Categories.normalize(record.category).isEmpty ? "未分类" : Categories.normalize(record.category)
                    totals[name, default: 0] += record.amount
                }
                let segments = totals
                    .sorted { $0.value > $1.value }
                    .map { (value: $0.value, color: MN.categoryColor($0.key)) }
                result.append((label: "\(month)月", segments: segments))
            } else {
                let sorted = records.compactMap { $0.odometer }.sorted()
                let value = sorted.count > 1 ? sorted.last! - sorted.first! : 0
                result.append((label: "\(month)月", segments: [(value: value, color: MN.primary)]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MNTopBar(title: "总览", actionIcon: "doc.text") { onNavigate(.records) }

                if let car = car {
                    MNHeroCard(
                        title: car.vehicle.name.isEmpty ? "我的爱车" : car.vehicle.name,
                        subtitle: "\(car.vehicle.plate.isEmpty ? "A号车" : car.vehicle.plate) · \(car.vehicle.model.isEmpty ? "车型" : car.vehicle.model)",
                        footer: "已陪伴 \(companionDays) 天 · \(car.records.count) 笔",
                        theme: theme
                    )

                    MNCard {
                        MNSectionHeader(title: "用车统计")
                        MNYearPicker(year: $year)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        MNMetricsGrid(items: [
                            (title: "用车支出", value: String(format: "%.2f", totalAmount), unit: "元"),
                            (title: "行驶里程", value: String(format: "%.0f", distance), unit: "公里"),
                            (title: "用车成本", value: String(format: "%.2f", costPerKm), unit: "元/公里"),
                            (title: car.vehicle.isElectric ? "平均电耗" : "平均油耗", value: averageConsumption.map { String(format: "%.2f", $0) } ?? "—", unit: car.vehicle.isElectric ? "度/百公里" : "升/百公里"),
                        ])
                    }

                    MNCard {
                        HStack(spacing: 12) {
                            Picker("", selection: $tab) {
                                Text("支出").tag(0)
                                Text("里程").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                            Spacer()
                            Button {
                                // 筛选入口在 Android 版是筛选面板，iOS 版保留入口占位
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 16))
                                    .foregroundColor(MN.primary)
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "EEF2F5"))
                                    .cornerRadius(16)
                            }
                            MNYearPicker(year: $year)
                        }
                        if months.isEmpty {
                            MNEmptyState(text: "今年还没有记录")
                        } else {
                            MNStackedBarChart(months: months)
                        }
                    }
                } else {
                    MNEmptyState(text: "还没有车辆，去「我的」添加一辆车")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(MN.surface)
    }
}

struct MNEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "car.2")
                .font(.system(size: 32))
                .foregroundColor(MN.outline)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(MN.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
