import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: GarageStore

    @State private var showCarEditor = false
    @State private var carEditorIsNew = false
    @State private var editingCar: Ledger? = nil

    @State private var showExport = false
    @State private var showImport = false
    @State private var exportDocument = JSONDocument(data: Data())
    @State private var showImportAlert = false
    @State private var importMessage = ""

    private var themeNames: [(id: String, name: String)] {
        [("blue", "里程蓝"), ("forest", "森林绿"), ("purple", "丁香紫"), ("orange", "暖日橙"), ("graphite", "石墨灰")]
    }

    var body: some View {
        NavigationView {
            Form {
                Section("车库") {
                    ForEach(store.garage.cars) { car in
                        HStack(spacing: 10) {
                            Image(systemName: "car.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(car.vehicle.name.isEmpty ? "未命名车辆" : car.vehicle.name)
                                    .font(.subheadline.weight(.medium))
                                Text(car.vehicle.plate.isEmpty ? (numberText(car.vehicle.currentKm) + " km") : "\(car.vehicle.plate) · \(numberText(car.vehicle.currentKm)) km")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if car.id == store.garage.activeId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingCar = car
                            carEditorIsNew = false
                            showCarEditor = true
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteVehicle(car.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    Button {
                        editingCar = nil
                        carEditorIsNew = true
                        showCarEditor = true
                    } label: {
                        Label("添加车辆", systemImage: "plus.circle")
                    }
                }

                Section("外观") {
                    Picker("主题", selection: Binding(
                        get: { store.garage.theme },
                        set: { store.setTheme($0) }
                    )) {
                        ForEach(themeNames, id: \.id) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                }

                Section("备份与同步") {
                    Button {
                        exportDocument = JSONDocument(data: Data(store.exportText().utf8))
                        showExport = true
                    } label: {
                        Label("导出 JSON 备份", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImport = true
                    } label: {
                        Label("导入 JSON 备份", systemImage: "square.and.arrow.down")
                    }
                    NavigationLink {
                        WebDAVSettingsView()
                    } label: {
                        Label("WebDAV 同步", systemImage: "cloud")
                    }
                }

                Section("关于") {
                    Text("里程志 iOS 移植版 · 未签名构建")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("数据默认保存在本机，备份 JSON 与 Android / Web 版兼容。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showCarEditor) {
                CarEditorView(car: editingCar, isNew: carEditorIsNew)
                    .environmentObject(store)
            }
            .fileExporter(
                isPresented: $showExport,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "milenote-garage.json"
            ) { _ in }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let accesses = url.startAccessingSecurityScopedResource()
                    defer { if accesses { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        guard let text = String(data: data, encoding: .utf8) else { throw BackupError.invalidJSON }
                        try store.importText(text)
                        importMessage = "备份导入成功"
                    } catch {
                        importMessage = error.localizedDescription
                    }
                    showImportAlert = true
                case .failure(let error):
                    importMessage = error.localizedDescription
                    showImportAlert = true
                }
            }
            .alert("导入结果", isPresented: $showImportAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(importMessage)
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct WebDAVSettingsView: View {
    @EnvironmentObject var store: GarageStore

    var body: some View {
        Form {
            Section("服务器") {
                TextField("服务器地址，例如 https://dav.example.com/", text: Binding(
                    get: { store.webDAVConfig.baseURL },
                    set: { store.webDAVConfig.baseURL = $0; store.saveWebDAVConfig() }
                ))
                .keyboardType(.URL)
                .autocapitalization(.none)
                .textContentType(.URL)
                TextField("远程文件名", text: Binding(
                    get: { store.webDAVConfig.remotePath },
                    set: { store.webDAVConfig.remotePath = $0; store.saveWebDAVConfig() }
                ))
                .autocapitalization(.none)
            }
            Section("认证") {
                TextField("用户名", text: Binding(
                    get: { store.webDAVConfig.username },
                    set: { store.webDAVConfig.username = $0; store.saveWebDAVConfig() }
                ))
                .autocapitalization(.none)
                SecureField("密码", text: Binding(
                    get: { store.webDAVConfig.password },
                    set: { store.webDAVConfig.password = $0; store.saveWebDAVConfig() }
                ))
            }
            Section("操作") {
                Button("上传当前备份") {
                    Task {
                        do {
                            try await WebDAVService.upload(store.exportText(), config: store.webDAVConfig)
                            await MainActor.run { store.lastMessage = "上传成功" }
                        } catch {
                            await MainActor.run { store.lastMessage = error.localizedDescription }
                        }
                    }
                }
                Button("从服务器下载并导入") {
                    Task {
                        do {
                            let text = try await WebDAVService.download(config: store.webDAVConfig)
                            try store.importText(text)
                            await MainActor.run { store.lastMessage = "下载并导入成功" }
                        } catch {
                            await MainActor.run { store.lastMessage = error.localizedDescription }
                        }
                    }
                }
                if !store.lastMessage.isEmpty {
                    Text(store.lastMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("WebDAV 同步")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CarEditorView: View {
    @EnvironmentObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss

    let car: Ledger?
    let isNew: Bool

    @State private var name: String
    @State private var plate: String
    @State private var model: String
    @State private var currentKm: String
    @State private var startKm: String
    @State private var powertrain: String
    @State private var companionDate: Date
    @State private var showDelete = false

    init(car: Ledger?, isNew: Bool) {
        self.car = car
        self.isNew = isNew
        _name = State(initialValue: car?.vehicle.name ?? "")
        _plate = State(initialValue: car?.vehicle.plate ?? "")
        _model = State(initialValue: car?.vehicle.model ?? "")
        _currentKm = State(initialValue: car.map { numberText($0.vehicle.currentKm) } ?? "")
        _startKm = State(initialValue: car?.vehicle.startKm.map { numberText($0) } ?? "")
        _powertrain = State(initialValue: car?.vehicle.powertrain ?? "fuel")
        _companionDate = State(initialValue: Self.dateFromString(car?.vehicle.companionDate ?? todayString()))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("车辆信息") {
                    TextField("昵称", text: $name)
                    TextField("车牌", text: $plate)
                    TextField("品牌 / 车型", text: $model)
                    Picker("动力类型", selection: $powertrain) {
                        Text("燃油").tag("fuel")
                        Text("纯电").tag("ev")
                    }
                    DatePicker("提车日期", selection: $companionDate, displayedComponents: .date)
                }
                Section("里程") {
                    TextField("起始里程（km）", text: $startKm)
                        .keyboardType(.decimalPad)
                    TextField("当前里程（km）", text: $currentKm)
                        .keyboardType(.decimalPad)
                }
                if !isNew, let car = car {
                    Section {
                        Button("设为当前车辆") {
                            store.setActiveVehicle(car.id)
                            dismiss()
                        }
                        Button(role: .destructive) { showDelete = true } label: {
                            Text("删除这辆车")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "添加车辆" : "编辑车辆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                }
            }
            .alert("确认删除这辆车及全部记录？", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    if let car = car { store.deleteVehicle(car.id) }
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        var vehicle = car?.vehicle ?? Vehicle()
        vehicle.name = name.isEmpty ? "我的爱车" : name
        vehicle.plate = plate
        vehicle.model = model
        vehicle.currentKm = Double(currentKm) ?? 0
        vehicle.startKm = Double(startKm)
        vehicle.powertrain = powertrain
        vehicle.companionDate = Self.stringFromDate(companionDate)

        if isNew {
            store.addVehicle(vehicle)
        } else if let car = car {
            var updated = car
            updated.vehicle = vehicle
            store.updateVehicle(updated)
        }
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
