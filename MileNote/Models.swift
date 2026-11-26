import Foundation

// MARK: - 备份数据模型
// 字段与 MileNote Android / Web 的 garage v2 JSON 保持一致。
// 自定义 Codable 实现用于「省略 nil」，对应 Kotlin 序列化配置的 explicitNulls = false。

struct Tombstone: Codable, Identifiable {
    var id: String = ""
    var at: Int64 = 0
}

struct Garage: Codable {
    var version: Int = 2
    var activeId: String = ""
    var theme: String = "blue"
    var cars: [Ledger] = []
    var vehicleTombstones: [Tombstone]?

    enum CodingKeys: String, CodingKey {
        case version, activeId, theme, cars, vehicleTombstones
    }

    init(version: Int = 2,
         activeId: String = "",
         theme: String = "blue",
         cars: [Ledger] = [],
         vehicleTombstones: [Tombstone]? = nil) {
        self.version = version
        self.activeId = activeId
        self.theme = theme
        self.cars = cars
        self.vehicleTombstones = vehicleTombstones
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 2
        activeId = try c.decodeIfPresent(String.self, forKey: .activeId) ?? ""
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? "blue"
        cars = try c.decodeIfPresent([Ledger].self, forKey: .cars) ?? []
        vehicleTombstones = try c.decodeIfPresent([Tombstone].self, forKey: .vehicleTombstones)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(activeId, forKey: .activeId)
        try c.encode(theme, forKey: .theme)
        try c.encode(cars, forKey: .cars)
        try c.encodeIfPresent(vehicleTombstones, forKey: .vehicleTombstones)
    }

    var activeCar: Ledger? {
        cars.first { $0.id == activeId } ?? cars.first
    }
}

struct Ledger: Codable, Identifiable {
    var version: Int = 1
    var id: String = UUID().uuidString
    var vehicle: Vehicle = Vehicle()
    var records: [Record] = []
    var reminders: [Reminder] = []
    var customCategories: [String]?
    var servicePlan: [PlanEntry]?
    var servicePlanBase: PlanBase?
    var servicePlanConfigured: Bool?
    var serviceProjects: [String]?
    var serviceProjectsByCategory: [String: [String]]?
    var hiddenCategories: [String]?
    var categoryLabels: [String: String]?
    var hiddenServiceProjects: [String: [String]]?
    var serviceProjectLabels: [String: String]?
    var tombstones: [Tombstone]?
    var restoredAt: Int64?
    var ignoredHealthIssues: [String]?

    enum CodingKeys: String, CodingKey {
        case version, id, vehicle, records, reminders, customCategories, servicePlan
        case servicePlanBase, servicePlanConfigured, serviceProjects, serviceProjectsByCategory
        case hiddenCategories, categoryLabels, hiddenServiceProjects, serviceProjectLabels
        case tombstones, restoredAt, ignoredHealthIssues
    }

    init(id: String = UUID().uuidString, vehicle: Vehicle = Vehicle()) {
        self.id = id
        self.vehicle = vehicle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        vehicle = try c.decodeIfPresent(Vehicle.self, forKey: .vehicle) ?? Vehicle()
        records = try c.decodeIfPresent([Record].self, forKey: .records) ?? []
        reminders = try c.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
        customCategories = try c.decodeIfPresent([String].self, forKey: .customCategories)
        servicePlan = try c.decodeIfPresent([PlanEntry].self, forKey: .servicePlan)
        servicePlanBase = try c.decodeIfPresent(PlanBase.self, forKey: .servicePlanBase)
        servicePlanConfigured = try c.decodeIfPresent(Bool.self, forKey: .servicePlanConfigured)
        serviceProjects = try c.decodeIfPresent([String].self, forKey: .serviceProjects)
        serviceProjectsByCategory = try c.decodeIfPresent([String: [String]].self, forKey: .serviceProjectsByCategory)
        hiddenCategories = try c.decodeIfPresent([String].self, forKey: .hiddenCategories)
        categoryLabels = try c.decodeIfPresent([String: String].self, forKey: .categoryLabels)
        hiddenServiceProjects = try c.decodeIfPresent([String: [String]].self, forKey: .hiddenServiceProjects)
        serviceProjectLabels = try c.decodeIfPresent([String: String].self, forKey: .serviceProjectLabels)
        tombstones = try c.decodeIfPresent([Tombstone].self, forKey: .tombstones)
        restoredAt = try c.decodeIfPresent(Int64.self, forKey: .restoredAt)
        ignoredHealthIssues = try c.decodeIfPresent([String].self, forKey: .ignoredHealthIssues)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(id, forKey: .id)
        try c.encode(vehicle, forKey: .vehicle)
        try c.encode(records, forKey: .records)
        try c.encode(reminders, forKey: .reminders)
        try c.encodeIfPresent(customCategories, forKey: .customCategories)
        try c.encodeIfPresent(servicePlan, forKey: .servicePlan)
        try c.encodeIfPresent(servicePlanBase, forKey: .servicePlanBase)
        try c.encodeIfPresent(servicePlanConfigured, forKey: .servicePlanConfigured)
        try c.encodeIfPresent(serviceProjects, forKey: .serviceProjects)
        try c.encodeIfPresent(serviceProjectsByCategory, forKey: .serviceProjectsByCategory)
        try c.encodeIfPresent(hiddenCategories, forKey: .hiddenCategories)
        try c.encodeIfPresent(categoryLabels, forKey: .categoryLabels)
        try c.encodeIfPresent(hiddenServiceProjects, forKey: .hiddenServiceProjects)
        try c.encodeIfPresent(serviceProjectLabels, forKey: .serviceProjectLabels)
        try c.encodeIfPresent(tombstones, forKey: .tombstones)
        try c.encodeIfPresent(restoredAt, forKey: .restoredAt)
        try c.encodeIfPresent(ignoredHealthIssues, forKey: .ignoredHealthIssues)
    }
}

struct Vehicle: Codable {
    var name: String = ""
    var plate: String = ""
    var model: String = ""
    var startKm: Double?
    var currentKm: Double = 0
    var fuelCostSource: String?
    var fuelGrade: String?
    var companionDate: String?
    var image: String?
    var imageFit: String?
    var powertrain: String?

    enum CodingKeys: String, CodingKey {
        case name, plate, model, startKm, currentKm, fuelCostSource
        case fuelGrade, companionDate, image, imageFit, powertrain
    }

    init() {}

    init(name: String = "",
         plate: String = "",
         model: String = "",
         startKm: Double? = nil,
         currentKm: Double = 0,
         fuelCostSource: String? = nil,
         fuelGrade: String? = nil,
         companionDate: String? = nil,
         image: String? = nil,
         imageFit: String? = nil,
         powertrain: String? = nil) {
        self.name = name
        self.plate = plate
        self.model = model
        self.startKm = startKm
        self.currentKm = currentKm
        self.fuelCostSource = fuelCostSource
        self.fuelGrade = fuelGrade
        self.companionDate = companionDate
        self.image = image
        self.imageFit = imageFit
        self.powertrain = powertrain
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        plate = try c.decodeIfPresent(String.self, forKey: .plate) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        startKm = try c.decodeIfPresent(Double.self, forKey: .startKm)
        currentKm = try c.decodeIfPresent(Double.self, forKey: .currentKm) ?? 0
        fuelCostSource = try c.decodeIfPresent(String.self, forKey: .fuelCostSource)
        fuelGrade = try c.decodeIfPresent(String.self, forKey: .fuelGrade)
        companionDate = try c.decodeIfPresent(String.self, forKey: .companionDate)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        imageFit = try c.decodeIfPresent(String.self, forKey: .imageFit)
        powertrain = try c.decodeIfPresent(String.self, forKey: .powertrain)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(plate, forKey: .plate)
        try c.encode(model, forKey: .model)
        try c.encodeIfPresent(startKm, forKey: .startKm)
        try c.encode(currentKm, forKey: .currentKm)
        try c.encodeIfPresent(fuelCostSource, forKey: .fuelCostSource)
        try c.encodeIfPresent(fuelGrade, forKey: .fuelGrade)
        try c.encodeIfPresent(companionDate, forKey: .companionDate)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(imageFit, forKey: .imageFit)
        try c.encodeIfPresent(powertrain, forKey: .powertrain)
    }

    var isElectric: Bool { powertrain == "ev" }
    var isPhev: Bool { powertrain == "phev" }
    var usesEnergyUI: Bool { isElectric || isPhev }
}

struct Record: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = ""
    var category: String = ""
    var amount: Double = 0
    var odometer: Double?
    var liters: Double?
    var kwh: Double?
    var unitPrice: Double?
    var payable: Double?
    var discount: Double?
    var rate: Double?
    var reportedRate: Double?
    var distance: Double?
    var full: Bool = false
    var missed: Bool = false
    var note: String = ""
    var location: String?
    var projects: String?
    var source: String = ""
    var sourceId: String?
    var kind: String = "expense"
    var fuelCounted: Bool?
    var importedKeys: [String]?
    var currency: String?
    var time: String?
    var fuelGrade: String?
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, date, category, amount, odometer, liters, kwh, unitPrice, payable, discount
        case rate, reportedRate, distance, full, missed, note, location, projects, source
        case sourceId, kind, fuelCounted, importedKeys, currency, time, fuelGrade, updatedAt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        odometer = try c.decodeIfPresent(Double.self, forKey: .odometer)
        liters = try c.decodeIfPresent(Double.self, forKey: .liters)
        kwh = try c.decodeIfPresent(Double.self, forKey: .kwh)
        unitPrice = try c.decodeIfPresent(Double.self, forKey: .unitPrice)
        payable = try c.decodeIfPresent(Double.self, forKey: .payable)
        discount = try c.decodeIfPresent(Double.self, forKey: .discount)
        rate = try c.decodeIfPresent(Double.self, forKey: .rate)
        reportedRate = try c.decodeIfPresent(Double.self, forKey: .reportedRate)
        distance = try c.decodeIfPresent(Double.self, forKey: .distance)
        full = try c.decodeIfPresent(Bool.self, forKey: .full) ?? false
        missed = try c.decodeIfPresent(Bool.self, forKey: .missed) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        location = try c.decodeIfPresent(String.self, forKey: .location)
        projects = try c.decodeIfPresent(String.self, forKey: .projects)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        sourceId = try c.decodeIfPresent(String.self, forKey: .sourceId)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "expense"
        fuelCounted = try c.decodeIfPresent(Bool.self, forKey: .fuelCounted)
        importedKeys = try c.decodeIfPresent([String].self, forKey: .importedKeys)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        time = try c.decodeIfPresent(String.self, forKey: .time)
        fuelGrade = try c.decodeIfPresent(String.self, forKey: .fuelGrade)
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(category, forKey: .category)
        try c.encode(amount, forKey: .amount)
        try c.encodeIfPresent(odometer, forKey: .odometer)
        try c.encodeIfPresent(liters, forKey: .liters)
        try c.encodeIfPresent(kwh, forKey: .kwh)
        try c.encodeIfPresent(unitPrice, forKey: .unitPrice)
        try c.encodeIfPresent(payable, forKey: .payable)
        try c.encodeIfPresent(discount, forKey: .discount)
        try c.encodeIfPresent(rate, forKey: .rate)
        try c.encodeIfPresent(reportedRate, forKey: .reportedRate)
        try c.encodeIfPresent(distance, forKey: .distance)
        try c.encode(full, forKey: .full)
        try c.encode(missed, forKey: .missed)
        try c.encode(note, forKey: .note)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(projects, forKey: .projects)
        try c.encode(source, forKey: .source)
        try c.encodeIfPresent(sourceId, forKey: .sourceId)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(fuelCounted, forKey: .fuelCounted)
        try c.encodeIfPresent(importedKeys, forKey: .importedKeys)
        try c.encodeIfPresent(currency, forKey: .currency)
        try c.encodeIfPresent(time, forKey: .time)
        try c.encodeIfPresent(fuelGrade, forKey: .fuelGrade)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct Reminder: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var presetKey: String?
    var projects: [String]?
    var firstOnly: Bool?
    var intervalKm: Double?
    var intervalMonths: Int?
    var dueDate: String?
    var dueKm: Double?
    var baseDate: String?
    var baseKm: Double?
    var done: Bool = false
    var completedDate: String?
    var completedKm: Double?
    var recordId: String?
    var historyGenerated: Bool?
    var historyBaseline: HistoryBaseline?
    var historyRecordId: String?
    var source: String?
    var note: String?
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, title, presetKey, projects, firstOnly, intervalKm, intervalMonths, dueDate
        case dueKm, baseDate, baseKm, done, completedDate, completedKm, recordId
        case historyGenerated, historyBaseline, historyRecordId, source, note, updatedAt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        presetKey = try c.decodeIfPresent(String.self, forKey: .presetKey)
        projects = try c.decodeIfPresent([String].self, forKey: .projects)
        firstOnly = try c.decodeIfPresent(Bool.self, forKey: .firstOnly)
        intervalKm = try c.decodeIfPresent(Double.self, forKey: .intervalKm)
        intervalMonths = try c.decodeIfPresent(Int.self, forKey: .intervalMonths)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        dueKm = try c.decodeIfPresent(Double.self, forKey: .dueKm)
        baseDate = try c.decodeIfPresent(String.self, forKey: .baseDate)
        baseKm = try c.decodeIfPresent(Double.self, forKey: .baseKm)
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        completedDate = try c.decodeIfPresent(String.self, forKey: .completedDate)
        completedKm = try c.decodeIfPresent(Double.self, forKey: .completedKm)
        recordId = try c.decodeIfPresent(String.self, forKey: .recordId)
        historyGenerated = try c.decodeIfPresent(Bool.self, forKey: .historyGenerated)
        historyBaseline = try c.decodeIfPresent(HistoryBaseline.self, forKey: .historyBaseline)
        historyRecordId = try c.decodeIfPresent(String.self, forKey: .historyRecordId)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(presetKey, forKey: .presetKey)
        try c.encodeIfPresent(projects, forKey: .projects)
        try c.encodeIfPresent(firstOnly, forKey: .firstOnly)
        try c.encodeIfPresent(intervalKm, forKey: .intervalKm)
        try c.encodeIfPresent(intervalMonths, forKey: .intervalMonths)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(dueKm, forKey: .dueKm)
        try c.encodeIfPresent(baseDate, forKey: .baseDate)
        try c.encodeIfPresent(baseKm, forKey: .baseKm)
        try c.encode(done, forKey: .done)
        try c.encodeIfPresent(completedDate, forKey: .completedDate)
        try c.encodeIfPresent(completedKm, forKey: .completedKm)
        try c.encodeIfPresent(recordId, forKey: .recordId)
        try c.encodeIfPresent(historyGenerated, forKey: .historyGenerated)
        try c.encodeIfPresent(historyBaseline, forKey: .historyBaseline)
        try c.encodeIfPresent(historyRecordId, forKey: .historyRecordId)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct HistoryBaseline: Codable {
    var baseDate: String?
    var baseKm: Double?
    var dueDate: String?
    var dueKm: Double?
}

struct PlanEntry: Codable {
    var key: String = ""
    var title: String?
    var intervalKm: Double?
    var intervalMonths: Int?
    var firstOnly: Bool?
    var projects: [String]?
}

struct PlanBase: Codable {
    var date: String?
    var km: Double?
    var includeFirst: Bool?
}
