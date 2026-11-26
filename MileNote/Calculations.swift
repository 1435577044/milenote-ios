import Foundation

// MARK: - 领域计算（移植自 MileNote domain 模块）

enum Categories {
    static let all = ["油费", "保险", "保养", "过路费", "停车费", "维修", "罚单", "汽车用品", "汽车美容"]

    static let palettes: [String: [String]] = [
        "blue": ["#55758b", "#7e9eaf", "#aec5d0", "#38566c", "#94aab7", "#c1d3dc", "#6d899d", "#dbe5ea", "#b58ac4"],
        "forest": ["#789657", "#b1c78e", "#d1dda9", "#485f4b", "#d9bc91", "#9cae9b", "#c79779", "#e1daca", "#b58ac4"],
        "purple": ["#8a76bd", "#b7a8d4", "#dbd2ec", "#665780", "#b7a1c5", "#c6b9d7", "#9175a8", "#e2dceb", "#b58ac4"],
        "orange": ["#ca8a54", "#ddb289", "#efcfad", "#8e6647", "#d7b59b", "#e4ceba", "#bb8b71", "#eee2d4", "#b58ac4"],
        "graphite": ["#718592", "#9dacb7", "#c4ced5", "#465c6a", "#98a5aa", "#b5c0c5", "#899aa5", "#dce2e5", "#b58ac4"],
    ]

    static func normalize(_ category: String?) -> String {
        guard let category = category, !category.isEmpty else { return "" }
        return category == "维修保养" ? "保养" : category
    }

    static func isEnergy(_ category: String?) -> Bool {
        let name = normalize(category)
        return name == "油费" || name == "充电费"
    }

    static func options(for ledger: Ledger) -> [String] {
        var seen: [String] = []
        for item in all where !seen.contains(item) { seen.append(item) }
        for item in ledger.customCategories ?? [] where !item.isEmpty && !seen.contains(item) { seen.append(item) }
        for record in ledger.records {
            let name = normalize(record.category)
            if !name.isEmpty && !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    static func color(theme: String?, name: String) -> String {
        let palette = palettes[theme ?? ""] ?? palettes["blue"]!
        if let index = all.firstIndex(of: name), index < palette.count {
            return palette[index]
        }
        var hash: UInt32 = 0
        for scalar in name.unicodeScalars {
            hash = hash &* 31 &+ scalar.value
        }
        return "hsl(\(hash % 360) 40% 56%)"
    }
}

enum EnergyKind {
    case fuel
    case electric
}

struct EnergyInterval {
    let date: String
    let distance: Double
    let amount: Double
    let rate: Double
    let source: String
}

/// 满箱法 / 满电法：第一次加满只建立基准；未加满的能源量累计到下次加满；
/// missed 会重新建立基准；里程差 <= 0 的区间不产出。与 Android 实现一致。
func energyIntervals(_ records: [Record], kind: EnergyKind = .fuel) -> [EnergyInterval] {
    let electric = kind == .electric
    func amount(of record: Record) -> Double? { electric ? record.kwh : record.liters }
    let sourceLabel = electric ? "满电法" : "满箱法"

    let sorted = records
        .filter { Categories.isEnergy($0.category) && $0.kind != "manual" && amount(of: $0) != nil }
        .sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return (lhs.odometer ?? 0) < (rhs.odometer ?? 0)
        }

    var anchor: Record?
    var accumulated = 0.0
    var result: [EnergyInterval] = []

    for record in sorted {
        let odometer = record.odometer
        let currentAmount = amount(of: record)
        if record.missed {
            anchor = (record.full && odometer != nil && currentAmount != nil && currentAmount != 0) ? record : nil
            accumulated = 0
            continue
        }
        guard let odo = odometer, let value = currentAmount, value != 0 else {
            anchor = nil
            accumulated = 0
            continue
        }
        if let base = anchor {
            accumulated += value
            if record.full {
                let distance = odo - (base.odometer ?? odo)
                if distance > 0 {
                    result.append(EnergyInterval(
                        date: record.date,
                        distance: distance,
                        amount: accumulated,
                        rate: accumulated / distance * 100,
                        source: sourceLabel
                    ))
                }
                anchor = record
                accumulated = 0
            }
        } else if record.full {
            anchor = record
        }
    }
    return result
}

func manualEnergyIntervals(_ records: [Record]) -> [EnergyInterval] {
    records.compactMap { record in
        guard record.kind == "manual",
              let distance = record.distance, distance > 0,
              let rate = record.rate, rate > 0 else { return nil }
        return EnergyInterval(
            date: record.date,
            distance: distance,
            amount: distance * rate / 100,
            rate: rate,
            source: "手动"
        )
    }
}

struct CategoryTotal: Identifiable {
    var id: String { category }
    let category: String
    let amount: Double
    let count: Int
}

func categoryTotals(_ records: [Record]) -> [CategoryTotal] {
    var values: [String: (amount: Double, count: Int)] = [:]
    for record in records {
        let name = Categories.normalize(record.category)
        let key = name.isEmpty ? "未分类" : name
        let current = values[key] ?? (0, 0)
        values[key] = (current.amount + record.amount, current.count + 1)
    }
    return values
        .map { CategoryTotal(category: $0.key, amount: $0.value.amount, count: $0.value.count) }
        .sorted { $0.amount > $1.amount }
}

struct MonthlyTotal: Identifiable {
    var id: String { month }
    let month: String
    let amount: Double
    let count: Int
}

func monthlyTotals(_ records: [Record], limit: Int = 6) -> [MonthlyTotal] {
    var values: [String: (amount: Double, count: Int)] = [:]
    for record in records where record.date.count >= 7 {
        let month = String(record.date.prefix(7))
        let current = values[month] ?? (0, 0)
        values[month] = (current.amount + record.amount, current.count + 1)
    }
    return values
        .map { MonthlyTotal(month: $0.key, amount: $0.value.amount, count: $0.value.count) }
        .sorted { $0.month < $1.month }
        .suffix(limit)
}

func totalAmount(_ records: [Record]) -> Double {
    records.reduce(0) { $0 + $1.amount }
}

/// 与 Android 版一致：收入/退款不计入支出。
func costOf(_ records: [Record]) -> Double {
    records.filter { $0.kind == "expense" }.reduce(0) { $0 + $1.amount }
}

func averageRate(_ intervals: [EnergyInterval]) -> Double? {
    let totalDistance = intervals.reduce(0) { $0 + $1.distance }
    guard totalDistance > 0 else { return nil }
    let totalAmount = intervals.reduce(0) { $0 + $1.amount }
    return totalAmount / totalDistance * 100
}

// MARK: - 保养提醒状态

enum ReminderState {
    case done
    case overdue
    case dueSoon
    case normal

    var label: String {
        switch self {
        case .done: return "已完成"
        case .overdue: return "已到期"
        case .dueSoon: return "临近到期"
        case .normal: return "正常"
        }
    }
}

func daysBetween(_ from: String, _ to: String) -> Int? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    guard let start = formatter.date(from: from), let end = formatter.date(from: to) else { return nil }
    return Calendar.current.dateComponents([.day], from: start, to: end).day
}

func addMonths(to dateString: String, months: Int) -> String? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    guard let date = formatter.date(from: dateString) else { return nil }
    let result = Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
    return formatter.string(from: result)
}

func reminderState(_ reminder: Reminder, car: Ledger, today: String = todayString()) -> ReminderState {
    if reminder.done { return .done }
    var dueKm = reminder.dueKm
    var dueDate = reminder.dueDate

    if dueKm == nil, let interval = reminder.intervalKm {
        let base = reminder.baseKm ?? car.vehicle.currentKm
        dueKm = base + interval
    }
    if (dueDate == nil || dueDate?.isEmpty == true), let months = reminder.intervalMonths {
        let base = reminder.baseDate ?? today
        dueDate = addMonths(to: base, months: months)
    }

    var overdue = false
    var soon = false
    if let km = dueKm, car.vehicle.currentKm >= km {
        overdue = true
    } else if let km = dueKm, car.vehicle.currentKm >= km - 500 {
        soon = true
    }
    if let date = dueDate, !date.isEmpty, let days = daysBetween(today, date) {
        if days <= 0 { overdue = true }
        else if days <= 30 { soon = true }
    }
    if overdue { return .overdue }
    if soon { return .dueSoon }
    return .normal
}

// MARK: - 格式化

func todayString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: Date())
}

func moneyText(_ value: Double) -> String {
    String(format: "¥%.2f", value)
}

func numberText(_ value: Double, digits: Int = 0) -> String {
    String(format: "%.\(digits)f", value)
}

func shortDate(_ date: String) -> String {
    guard date.count >= 10 else { return date }
    return String(date.dropFirst(5).prefix(5))
}
