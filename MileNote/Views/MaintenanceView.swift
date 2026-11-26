import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var store: GarageStore

    @State private var showEditor = false
    @State private var draft = Reminder()

    private var car: Ledger? { store.activeCar }
    private var theme: String { store.garage.theme }

    private var serviceHistory: [Record] {
        (car?.records ?? [])
            .filter { ["保养", "维修"].contains(Categories.normalize($0.category)) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationView {
            Group {
                if let car = car {
                    ScrollView {
                        VStack(spacing: 16) {
                            SectionCard(title: "保养提醒") {
                                if car.reminders.isEmpty {
                                    EmptyState(text: "还没有提醒，点右上角添加")
                                } else {
                                    ForEach(car.reminders) { reminder in
                                        let state = reminderState(reminder, car: car)
                                        HStack(spacing: 10) {
                                            Image(systemName: state == .done ? "checkmark.circle.fill" : (state == .overdue ? "exclamationmark.triangle.fill" : "clock.circle"))
                                                .foregroundColor(stateColor(state))
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(reminder.title)
                                                    .font(.subheadline.weight(.medium))
                                                Text(detailText(reminder, car: car))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text(state.label)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundColor(stateColor(state))
                                                Button(state == .done ? "重置" : "完成") {
                                                    store.toggleReminder(reminder)
                                                }
                                                .font(.caption)
                                                .buttonStyle(.bordered)
                                            }
                                        }
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            draft = reminder
                                            showEditor = true
                                        }
                                        Divider()
                                    }
                                }
                            }

                            SectionCard(title: "保养 / 维修记录") {
                                if serviceHistory.isEmpty {
                                    EmptyState(text: "暂无保养维修记录")
                                } else {
                                    ForEach(serviceHistory.prefix(12)) { record in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(Categories.normalize(record.category))
                                                    .font(.subheadline)
                                                Text(record.date + (record.note.isEmpty ? "" : " · \(record.note)"))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Text(moneyText(record.amount))
                                                .font(.subheadline.weight(.medium))
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
            .navigationTitle("保养")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        draft = Reminder()
                        draft.baseDate = todayString()
                        draft.baseKm = store.activeCar?.vehicle.currentKm ?? 0
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                ReminderEditorView(reminder: draft)
                    .environmentObject(store)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func stateColor(_ state: ReminderState) -> Color {
        switch state {
        case .done: return .green
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return categoryColor("保养", theme: theme)
        }
    }

    private func detailText(_ reminder: Reminder, car: Ledger) -> String {
        var parts: [String] = []
        if let km = reminder.dueKm {
            parts.append("到期 \(numberText(km)) km")
        } else if let interval = reminder.intervalKm {
            parts.append("每 \(numberText(interval)) km")
        }
        if let date = reminder.dueDate, !date.isEmpty {
            parts.append("到期 \(date)")
        } else if let months = reminder.intervalMonths {
            parts.append("每 \(months) 个月")
        }
        return parts.isEmpty ? "自定义提醒" : parts.joined(separator: " · ")
    }
}

struct ReminderEditorView: View {
    @EnvironmentObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss

    let reminder: Reminder

    @State private var title: String
    @State private var intervalKm: String
    @State private var intervalMonths: String
    @State private var baseDate: Date
    @State private var baseKm: String
    @State private var showDelete = false

    init(reminder: Reminder) {
        self.reminder = reminder
        _title = State(initialValue: reminder.title)
        _intervalKm = State(initialValue: reminder.intervalKm.map { numberText($0) } ?? "")
        _intervalMonths = State(initialValue: reminder.intervalMonths.map { String($0) } ?? "")
        _baseDate = State(initialValue: Self.dateFromString(reminder.baseDate ?? todayString()))
        _baseKm = State(initialValue: reminder.baseKm.map { numberText($0) } ?? "")
    }

    private var isNew: Bool { reminder.id.isEmpty || !containsReminder }

    private var containsReminder: Bool {
        store.activeCar?.reminders.contains { $0.id == reminder.id } ?? false
    }

    var body: some View {
        NavigationView {
            Form {
                Section("提醒事项") {
                    TextField("名称，例如：更换机油", text: $title)
                    TextField("里程周期（km，可空）", text: $intervalKm)
                        .keyboardType(.decimalPad)
                    TextField("时间周期（月，可空）", text: $intervalMonths)
                        .keyboardType(.numberPad)
                }
                Section("本轮基准") {
                    DatePicker("基准日期", selection: $baseDate, displayedComponents: .date)
                    TextField("基准里程（km）", text: $baseKm)
                        .keyboardType(.decimalPad)
                }
                if !isNew {
                    Section {
                        Button(role: .destructive) { showDelete = true } label: {
                            Text("删除提醒")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "新建提醒" : "编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                }
            }
            .alert("确认删除？", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    store.deleteReminder(reminder.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        let km = Double(intervalKm)
        let months = Int(intervalMonths)
        let kmValue = Double(baseKm) ?? 0
        let dateValue = Self.stringFromDate(baseDate)

        var saved = reminder
        if saved.id.isEmpty { saved.id = UUID().uuidString }
        saved.title = title.isEmpty ? "保养提醒" : title
        saved.intervalKm = (km ?? 0) > 0 ? km : nil
        saved.intervalMonths = (months ?? 0) > 0 ? months : nil
        saved.baseKm = kmValue
        saved.baseDate = dateValue
        saved.done = false
        saved.dueKm = (km ?? 0) > 0 ? kmValue + km! : nil
        saved.dueDate = (months ?? 0) > 0 ? addMonths(to: dateValue, months: months!) : nil
        saved.source = "自定义提醒"
        store.upsertReminder(saved)
        dismiss()
    }

    private static func dateFromString(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: text) ?? Date()
    }

    private static func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
