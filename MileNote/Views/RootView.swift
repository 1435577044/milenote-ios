import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: GarageStore

    private var accent: Color {
        let palette = Categories.palettes[store.garage.theme] ?? Categories.palettes["blue"]!
        return Color(hex: palette[0])
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("概览", systemImage: "chart.bar.fill") }
            RecordsView()
                .tabItem { Label("记录", systemImage: "list.bullet.rectangle") }
            EnergyView()
                .tabItem { Label("能耗", systemImage: "fuelpump") }
            MaintenanceView()
                .tabItem { Label("保养", systemImage: "wrench.and.screwdriver") }
            SettingsView()
                .tabItem { Label("我的", systemImage: "gearshape") }
        }
        .accentColor(accent)
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: GarageStore

    private var car: Ledger? { store.activeCar }
    private var theme: String { store.garage.theme }

    var body: some View {
        NavigationView {
            Group {
                if let car = car {
                    ScrollView {
                        VStack(spacing: 16) {
                            carPicker

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                StatCard(
                                    title: "总支出",
                                    value: moneyText(totalAmount(car.records)),
                                    caption: "\(car.records.count) 条记录",
                                    tint: categoryColor("油费", theme: theme)
                                )
                                StatCard(
                                    title: "本月支出",
                                    value: moneyText(monthlyTotals(car.records, limit: 1).first?.amount ?? 0),
                                    caption: String(todayString().prefix(7)),
                                    tint: categoryColor("保养", theme: theme)
                                )
                                StatCard(
                                    title: "当前里程",
                                    value: numberText(car.vehicle.currentKm) + " km",
                                    caption: car.vehicle.plate.isEmpty ? "未填写车牌" : car.vehicle.plate,
                                    tint: categoryColor("保险", theme: theme)
                                )
                                StatCard(
                                    title: car.vehicle.isElectric ? "平均电耗" : "平均油耗",
                                    value: averageText(car),
                                    caption: car.vehicle.isElectric ? "kWh/100km" : "L/100km",
                                    tint: categoryColor("过路费", theme: theme)
                                )
                            }

                            SectionCard(title: "近 6 个月支出") {
                                let months = monthlyTotals(car.records)
                                if months.isEmpty {
                                    EmptyState(text: "还没有记录，去「记录」添加第一笔吧")
                                } else {
                                    VerticalBarChart(items: months.map { month in
                                        (shortDate(month.month + "-01"), month.amount, categoryColor("油费", theme: theme))
                                    })
                                }
                            }

                            SectionCard(title: "费用构成") {
                                let totals = categoryTotals(car.records)
                                if totals.isEmpty {
                                    EmptyState(text: "暂无分类数据")
                                } else {
                                    HorizontalBars(items: totals, theme: theme)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    EmptyState(text: "还没有车辆，去「我的」添加一辆车")
                }
            }
            .navigationTitle("里程志")
        }
        .navigationViewStyle(.stack)
    }

    private var carPicker: some View {
        Menu {
            ForEach(store.garage.cars) { item in
                Button {
                    store.setActiveVehicle(item.id)
                } label: {
                    HStack {
                        Text(item.vehicle.name.isEmpty ? "未命名车辆" : item.vehicle.name)
                        if item.id == store.garage.activeId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "car.fill")
                Text(car?.vehicle.name.isEmpty == false ? car!.vehicle.name : "选择车辆")
                Spacer()
                Image(systemName: "chevron.down")
            }
            .font(.subheadline.weight(.medium))
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func averageText(_ car: Ledger) -> String {
        let kind: EnergyKind = car.vehicle.isElectric ? .electric : .fuel
        let intervals = energyIntervals(car.records, kind: kind) + manualEnergyIntervals(car.records)
        guard let rate = averageRate(intervals) else { return "—" }
        return numberText(rate, digits: 1)
    }
}
