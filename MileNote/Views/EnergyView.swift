import SwiftUI

struct FuelView: View {
    @EnvironmentObject var store: GarageStore
    var onNavigate: (MNPage) -> Void

    @State private var year = Calendar.current.component(.year, from: Date())

    private var car: Ledger? { store.activeCar }
    private var isElectric: Bool { car?.vehicle.isElectric ?? false }
    private var usesEnergyUI: Bool { car?.vehicle.usesEnergyUI ?? false }
    private var title: String { usesEnergyUI ? "能耗" : "油耗" }

    private var yearRecords: [Record] {
        car?.records.filter { $0.date.hasPrefix("\(year)") } ?? []
    }

    private var intervals: [EnergyInterval] {
        guard let car = car else { return [] }
        let kind: EnergyKind = isElectric ? .electric : .fuel
        return (energyIntervals(car.records, kind: kind) + manualEnergyIntervals(car.records))
            .filter { $0.date.hasPrefix("\(year)") }
    }

    private var averageRateValue: Double { averageRate(intervals) ?? 0 }
    private var energyCost: Double {
        let names = isElectric ? [] : ["油费"]
        return yearRecords.filter { names.contains(Categories.normalize($0.category)) }.reduce(0) { $0 + $1.amount }
    }
    private var averageCost: Double {
        let distance = intervals.reduce(0) { $0 + $1.distance }
        return distance > 0 ? energyCost / distance : 0
    }
    private var totalDistance: Double { intervals.reduce(0) { $0 + $1.distance } }

    private var trendValues: [Double] {
        var values: [Double] = []
        for month in 1...12 {
            let prefix = String(format: "%d-%02d", year, month)
            let monthly = intervals.filter { $0.date.hasPrefix(prefix) }
            if let rate = averageRate(monthly) { values.append(rate) }
        }
        return values.isEmpty ? [0] : values
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MNTopBar(title: title, actionIcon: "fuelpump") { onNavigate(.fuelDetail) }

                if car != nil {
                    MNCard {
                        HStack {
                            Text("今日油价")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: "location")
                                Text("北京 · 未定位")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(MN.secondary)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("95#")
                                .font(.system(size: 14))
                                .foregroundColor(MN.secondary)
                            Text("—")
                                .font(.system(size: 32, weight: .semibold))
                            Text("元/升")
                                .font(.system(size: 12))
                                .foregroundColor(MN.secondary)
                            Spacer()
                            Text("iOS 版未接入油价源")
                                .font(.system(size: 11))
                                .foregroundColor(MN.outline)
                        }
                    }

                    MNCard {
                        MNSectionHeader(title: "\(title)概览")
                        MNYearPicker(year: $year)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        MNMetricsGrid(items: [
                            (title: isElectric ? "平均电耗" : "平均油耗", value: String(format: "%.2f", averageRateValue), unit: isElectric ? "度/百公里" : "升/百公里"),
                            (title: isElectric ? "电费支出" : "油费支出", value: String(format: "%.2f", energyCost), unit: "元"),
                            (title: isElectric ? "平均电费" : "平均油费", value: String(format: "%.2f", averageCost), unit: "元/公里"),
                            (title: "行驶里程", value: String(format: "%.0f", totalDistance), unit: "公里"),
                        ])
                    }

                    MNCard {
                        MNSectionHeader(title: "\(title)走势")
                        MNYearPicker(year: $year)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        MNLineChart(
                            values: trendValues,
                            label: String(format: "最近 %.2f %@", averageRateValue, isElectric ? "度/百公里" : "升/百公里")
                        )
                        HStack {
                            Text("1月").foregroundColor(MN.secondary)
                            Spacer()
                            Text("12月").foregroundColor(MN.secondary)
                        }
                        .font(.system(size: 11))
                    }
                } else {
                    MNEmptyState(text: "还没有车辆")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(MN.surface)
    }
}

struct FuelDetailView: View {
    @EnvironmentObject var store: GarageStore

    private var car: Ledger? { store.activeCar }
    private var intervals: [EnergyInterval] {
        guard let car = car else { return [] }
        let kind: EnergyKind = car.vehicle.isElectric ? .electric : .fuel
        return (energyIntervals(car.records, kind: kind) + manualEnergyIntervals(car.records)).reversed()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MNDetailTopBar(title: car?.vehicle.isElectric == true ? "能耗明细" : "油耗明细")
                if intervals.isEmpty {
                    MNEmptyState(text: "至少需要两次「加满 / 充满」记录才能计算能耗")
                } else {
                    MNCard {
                        Text("区间明细")
                            .font(.system(size: 18, weight: .semibold))
                        ForEach(intervals.indices, id: \.self) { index in
                            let item = intervals[index]
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.date)
                                        .font(.system(size: 14))
                                    Text("\(Int(item.distance)) km · \(item.source)")
                                        .font(.system(size: 12))
                                        .foregroundColor(MN.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(String(format: "%.2f", item.rate))
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(car?.vehicle.isElectric == true ? "度/百公里" : "升/百公里")
                                        .font(.system(size: 11))
                                        .foregroundColor(MN.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            if index < intervals.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(MN.surface)
    }
}
