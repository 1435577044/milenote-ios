import Foundation

// MARK: - 本地存储 / 备份 / WebDAV

struct WebDAVConfig: Codable {
    var baseURL: String = ""
    var remotePath: String = "milenote.json"
    var username: String = ""
    var password: String = ""
}

enum BackupError: LocalizedError {
    case invalidJSON
    case unsupportedVersion
    case emptyGarage

    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "备份文件不是有效的 JSON"
        case .unsupportedVersion: return "不支持的备份版本（需要 version 1 或 2）"
        case .emptyGarage: return "备份中没有车辆数据"
        }
    }
}

enum WebDAVError: LocalizedError {
    case badURL
    case failed(status: Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "WebDAV 地址无效"
        case .failed(let status): return "WebDAV 请求失败（HTTP \(status)）"
        }
    }
}

struct WebDAVService {
    static func fullURL(_ config: WebDAVConfig) throws -> URL {
        guard !config.baseURL.isEmpty,
              var components = URLComponents(string: config.baseURL) else {
            throw WebDAVError.badURL
        }
        let base = components.path.hasSuffix("/") ? components.path : components.path + "/"
        let path = config.remotePath.isEmpty ? "milenote.json" : config.remotePath
        components.path = base + path
        guard let url = components.url else { throw WebDAVError.badURL }
        return url
    }

    static func authorized(_ request: inout URLRequest, config: WebDAVConfig) {
        guard !config.username.isEmpty else { return }
        let raw = "\(config.username):\(config.password)"
        if let data = raw.data(using: .utf8) {
            request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
    }

    static func upload(_ text: String, config: WebDAVConfig) async throws {
        var request = URLRequest(url: try fullURL(config))
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = text.data(using: .utf8)
        authorized(&request, config: config)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WebDAVError.failed(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    static func download(config: WebDAVConfig) async throws -> String {
        var request = URLRequest(url: try fullURL(config))
        request.httpMethod = "GET"
        authorized(&request, config: config)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WebDAVError.failed(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw BackupError.invalidJSON }
        return text
    }
}

class GarageStore: ObservableObject {
    @Published var garage: Garage
    @Published var webDAVConfig: WebDAVConfig
    @Published var lastMessage: String = ""

    private let encoder: JSONEncoder = JSONEncoder()
    private let decoder: JSONDecoder = JSONDecoder()

    init() {
        let configData = UserDefaults.standard.data(forKey: "milenote.webdav")
        self.webDAVConfig = (try? JSONDecoder().decode(WebDAVConfig.self, from: configData ?? Data())) ?? WebDAVConfig()

        let url = Self.fileURL
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Garage.self, from: data),
           !decoded.cars.isEmpty {
            self.garage = decoded
        } else {
            self.garage = Self.demoGarage()
        }
    }

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("garage.json")
    }

    var activeCar: Ledger? { garage.activeCar }

    func save() {
        guard let data = try? encoder.encode(garage) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    func saveWebDAVConfig() {
        guard let data = try? encoder.encode(webDAVConfig) else { return }
        UserDefaults.standard.set(data, forKey: "milenote.webdav")
    }

    // MARK: 车辆

    func addVehicle(_ vehicle: Vehicle) {
        let ledger = Ledger(vehicle: vehicle)
        garage.cars.append(ledger)
        if garage.activeId.isEmpty { garage.activeId = ledger.id }
        save()
    }

    func updateVehicle(_ car: Ledger) {
        guard let index = garage.cars.firstIndex(where: { $0.id == car.id }) else { return }
        garage.cars[index] = car
        save()
    }

    func deleteVehicle(_ id: String) {
        garage.cars.removeAll { $0.id == id }
        if garage.activeId == id { garage.activeId = garage.cars.first?.id ?? "" }
        garage.vehicleTombstones?.append(Tombstone(id: id, at: Self.nowMillis))
        if garage.vehicleTombstones == nil { garage.vehicleTombstones = [Tombstone(id: id, at: Self.nowMillis)] }
        save()
    }

    func setActiveVehicle(_ id: String) {
        garage.activeId = id
        save()
    }

    func setTheme(_ theme: String) {
        garage.theme = theme
        save()
    }

    // MARK: 记录 / 提醒

    func upsertRecord(_ record: Record, carID: String? = nil) {
        let targetID = carID ?? garage.activeId
        guard let index = garage.cars.firstIndex(where: { $0.id == targetID }) else { return }
        var updated = record
        updated.updatedAt = Self.nowMillis
        if let existing = garage.cars[index].records.firstIndex(where: { $0.id == record.id }) {
            garage.cars[index].records[existing] = updated
        } else {
            garage.cars[index].records.append(updated)
        }
        if Categories.isEnergy(updated.category), let odometer = updated.odometer, odometer > garage.cars[index].vehicle.currentKm {
            garage.cars[index].vehicle.currentKm = odometer
        }
        garage.cars[index].tombstones?.removeAll { $0.id == record.id }
        save()
    }

    func deleteRecord(_ id: String, carID: String? = nil) {
        let targetID = carID ?? garage.activeId
        guard let index = garage.cars.firstIndex(where: { $0.id == targetID }) else { return }
        garage.cars[index].records.removeAll { $0.id == id }
        if garage.cars[index].tombstones == nil { garage.cars[index].tombstones = [] }
        garage.cars[index].tombstones?.append(Tombstone(id: id, at: Self.nowMillis))
        save()
    }

    func upsertReminder(_ reminder: Reminder, carID: String? = nil) {
        let targetID = carID ?? garage.activeId
        guard let index = garage.cars.firstIndex(where: { $0.id == targetID }) else { return }
        var updated = reminder
        updated.updatedAt = Self.nowMillis
        if let existing = garage.cars[index].reminders.firstIndex(where: { $0.id == reminder.id }) {
            garage.cars[index].reminders[existing] = updated
        } else {
            garage.cars[index].reminders.append(updated)
        }
        save()
    }

    func deleteReminder(_ id: String, carID: String? = nil) {
        let targetID = carID ?? garage.activeId
        guard let index = garage.cars.firstIndex(where: { $0.id == targetID }) else { return }
        garage.cars[index].reminders.removeAll { $0.id == id }
        save()
    }

    func toggleReminder(_ reminder: Reminder, carID: String? = nil) {
        var updated = reminder
        updated.done.toggle()
        updated.completedDate = updated.done ? todayString() : nil
        updated.completedKm = updated.done ? (activeCar?.vehicle.currentKm ?? 0) : nil
        upsertReminder(updated, carID: carID)
    }

    // MARK: 备份

    func exportText() -> String {
        (try? encoder.encode(garage)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    func importText(_ text: String) throws {
        let imported = try Self.parseGarage(text)
        for car in imported.cars {
            if let index = garage.cars.firstIndex(where: { $0.id == car.id }) {
                var existing = garage.cars[index]
                let knownIDs = Set(existing.records.map { $0.id })
                for record in car.records where !knownIDs.contains(record.id) {
                    existing.records.append(record)
                }
                let knownReminderIDs = Set(existing.reminders.map { $0.id })
                for reminder in car.reminders where !knownReminderIDs.contains(reminder.id) {
                    existing.reminders.append(reminder)
                }
                existing.records.sort { $0.date < $1.date }
                garage.cars[index] = existing
            } else {
                garage.cars.append(car)
            }
        }
        if garage.cars.isEmpty { throw BackupError.emptyGarage }
        if !garage.cars.contains(where: { $0.id == garage.activeId }) {
            garage.activeId = garage.cars.first?.id ?? ""
        }
        save()
    }

    static func parseGarage(_ text: String) throws -> Garage {
        guard let data = text.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw BackupError.invalidJSON
        }
        let version = (object["version"] as? NSNumber)?.intValue
        let decoder = JSONDecoder()
        if version == 2 {
            return try decoder.decode(Garage.self, from: data)
        }
        if version == 1 {
            let ledger = try decoder.decode(Ledger.self, from: data)
            var garage = Garage()
            garage.cars = [ledger]
            garage.activeId = ledger.id
            return garage
        }
        throw BackupError.unsupportedVersion
    }

    static var nowMillis: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    // MARK: 演示数据

    static func demoGarage() -> Garage {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        func makeCar(name: String, plate: String, model: String, powertrain: String,
                     startKm: Double, currentKm: Double, count: Int, grade: String?) -> Ledger {
            var car = Ledger(vehicle: Vehicle(
                name: name,
                plate: plate,
                model: model,
                startKm: startKm,
                currentKm: currentKm,
                fuelGrade: grade,
                companionDate: "2024-01-01",
                powertrain: powertrain
            ))
            let step = (currentKm - startKm) / Double(max(1, count))
            var records: [Record] = []
            for i in 0..<count {
                guard let date = calendar.date(byAdding: .day, value: -((count - i) * 2), to: now) else { continue }
                var record = Record()
                record.date = formatter.string(from: date)
                record.odometer = startKm + step * Double(i + 1)
                record.source = "演示数据"

                let roll = i % 10
                if powertrain == "ev" {
                    record.category = roll < 6 ? "充电费" : (roll == 6 ? "停车费" : (roll == 7 ? "保险" : (roll == 8 ? "保养" : "过路费")))
                } else if powertrain == "phev" {
                    record.category = roll < 4 ? "油费" : (roll < 7 ? "充电费" : (roll == 7 ? "停车费" : "过路费"))
                } else {
                    record.category = roll < 6 ? "油费" : (roll == 6 ? "停车费" : (roll == 7 ? "保险" : (roll == 8 ? "保养" : "过路费")))
                }

                switch Categories.normalize(record.category) {
                case "油费":
                    record.amount = 280 + Double(i % 7) * 18
                    record.liters = record.amount / 7.6
                    record.unitPrice = 7.6
                    record.full = i % 4 == 0
                    record.fuelGrade = grade
                    record.location = "示例加油站"
                case "充电费":
                    record.amount = 60 + Double(i % 5) * 12
                    record.kwh = record.amount / 1.25
                    record.unitPrice = 1.25
                    record.full = i % 5 == 0
                    record.location = "示例充电站"
                case "保险":
                    record.amount = 3200
                case "保养":
                    record.amount = 460
                case "停车费":
                    record.amount = 35 + Double(i % 4) * 10
                default:
                    record.amount = 90 + Double(i % 5) * 15
                }
                if i % 13 == 0 { record.note = "演示数据" }
                records.append(record)
            }
            car.records = records

            let reminderTitles = ["空调滤芯", "洗车", "冷却液", "制动液", "机油机滤"]
            for (index, title) in reminderTitles.enumerated() {
                var reminder = Reminder()
                reminder.title = title
                reminder.baseDate = formatter.string(from: calendar.date(byAdding: .month, value: -6 - index, to: now) ?? now)
                reminder.baseKm = max(0, currentKm - Double(4000 + index * 1500))
                reminder.intervalKm = 10000
                reminder.intervalMonths = 12
                reminder.projects = [title]
                reminder.source = "默认保养方案"
                car.reminders.append(reminder)
            }
            return car
        }

        let cars = [
            makeCar(name: "周末出逃计划", plate: "A号车", model: "远峰 · T1.4T", powertrain: "fuel",
                    startKm: 12000, currentKm: 24659, count: 132, grade: "95#"),
            makeCar(name: "插混通勤", plate: "B号车", model: "插混 · 增程", powertrain: "phev",
                    startKm: 11000, currentKm: 23538, count: 155, grade: "92#"),
            makeCar(name: "城市通勤", plate: "C号车", model: "纯电 · 长续航", powertrain: "ev",
                    startKm: 10000, currentKm: 20176, count: 154, grade: nil),
        ]
        var garage = Garage()
        garage.cars = cars
        garage.activeId = cars.first?.id ?? ""
        return garage
    }

}
