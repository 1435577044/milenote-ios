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
        let keyword = search.trimmingCharacters(in: .whitespaces)
        return car.records
            .filter { record in
                let matchesCategory = categoryFilter == "全部" || Categories.normalize(record.category) == categoryFilter
                let matchesSearch = keyword.isEmpty ||
                    record.note.localizedCaseInsensitiveContains(keyword) ||
                    (record.location ?? "").localizedCaseInsensitiveContains(keyword) ||
                    record.category.localizedCaseInsensitiveContains(keyword)
                return matchesCategory && matchesSearch
            }
            .sorted { $0.date > $1.date }
    }

    private var grouped: [(date: String, records: [Record])] {
        var result: [(date: String, records: [Record])] = []
        for record in filtered {
            if let index = result.firstIndex(where: { $0.date == record.date }) {
                result[index].records.append(record)
            } else {
                result.append((date: record.date, records: [record]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                MNDetailTopBar(title: "费用明细")

                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(MN.outline)
                        TextField("搜索备注 / 地点 / 分类", text: $search)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .cornerRadius(12)

                    Menu {
                        ForEach(options, id: \.self) { option in
                            Button {
                                categoryFilter = option
                            } label: {
                                HStack {
                                    Text(option)
                                    if option == categoryFilter { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16))
                            .foregroundColor(MN.primary)
                            .frame(width: 38, height: 38)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }

                if filtered.isEmpty {
                    MNEmptyState(text: "没有符合条件的记录")
                } else {
                    ForEach(grouped.indices, id: \.self) { groupIndex in
                        let group = grouped[groupIndex]
                        MNCard {
                            Text(group.date)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MN.secondary)
                            ForEach(group.records.indices, id: \.self) { index in
                                recordRow(group.records[index])
                                if index < group.records.count - 1 { Divider() }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(MN.surface)
        .sheet(isPresented: $showEditor) {
            RecordEditorView(record: draft, isNew: false)
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private func recordRow(_ record: Record) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(MN.categoryColor(record.category).opacity(0.16))
                Image(systemName: symbol(for: record.category))
                    .font(.system(size: 17))
                    .foregroundColor(MN.categoryColor(record.category))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(Categories.normalize(record.category).isEmpty ? "未分类" : Categories.normalize(record.category))
                        .font(.system(size: 15, weight: .medium))
                    if record.full {
                        Text("加满").font(.system(size: 10)).foregroundColor(MN.success)
                    }
                }
                Text(record.note.isEmpty ? (record.location ?? record.date) : record.note)
                    .font(.system(size: 12))
                    .foregroundColor(MN.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(moneyText(record.amount))
                    .font(.system(size: 15, weight: .semibold))
                if let odo = record.odometer {
                    Text("\(Int(odo)) km")
                        .font(.system(size: 11))
                        .foregroundColor(MN.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            draft = record
            showEditor = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteRecord(record.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func symbol(for category: String) -> String {
        switch Categories.normalize(category) {
        case "油费": return "fuelpump.fill"
        case "保险": return "shield.fill"
        case "保养": return "wrench.fill"
        case "过路费": return "road.lanes"
        case "停车费": return "parkingsign.circle.fill"
        case "维修": return "hammer.fill"
        case "罚单": return "doc.text.fill"
        case "汽车用品": return "shippingbox.fill"
        case "汽车美容": return "sparkles"
        default: return "circle.fill"
        }
    }
}

// MARK: - 记一笔 / 编辑记录

struct RecordEditorView: View {
    @EnvironmentObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss

    let record: Record
    let isNew: Bool

    @State private var date: String
    @State private var category: String
    @State private var amount: String
    @State private var odometer: String
    @State private var liters: String
    @State private var unitPrice: String
    @State private var payable: String
    @State private var discount: String
    @State private var full: Bool
    @State private var missed: Bool
    @State private var fuelGrade: String
    @State private var location: String
    @State private var note: String
    @State private var showCategoryMenu = false

    init(record: Record, isNew: Bool) {
        self.record = record
        self.isNew = isNew
        _date = State(initialValue: record.date.isEmpty ? todayString() : record.date)
        _category = State(initialValue: record.category.isEmpty ? "油费" : record.category)
        _amount = State(initialValue: record.amount == 0 ? "" : String(format: "%.2f", record.amount))
        _odometer = State(initialValue: record.odometer.map { String(format: "%.0f", $0) } ?? "")
        _liters = State(initialValue: record.liters.map { String(format: "%.2f", $0) } ?? "")
        _unitPrice = State(initialValue: record.unitPrice.map { String(format: "%.2f", $0) } ?? "")
        _payable = State(initialValue: record.payable.map { String(format: "%.2f", $0) } ?? "")
        _discount = State(initialValue: record.discount.map { String(format: "%.2f", $0) } ?? "")
        _full = State(initialValue: record.full)
        _missed = State(initialValue: record.missed)
        _fuelGrade = State(initialValue: record.fuelGrade ?? "95#")
        _location = State(initialValue: record.location ?? "")
        _note = State(initialValue: record.note)
    }

    private var isEnergy: Bool { Categories.isEnergy(category) }
    private var isElectric: Bool { store.activeCar?.vehicle.isElectric ?? false }
    private var categories: [String] { store.activeCar.map { Categories.options(for: $0) } ?? Categories.all }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundColor(MN.onSurface)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isEnergy ? (isElectric ? "记录充电" : "记录加油") : "记一笔")
                        .font(.system(size: 20, weight: .semibold))
                    Text("记入 · \(store.activeCar?.vehicle.name ?? "未命名车辆")")
                        .font(.system(size: 12))
                        .foregroundColor(MN.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(categories.prefix(10), id: \.self) { item in
                            Button {
                                category = item
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: symbol(for: item))
                                        .font(.system(size: 20))
                                    Text(item)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(category == item ? MN.primary : MN.secondary)
                                .background(category == item ? MN.primaryContainer : Color(hex: "F1F4F7"))
                                .cornerRadius(12)
                            }
                        }
                    }

                    MNEditorField(label: "实付金额 · 元") {
                        HStack {
                            Text("¥").font(.system(size: 24)).foregroundColor(MN.onSurface)
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 28, weight: .semibold))
                            Image(systemName: "camera")
                                .foregroundColor(MN.secondary)
                        }
                    }

                    MNEditorField(label: "日期") {
                        HStack {
                            TextField("yyyy-MM-dd", text: $date)
                                .font(.system(size: 16))
                            Image(systemName: "calendar")
                                .foregroundColor(MN.secondary)
                        }
                    }

                    MNEditorField(label: "总里程（选填）") {
                        HStack {
                            Image(systemName: "road.lanes").foregroundColor(MN.secondary)
                            TextField("0", text: $odometer)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 18))
                            Text("公里").foregroundColor(MN.secondary).font(.system(size: 13))
                        }
                    }

                    if isEnergy {
                        HStack(spacing: 12) {
                            MNEditorField(label: isElectric ? "充电量" : "加油量") {
                                HStack {
                                    TextField("0", text: $liters).keyboardType(.decimalPad)
                                    Text(isElectric ? "度" : "升").foregroundColor(MN.secondary).font(.system(size: 13))
                                }
                            }
                            MNEditorField(label: isElectric ? "电价" : "油价") {
                                HStack {
                                    TextField("0", text: $unitPrice).keyboardType(.decimalPad)
                                    Text("元/\(isElectric ? "度" : "升")").foregroundColor(MN.secondary).font(.system(size: 13))
                                }
                            }
                        }
                        HStack(spacing: 12) {
                            MNEditorField(label: "应付金额") {
                                HStack {
                                    TextField("0", text: $payable).keyboardType(.decimalPad)
                                    Text("元").foregroundColor(MN.secondary).font(.system(size: 13))
                                }
                            }
                            MNEditorField(label: "优惠金额") {
                                HStack {
                                    TextField("0", text: $discount).keyboardType(.decimalPad)
                                    Text("元").foregroundColor(MN.secondary).font(.system(size: 13))
                                }
                            }
                        }
                        HStack {
                            MNCheckbox(title: isElectric ? "本次充满" : "本次加满", isOn: $full)
                            MNCheckbox(title: "此前漏记", isOn: $missed)
                            Spacer()
                            if !isElectric {
                                Menu {
                                    ForEach(["92#", "95#", "98#", "0#"], id: \.self) { grade in
                                        Button {
                                            fuelGrade = grade
                                        } label: {
                                            HStack {
                                                Text(grade)
                                                if grade == fuelGrade { Image(systemName: "checkmark") }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(fuelGrade)
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(MN.onSurface)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MN.outlineVariant))
                                }
                            }
                        }
                    }

                    MNEditorField(label: "加油站 / 地点（选填）") {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(MN.secondary)
                            TextField("地点", text: $location)
                                .font(.system(size: 15))
                        }
                    }
                    MNEditorField(label: "备注（选填）") {
                        TextField("备注", text: $note)
                            .font(.system(size: 15))
                    }
                }
                .padding(16)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .foregroundColor(MN.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                Button {
                    save()
                    dismiss()
                } label: {
                    Text("保存记录")
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(MN.primary)
                        .cornerRadius(24)
                }
            }
            .padding(12)
            .background(Color.white)
        }
        .background(MN.surface)
    }

    private func save() {
        var saved = record
        saved.date = date
        saved.category = category
        saved.amount = Double(amount) ?? 0
        saved.odometer = Double(odometer).flatMap { $0 > 0 ? $0 : nil }
        saved.liters = isEnergy && !isElectric ? Double(liters) : nil
        saved.kwh = isEnergy && isElectric ? Double(liters) : nil
        saved.unitPrice = isEnergy ? Double(unitPrice) : nil
        saved.payable = isEnergy ? Double(payable) : nil
        saved.discount = isEnergy ? Double(discount) : nil
        saved.full = isEnergy && full
        saved.missed = isEnergy && missed
        saved.fuelGrade = isEnergy && !isElectric ? fuelGrade : nil
        saved.location = location.isEmpty ? nil : location
        saved.note = note
        saved.source = isNew ? "iOS" : saved.source
        store.upsertRecord(saved)
    }

    private func symbol(for category: String) -> String {
        switch Categories.normalize(category) {
        case "油费": return "fuelpump.fill"
        case "保险": return "shield.fill"
        case "保养": return "wrench.fill"
        case "过路费": return "road.lanes"
        case "停车费": return "parkingsign.circle.fill"
        case "维修": return "hammer.fill"
        case "罚单": return "doc.text.fill"
        case "汽车用品": return "shippingbox.fill"
        case "汽车美容": return "sparkles"
        default: return "circle.fill"
        }
    }
}

struct MNEditorField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(MN.secondary)
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MN.outlineVariant))
        }
    }
}

struct MNCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn ? MN.primary : MN.outline)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(MN.onSurface)
            }
        }
    }
}
