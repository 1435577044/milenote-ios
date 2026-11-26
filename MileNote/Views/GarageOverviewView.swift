import SwiftUI

struct GarageOverviewView: View {
    @EnvironmentObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss

    @State private var sort = 0
    @State private var showCarEditor = false
    @State private var editingCar: Ledger? = nil
    @State private var carEditorIsNew = false

    private let sortOptions = ["累计支出", "累计里程", "元/公里", "最近记录"]

    private var cars: [Ledger] {
        let all = store.garage.cars
        switch sort {
        case 1: return all.sorted { distance($0) > distance($1) }
        case 2: return all.sorted { costPerKm($0) > costPerKm($1) }
        case 3: return all.sorted { latestDate($0) > latestDate($1) }
        default: return all.sorted { total($0) > total($1) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MNDetailTopBar(title: "车库总览", actionIcon: "plus") {
                    editingCar = nil
                    carEditorIsNew = true
                    showCarEditor = true
                }

                HStack {
                    Text("\(store.garage.cars.count) 辆车")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Menu {
                        ForEach(sortOptions.indices, id: \.self) { index in
                            Button {
                                sort = index
                            } label: {
                                HStack {
                                    Text("排序：\(sortOptions[index])")
                                    if index == sort { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("排序：\(sortOptions[sort])")
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MN.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(hex: "EEF2F5"))
                        .cornerRadius(16)
                    }
                }

                Text("只并列、不合并：不同动力类型的能耗与元/公里不做合计。")
                    .font(.system(size: 12))
                    .foregroundColor(MN.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(cars) { car in
                    MNCard {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(car.vehicle.name.isEmpty ? "未命名车辆" : car.vehicle.name)
                                    .font(.system(size: 18, weight: .semibold))
                                Text("\(powertrainText(car)) · \(car.records.count) 条记录")
                                    .font(.system(size: 12))
                                    .foregroundColor(MN.secondary)
                            }
                            Spacer()
                            if car.id == store.garage.activeId {
                                Text("当前")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(MN.primary)
                            }
                        }

                        Divider().padding(.vertical, 10)

                        MNMetricsGrid(items: [
                            (title: "累计支出", value: String(format: "¥%.2f", total(car)), unit: ""),
                            (title: "累计里程", value: String(format: "%.0f", distance(car)), unit: "公里"),
                            (title: "元/公里", value: String(format: "%.2f", costPerKm(car)), unit: "元/公里"),
                            (title: "本月支出", value: String(format: "¥%.2f", monthly(car)), unit: ""),
                            (title: "能耗", value: energyText(car), unit: ""),
                            (title: "待办", value: "\(pendingCount(car))", unit: "项"),
                        ])

                        Text("最近记录 \(latestDate(car))")
                            .font(.system(size: 12))
                            .foregroundColor(MN.secondary)
                            .padding(.top, 10)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.setActiveVehicle(car.id)
                        dismiss()
                    }
                }
            }
            .padding(16)
        }
        .background(MN.surface)
        .sheet(isPresented: $showCarEditor) {
            CarEditorView(car: editingCar, isNew: carEditorIsNew)
                .environmentObject(store)
        }
    }

    private func total(_ car: Ledger) -> Double { car.records.reduce(0) { $0 + $1.amount } }
    private func distance(_ car: Ledger) -> Double {
        if let start = car.vehicle.startKm { return max(0, car.vehicle.currentKm - start) }
        let odos = car.records.compactMap { $0.odometer }.sorted()
        return odos.count > 1 ? odos.last! - odos.first! : 0
    }
    private func costPerKm(_ car: Ledger) -> Double {
        let d = distance(car)
        return d > 0 ? total(car) / d : 0
    }
    private func monthly(_ car: Ledger) -> Double {
        let prefix = String(todayString().prefix(7))
        return car.records.filter { $0.date.hasPrefix(prefix) }.reduce(0) { $0 + $1.amount }
    }
    private func pendingCount(_ car: Ledger) -> Int { car.reminders.filter { !$0.done }.count }
    private func latestDate(_ car: Ledger) -> String { car.records.map { $0.date }.max() ?? "—" }
    private func powertrainText(_ car: Ledger) -> String {
        switch car.vehicle.powertrain {
        case "ev": return "纯电"
        case "phev": return "插混"
        default: return "燃油"
        }
    }
    private func energyText(_ car: Ledger) -> String {
        let kind: EnergyKind = car.vehicle.isElectric ? .electric : .fuel
        let intervals = energyIntervals(car.records, kind: kind) + manualEnergyIntervals(car.records)
        guard let rate = averageRate(intervals) else { return "—" }
        return String(format: "%.1f \(car.vehicle.isElectric ? "度" : "升")/百公里", rate)
    }
}
