import SwiftUI

enum MNPage: Identifiable {
    case records
    case fuelDetail
    case serviceHistory
    case report
    case garageOverview
    case settings
    case webdav

    var id: String {
        switch self {
        case .records: return "records"
        case .fuelDetail: return "fuelDetail"
        case .serviceHistory: return "serviceHistory"
        case .report: return "report"
        case .garageOverview: return "garageOverview"
        case .settings: return "settings"
        case .webdav: return "webdav"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: GarageStore
    @State private var selection = 0
    @State private var pushed: MNPage? = nil
    @State private var showEditor = false
    @State private var showVehicleSwitcher = false

    private var energyTabTitle: String {
        (store.activeCar?.vehicle.usesEnergyUI ?? false) ? "能耗" : "油耗"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MN.surface.ignoresSafeArea()

            Group {
                switch selection {
                case 0: DashboardView(onNavigate: { pushed = $0 })
                case 1: FuelView(onNavigate: { pushed = $0 })
                case 2: MaintenanceView(onNavigate: { pushed = $0 })
                default: MineView(onNavigate: { pushed = $0 })
                }
            }
            .padding(.bottom, 76)

            bottomBar
        }
        .sheet(isPresented: $showVehicleSwitcher) {
            VehicleSwitcherView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showEditor) {
            RecordEditorView(record: Record(), isNew: true)
                .environmentObject(store)
        }
        .fullScreenCover(item: $pushed) { page in
            pushedView(page)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mnShowVehicleSwitcher)) { _ in
            showVehicleSwitcher = true
        }
    }

    @ViewBuilder
    private func pushedView(_ page: MNPage) -> some View {
        switch page {
        case .records: RecordsView()
        case .fuelDetail: FuelDetailView()
        case .serviceHistory: ServiceHistoryView()
        case .report: ReportView()
        case .garageOverview: GarageOverviewView()
        case .settings: SettingsView()
        case .webdav: WebDAVSettingsView()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(MN.outlineVariant.opacity(0.55))
                .frame(height: 0.5)
            HStack(spacing: 0) {
                tabItem(index: 0, title: "总览", icon: "house", filled: "house.fill")
                tabItem(index: 1, title: energyTabTitle, icon: "fuelpump", filled: "fuelpump.fill")

                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 40)
                        .background(MN.primary)
                        .cornerRadius(14)
                }
                .frame(maxWidth: .infinity)

                tabItem(index: 2, title: "保养", icon: "wrench", filled: "wrench.fill")
                tabItem(index: 3, title: "我的", icon: "person", filled: "person.fill")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white)
        }
        .frame(height: 76)
    }

    @ViewBuilder
    private func tabItem(index: Int, title: String, icon: String, filled: String) -> some View {
        Button {
            selection = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == index ? filled : icon)
                    .font(.system(size: 22))
                    .foregroundColor(selection == index ? MN.onSurface : MN.secondary)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(selection == index ? MN.onSurface : MN.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
    }
}

// MARK: - 四个主 Tab 通用顶栏

struct MNTopBar: View {
    @EnvironmentObject var store: GarageStore
    let title: String
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil
    var showVehicle: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(MN.onSurface)
            Spacer(minLength: 4)
            if showVehicle, let vehicle = store.activeCar?.vehicle {
                Button {
                    NotificationCenter.default.post(name: .mnShowVehicleSwitcher, object: nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: vehicle.isElectric ? "bolt.car.fill" : "fuelpump.fill")
                        Text(vehicle.name.isEmpty ? "未命名车辆" : vehicle.name)
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MN.onSurface)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(MN.outlineVariant, lineWidth: 0.8)
                    )
                }
            }
            if let actionIcon = actionIcon, let action = action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 20))
                        .foregroundColor(MN.onSurface)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(MN.surface)
    }
}

extension Notification.Name {
    static let mnShowVehicleSwitcher = Notification.Name("mnShowVehicleSwitcher")
}

struct VehicleSwitcherView: View {
    @EnvironmentObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("切换车辆")
                .font(.system(size: 24, weight: .semibold))
            ForEach(store.garage.cars) { car in
                Button {
                    store.setActiveVehicle(car.id)
                    dismiss()
                } label: {
                    HStack {
                        Text((car.id == store.garage.activeId ? "✓ " : "") + (car.vehicle.name.isEmpty ? "未命名车辆" : car.vehicle.name))
                        Spacer()
                        Text("\(car.records.count) 条记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - 推入页通用顶栏

struct MNDetailTopBar: View {
    let title: String
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .foregroundColor(MN.onSurface)
                    .frame(width: 36, height: 36)
            }
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(MN.onSurface)
            Spacer()
            if let actionIcon = actionIcon, let action = action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 20))
                        .foregroundColor(MN.onSurface)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(MN.surface)
    }
}
