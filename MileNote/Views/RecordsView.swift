import SwiftUI

struct RecordsView: View {
    @EnvironmentObject var store: GarageStore

    @State private var search = ""
    @State private var categoryFilter = "全部"
    @State private var showEditor = false
    @State private var draft = Record()

    private var car: Ledger? { store.activeCar }
    private var options: [String] {
        ["全部"] + (car.map { Categories.options(for: $0) } ?? [])
    }

    private var filtered: [Record] {
        guard let car = car else { return [] }
        return car.records
            .filter { record in
                let matchesCategory = categoryFilter == "全部" || Categories.normalize(record.category) == categoryFilter
                let keyword = search.trimmingCharacters(in: .whitespaces)
                let matchesSearch = keyword.isEmpty ||
                    record.note.localizedCaseInsensitiveContains(keyword) ||
                    (record.location ?? "").localizedCaseInsensitiveContains(keyword) ||
                    record.category.localizedCaseInsensitiveContains(keyword)
                return matchesCategory && matchesSearch
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationView {
            Group {
                if car == nil {
                    EmptyState(text: "还没有车辆，去「我的」添加一辆车")
                } else {
                    VStack(spacing: 10) {
                        Picker("分类", selection: $categoryFilter) {
                            ForEach(options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)

                        List {
                            ForEach(filtered) { record in
                                Button {
                                    draft = record
                                    showEditor = true
                                } label: {
                                    recordRow(record)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.deleteRecord(record.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                            if filtered.isEmpty {
                                EmptyState(text: "没有符合条件的记录")
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                    .searchable(text: $search, prompt: "搜索备注 / 地点 / 分类")
                }
            }
            .navigationTitle("记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        var newRecord = Record()
                        newRecord.date = todayString()
                        newRecord.category = "油费"
                        draft = newRecord
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                RecordEditorView(record: draft, isNew: !filtered.contains { $0.id == draft.id })
                    .environmentObject(store)
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private func recordRow(_ record: Record) -> some View {
        HStack(spacing: 12) {
            ZStack {
                categoryColor(record.category, theme: store.garage.theme).opacity(0.18)
                Image(systemName: symbol(for: record.category))
                    .foregroundColor(categoryColor(record.category, theme: store.garage.theme))
            }
            .frame(width: 38, height: 38)
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Categories.normalize(record.category).isEmpty ? "未分类" : Categories.normalize(record.category))
                        .font(.subheadline.weight(.medium))
                    if record.full {
                        Text("加满").font(.caption2).foregroundColor(.secondary)
                    }
                }
                Text(record.note.isEmpty ? record.date : "\(record.date) · \(record.note)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(moneyText(record.amount))
                    .font(.subheadline.weight(.semibold))
                if let odo = record.odometer {
                    Text(numberText(odo) + " km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func symbol(for category: String) -> String {
        switch Categories.normalize(category) {
        case "油费": return "fuelpump"
        case "保险": return "shield"
        case "保养": return "wrench"
        case "过路费": return "road.lanes"
        case "停车费": return "parkingsign"
        case "维修": return "hammer"
        case "罚单": return "doc.text"
        case "汽车用品": return "shippingbox"
        case "汽车美容": return "sparkles"
        default: return "circle"
        }
    }
}

struct RecordEditorView: View {
    @EnvironmentObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss

    let record: Record
    let isNew: Bool

    @State private var date: String
    @State private var category: String
    @State private var amount: String
    @State private var odometer: String
    @State private var energyAmount: String
    @State private var full: Bool
    @State private var missed: Bool
    @State private var note: String
    @State private var location: String
    @State private var fuelGrade: String
    @State private var showDeleteConfirm = false

    init(record: Record, isNew: Bool) {
        self.record = record
        self.isNew = isNew
        _date = State(initialValue: record.date.isEmpty ? todayString() : record.date)
        _category = State(initialValue: record.category.isEmpty ? "油费" : record.category)
        _amount = State(initialValue: record.amount == 0 ? "" : numberText(record.amount, digits: 2))
        _odometer = State(initialValue: record.odometer.map { numberText($0) } ?? "")
        _energyAmount = State(initialValue: (record.kwh ?? record.liters).map { numberText($0, digits: 2) } ?? "")
        _full = State(initialValue: record.full)
        _missed = State(initialValue: record.missed)
        _note = State(initialValue: record.note)
        _location = State(initialValue: record.location ?? "")
        _fuelGrade = State(initialValue: record.fuelGrade ?? "")
    }

    private var isElectric: Bool { store.activeCar?.vehicle.isElectric ?? false }
    private var isEnergyCategory: Bool { Categories.isEnergy(category) }
    private var options: [String] { store.activeCar.map { Categories.options(for: $0) } ?? Categories.all }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    DatePicker("日期", selection: Binding(
                        get: { dateFromString(date) },
                        set: { date = stringFromDate($0) }
                    ), displayedComponents: .date)
                    Picker("分类", selection: $category) {
                        ForEach(options, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("实付金额（元）", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("总里程（km）", text: $odometer)
                        .keyboardType(.decimalPad)
                }

                if isEnergyCategory {
                    Section(isElectric ? "充电信息" : "加油信息") {
                        TextField(isElectric ? "充电量（kWh）" : "加油量（L）", text: $energyAmount)
                            .keyboardType(.decimalPad)
                        Toggle(isElectric ? "本次充满" : "本次加满", isOn: $full)
                        Toggle("此前有漏记", isOn: $missed)
                        if !isElectric {
                            Picker("燃油标号", selection: $fuelGrade) {
                                Text("未指定").tag("")
                                ForEach(["92#", "95#", "98#", "0#"], id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }
                }

                Section("其他") {
                    TextField("地点 / 加油站", text: $location)
                    TextField("备注", text: $note)
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("删除这条记录")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "新建记录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                }
            }
            .alert("确认删除？", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    store.deleteRecord(record.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        var saved = record
        saved.date = date
        saved.category = category
        saved.amount = Double(amount) ?? 0
        saved.odometer = Double(odometer).flatMap { $0 > 0 ? $0 : nil }
        let energy = Double(energyAmount).flatMap { $0 > 0 ? $0 : nil }
        saved.liters = isEnergyCategory && !isElectric ? energy : nil
        saved.kwh = isEnergyCategory && isElectric ? energy : nil
        saved.full = isEnergyCategory && full
        saved.missed = isEnergyCategory && missed
        saved.note = note
        saved.location = location.isEmpty ? nil : location
        saved.fuelGrade = isEnergyCategory && !isElectric && !fuelGrade.isEmpty ? fuelGrade : nil
        saved.source = isNew ? "iOS" : saved.source
        store.upsertRecord(saved)
        dismiss()
    }

    private func dateFromString(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: text) ?? Date()
    }

    private func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
