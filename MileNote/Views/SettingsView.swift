import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: GarageStore

    @State private var showExport = false
    @State private var showImport = false
    @State private var exportDocument = JSONDocument(data: Data())
    @State private var importMessage = ""
    @State private var showImportAlert = false

    private let themes: [(id: String, name: String, color: Color)] = [
        ("blue", "里程蓝", Color(hex: "55758B")),
        ("forest", "森林绿", Color(hex: "50846C")),
        ("purple", "丁香紫", Color(hex: "8B72B2")),
        ("orange", "暖日橙", Color(hex: "BA7F4C")),
        ("graphite", "石墨灰", Color(hex: "697F8E")),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MNDetailTopBar(title: "设置")

                MNCard {
                    Text("外观")
                        .font(.system(size: 18, weight: .semibold))
                    VStack(spacing: 8) {
                        ForEach(themes, id: \.id) { theme in
                            Button {
                                store.setTheme(theme.id)
                            } label: {
                                HStack {
                                    Circle().fill(theme.color).frame(width: 18, height: 18)
                                    Text(theme.name)
                                        .font(.system(size: 15))
                                        .foregroundColor(MN.onSurface)
                                    Spacer()
                                    if store.garage.theme == theme.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(MN.primary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }

                MNCard {
                    Text("费用分类与项目")
                        .font(.system(size: 18, weight: .semibold))
                    Text(Categories.all.joined(separator: "、"))
                        .font(.system(size: 13))
                        .foregroundColor(MN.secondary)
                        .padding(.top, 6)
                    Text("自定义分类通过导入 garage v2 备份保留。")
                        .font(.system(size: 12))
                        .foregroundColor(MN.outline)
                        .padding(.top, 2)
                }

                MNCard {
                    Text("数据体检")
                        .font(.system(size: 18, weight: .semibold))
                    let records = store.garage.cars.reduce(0) { $0 + $1.records.count }
                    let reminders = store.garage.cars.reduce(0) { $0 + $1.reminders.count }
                    Text("车辆 \(store.garage.cars.count) 辆 · 记录 \(records) 笔 · 提醒 \(reminders) 项")
                        .font(.system(size: 13))
                        .foregroundColor(MN.secondary)
                        .padding(.top, 6)
                }

                MNCard {
                    Text("备份与还原")
                        .font(.system(size: 18, weight: .semibold))
                    HStack(spacing: 12) {
                        Button {
                            exportDocument = JSONDocument(data: Data(store.exportText().utf8))
                            showExport = true
                        } label: {
                            Text("导出 JSON")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(MN.primary)
                                .cornerRadius(20)
                        }
                        Button {
                            showImport = true
                        } label: {
                            Text("导入 JSON")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(MN.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(hex: "EEF2F5"))
                                .cornerRadius(20)
                        }
                    }
                    .padding(.top, 8)
                    Text("备份格式与 Android / Web 版 garage v2 兼容。")
                        .font(.system(size: 12))
                        .foregroundColor(MN.outline)
                        .padding(.top, 4)
                }

                MNCard {
                    Text("关于")
                        .font(.system(size: 18, weight: .semibold))
                    Text("里程志 iOS 移植版 · 未签名构建\n版本 1.0.1 (111)")
                        .font(.system(size: 13))
                        .foregroundColor(MN.secondary)
                        .padding(.top, 6)
                }
            }
            .padding(16)
        }
        .background(MN.surface)
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
}

struct WebDAVSettingsView: View {
    @EnvironmentObject var store: GarageStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MNDetailTopBar(title: "WebDAV 同步")
                MNCard {
                    Text("服务器")
                        .font(.system(size: 18, weight: .semibold))
                    MNEditorField(label: "服务器地址") {
                        TextField("https://dav.example.com/", text: Binding(
                            get: { store.webDAVConfig.baseURL },
                            set: { store.webDAVConfig.baseURL = $0; store.saveWebDAVConfig() }
                        ))
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    }
                    MNEditorField(label: "远程文件名") {
                        TextField("milenote.json", text: Binding(
                            get: { store.webDAVConfig.remotePath },
                            set: { store.webDAVConfig.remotePath = $0; store.saveWebDAVConfig() }
                        ))
                        .autocapitalization(.none)
                    }
                    MNEditorField(label: "用户名") {
                        TextField("用户名", text: Binding(
                            get: { store.webDAVConfig.username },
                            set: { store.webDAVConfig.username = $0; store.saveWebDAVConfig() }
                        ))
                        .autocapitalization(.none)
                    }
                    MNEditorField(label: "密码") {
                        SecureField("密码", text: Binding(
                            get: { store.webDAVConfig.password },
                            set: { store.webDAVConfig.password = $0; store.saveWebDAVConfig() }
                        ))
                    }
                    HStack(spacing: 12) {
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(MN.primary)
                        .cornerRadius(20)

                        Button("下载并导入") {
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MN.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hex: "EEF2F5"))
                        .cornerRadius(20)
                    }
                    if !store.lastMessage.isEmpty {
                        Text(store.lastMessage)
                            .font(.system(size: 12))
                            .foregroundColor(MN.secondary)
                            .padding(.top, 6)
                    }
                }
            }
            .padding(16)
        }
        .background(MN.surface)
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
    @State private var companionDate: String

    init(car: Ledger?, isNew: Bool) {
        self.car = car
        self.isNew = isNew
        _name = State(initialValue: car?.vehicle.name ?? "")
        _plate = State(initialValue: car?.vehicle.plate ?? "")
        _model = State(initialValue: car?.vehicle.model ?? "")
        _currentKm = State(initialValue: car.map { String(format: "%.0f", $0.vehicle.currentKm) } ?? "")
        _startKm = State(initialValue: car?.vehicle.startKm.map { String(format: "%.0f", $0) } ?? "")
        _powertrain = State(initialValue: car?.vehicle.powertrain ?? "fuel")
        _companionDate = State(initialValue: car?.vehicle.companionDate ?? todayString())
    }

    var body: some View {
        VStack(spacing: 0) {
            MNDetailTopBar(title: isNew ? "添加车辆" : "编辑车辆")
            ScrollView {
                VStack(spacing: 12) {
                    MNCard {
                        MNEditorField(label: "昵称") { TextField("例如：周末出逃计划", text: $name) }
                        MNEditorField(label: "车牌") { TextField("粤A·12345", text: $plate) }
                        MNEditorField(label: "品牌 / 车型") { TextField("例如：远峰 T1.4T", text: $model) }
                        MNEditorField(label: "动力类型") {
                            Picker("", selection: $powertrain) {
                                Text("燃油").tag("fuel")
                                Text("纯电").tag("ev")
                                Text("插混").tag("phev")
                            }
                            .pickerStyle(.segmented)
                        }
                        MNEditorField(label: "提车日期") { TextField("yyyy-MM-dd", text: $companionDate) }
                        MNEditorField(label: "起始里程") {
                            TextField("0", text: $startKm).keyboardType(.decimalPad)
                        }
                        MNEditorField(label: "当前里程") {
                            TextField("0", text: $currentKm).keyboardType(.decimalPad)
                        }
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
                Button("保存") { save(); dismiss() }
                    .foregroundColor(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(MN.primary)
                    .cornerRadius(20)
            }
            .padding(12)
            .background(Color.white)
        }
        .background(MN.surface)
    }

    private func save() {
        var vehicle = car?.vehicle ?? Vehicle()
        vehicle.name = name.isEmpty ? "我的爱车" : name
        vehicle.plate = plate
        vehicle.model = model
        vehicle.currentKm = Double(currentKm) ?? 0
        vehicle.startKm = Double(startKm)
        vehicle.powertrain = powertrain
        vehicle.companionDate = companionDate
        if isNew {
            store.addVehicle(vehicle)
        } else if let car = car {
            var updated = car
            updated.vehicle = vehicle
            store.updateVehicle(updated)
        }
    }
}
