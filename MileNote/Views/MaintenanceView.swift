import SwiftUI

private struct ReminderInfo {
    let status: String
    let detail: String
    let progress: Double
    let color: Color
    let overdue: Bool
}

struct MaintenanceView: View {
    @EnvironmentObject var store: GarageStore
    var onNavigate: (MNPage) -> Void

    @State private var showEditor = false
    @State private var draft = Reminder()

    private var car: Ledger? { store.activeCar }

    private var reminders: [Reminder] {
        (car?.reminders ?? []).sorted { lhs, rhs in
            let l = info(for: lhs).overdue ? 0 : 1
            let r = info(for: rhs).overdue ? 0 : 1
            if l != r { return l < r }
            return (lhs.dueDate ?? "9999") < (rhs.dueDate ?? "9999")
        }
    }

    private var overdueCount: Int { reminders.filter { info(for: $0).overdue }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MNTopBar(title: "保养", actionIcon: "wrench.and.screwdriver") { onNavigate(.serviceHistory) }

                if let car = car {
                    MNCard {
                        MNSectionHeader(
                            title: "待办事项",
                            subtitle: "共 \(car.reminders.count) 项 · \(overdueCount) 项已到期",
                            actionTitle: "添加提醒"
                        ) {
                            draft = Reminder()
                            draft.baseDate = todayString()
                            draft.baseKm = car.vehicle.currentKm
                            showEditor = true
                        }

                        if reminders.isEmpty {
                            MNEmptyState(text: "还没有提醒，点「添加提醒」创建")
                        } else {
                            ForEach(reminders.indices, id: \.self) { index in
                                reminderRow(reminders[index], car: car)
                                if index < reminders.count - 1 { Divider() }
                            }
                        }
                    }

                    MNCard {
                        MNSectionHeader(title: "保养计划", actionTitle: "编辑计划") {
                            onNavigate(.settings)
                        }
                        Text("默认项目：机油机滤、空气滤芯、空调滤芯、冷却液、制动液、洗车")
                            .font(.system(size: 13))
                            .foregroundColor(MN.secondary)
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
        .sheet(isPresented: $showEditor) {
            ReminderEditorView(reminder: draft)
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private func reminderRow(_ reminder: Reminder, car: Ledger) -> some View {
        let info = info(for: reminder)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(reminder.title.isEmpty ? "保养提醒" : reminder.title)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Button {
                    recordService(reminder, car: car)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                        Text("记录保养")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MN.primary)
                }
            }
            HStack(spacing: 5) {
                Circle().fill(info.color).frame(width: 6, height: 6)
                Text(info.status)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(info.color)
            }
            Text(info.detail)
                .font(.system(size: 12))
                .foregroundColor(MN.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "E5E9EB"))
                    Capsule().fill(info.color)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, info.progress))))
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            draft = reminder
            showEditor = true
        }
    }

    private func info(for reminder: Reminder) -> ReminderInfo {
        guard let car = car else {
            return ReminderInfo(status: "计划中", detail: "", progress: 0, color: MN.primary, overdue: false)
        }
        let today = todayString()
        var dueKm = reminder.dueKm
        var dueDate = reminder.dueDate

        if dueKm == nil, let interval = reminder.intervalKm {
            let base = reminder.baseKm ?? car.vehicle.currentKm
            dueKm = base + interval
        }
        if (dueDate == nil || dueDate?.isEmpty == true), let months = reminder.intervalMonths {
            dueDate = addMonths(to: reminder.baseDate ?? today, months: months)
        }

        var overdue = false
        var dueSoon = false
        var status = "计划中"
        var statusColor = MN.primary

        if let km = dueKm {
            let remaining = km - car.vehicle.currentKm
            if remaining <= 0 {
                overdue = true
                status = "已到期 · 超出 \(Int(abs(remaining))) 公里"
                statusColor = MN.danger
            } else if remaining <= 1000 {
                dueSoon = true
                status = "即将到期 · 还有 \(Int(remaining)) 公里"
                statusColor = MN.warning
            }
        }
        if let date = dueDate, !date.isEmpty, let days = daysBetween(today, date) {
            if days <= 0 {
                overdue = true
                status = "已到期"
                statusColor = MN.danger
            } else if days <= 30 {
                if !overdue {
                    dueSoon = true
                    status = "即将到期 · 还有 \(days) 天"
                    statusColor = MN.warning
                }
            }
        }
        if reminder.done {
            overdue = false
            status = "已完成"
            statusColor = MN.success
        }

        var detailParts: [String] = []
        if let date = dueDate, !date.isEmpty {
            detailParts.append("到期 \(displayDots(date))")
        }
        if let km = dueKm {
            detailParts.append("\(Int(km)) 公里")
        }
        if let days = dueDate.flatMap({ daysBetween(today, $0) }), days > 0, !overdue {
            detailParts.append("还有 \(days) 天")
        }

        var progress: Double = 0
        if let km = dueKm, let base = reminder.baseKm, km > base {
            progress = (car.vehicle.currentKm - base) / (km - base)
        } else if let date = dueDate, let baseDate = reminder.baseDate,
                  let total = daysBetween(baseDate, date), total > 0,
                  let elapsed = daysBetween(baseDate, today) {
            progress = Double(elapsed) / Double(total)
        }

        return ReminderInfo(
            status: status,
            detail: detailParts.joined(separator: " · "),
            progress: progress,
            color: statusColor,
            overdue: overdue || dueSoon && !reminder.done
        )
    }

    private func displayDots(_ date: String) -> String {
        guard date.count >= 10 else { return date }
        return date.replacingOccurrences(of: "-", with: ".")
    }

    private func recordService(_ reminder: Reminder, car: Ledger) {
        var record = Record()
        record.date = todayString()
        record.category = "保养"
        record.amount = 0
        record.odometer = car.vehicle.currentKm
        record.note = reminder.title
        record.source = "保养提醒"
        store.upsertRecord(record)
        var updated = reminder
        updated.done = true
        updated.completedDate = todayString()
        updated.completedKm = car.vehicle.currentKm
        updated.recordId = record.id
        store.upsertReminder(updated)
    }
}

struct ServiceHistoryView: View {
    @EnvironmentObject var store: GarageStore

    private var records: [Record] {
        (store.activeCar?.records ?? [])
            .filter { ["保养", "维修"].contains(Categories.normalize($0.category)) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MNDetailTopBar(title: "维修保养记录")
                MNCard {
                    if records.isEmpty {
                        MNEmptyState(text: "暂无保养维修记录")
                    } else {
                        ForEach(records.indices, id: \.self) { index in
                            let record = records[index]
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(Categories.normalize(record.category))
                                        .font(.system(size: 15, weight: .medium))
                                    Text(record.date + (record.note.isEmpty ? "" : " · \(record.note)"))
                                        .font(.system(size: 12))
                                        .foregroundColor(MN.secondary)
                                }
                                Spacer()
                                Text(moneyText(record.amount))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .padding(.vertical, 8)
                            if index < records.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(MN.surface)
    }
}
