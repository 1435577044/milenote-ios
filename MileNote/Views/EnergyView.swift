import SwiftUI

struct EnergyView: View {
    @EnvironmentObject var store: GarageStore

    @State private var useElectric = false

    private var car: Ledger? { store.activeCar }
    private var theme: String { store.garage.theme }

    private var intervals: [EnergyInterval] {
        guard let car = car else { return [] }
        let kind: EnergyKind = useElectric ? .electric : .fuel
        return energyIntervals(car.records, kind: kind) + manualEnergyIntervals(car.records)
    }

    var body: some View {
        NavigationView {
            Group {
                if let car = car {
                    ScrollView {
                        VStack(spacing: 16) {
                            if car.vehicle.powertrain == nil {
                                Picker("能源类型", selection: $useElectric) {
                                    Text("燃油").tag(false)
                                    Text("纯电").tag(true)
                                }
                                .pickerStyle(.segmented)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                StatCard(
                                    title: useElectric ? "平均电耗" : "平均油耗",
                                    value: averageRate(intervals).map { numberText($0, digits: 2) } ?? "—",
                                    caption: useElectric ? "kWh / 100km" : "L / 100km",
                                    tint: categoryColor("油费", theme: theme)
                                )
                                StatCard(
                                    title: "统计区间",
                                    value: "\(intervals.count) 段",
                                    caption: "满箱法 / 满电法",
                                    tint: categoryColor("保养", theme: theme)
                                )
                            }

                            SectionCard(title: "能耗趋势") {
                                if intervals.isEmpty {
                                    EmptyState(text: "至少需要两次「加满 / 充满」记录才能计算能耗")
                                } else {
                                    VerticalBarChart(items: Array(intervals.suffix(8)).map { interval in
                                        (shortDate(interval.date), interval.rate, categoryColor("油费", theme: theme))
                                    })
                                    Text("单位：\(useElectric ? "kWh" : "L") / 100km")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            SectionCard(title: "区间明细") {
                                if intervals.isEmpty {
                                    EmptyState(text: "暂无区间")
                                } else {
                                    ForEach(intervals.indices.reversed(), id: \.self) { index in
                                        let interval = intervals[index]
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(interval.date)
                                                    .font(.subheadline)
                                                Text("\(numberText(interval.distance)) km · \(interval.source)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 3) {
                                                Text(numberText(interval.rate, digits: 2))
                                                    .font(.subheadline.weight(.semibold))
                                                Text(useElectric ? "kWh/100km" : "L/100km")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        Divider()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    EmptyState(text: "还没有车辆")
                }
            }
            .navigationTitle("能耗")
            .onAppear {
                if let powertrain = car?.vehicle.powertrain {
                    useElectric = powertrain == "ev"
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
