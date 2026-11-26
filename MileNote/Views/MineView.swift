import SwiftUI

struct MineView: View {
    @EnvironmentObject var store: GarageStore
    var onNavigate: (MNPage) -> Void

    private var carsCount: Int { store.garage.cars.count }
    private var recordsCount: Int { store.garage.cars.reduce(0) { $0 + $1.records.count } }
    private var companionDays: Int {
        let dates = store.garage.cars.compactMap { $0.vehicle.companionDate }
        guard let earliest = dates.min() else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: earliest) else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MNTopBar(title: "我的", showVehicle: false)

                MNCard {
                    HStack(alignment: .firstTextBaseline) {
                        Text("数据概览")
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                    }
                    HStack {
                        MineMetric(value: "\(carsCount)", label: "辆车")
                        Spacer()
                        MineMetric(value: "\(recordsCount)", label: "笔记录")
                        Spacer()
                        MineMetric(value: "\(companionDays)", label: "天相伴")
                    }
                    .padding(.top, 8)
                    Divider().padding(.vertical, 12)
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(MN.success)
                        Text("数据保存在本机 · 未接入 WebDAV")
                            .font(.system(size: 12))
                            .foregroundColor(MN.secondary)
                    }
                }

                MineGroup(label: "车辆与偏好") {
                    MineRow(icon: "car.fill", title: "我的车辆") { onNavigate(.garageOverview) }
                    MineRow(icon: "paintpalette.fill", title: "外观") { onNavigate(.settings) }
                    MineRow(icon: "tag.fill", title: "费用分类与项目") { onNavigate(.settings) }
                }

                MineGroup(label: "数据与同步") {
                    MineRow(icon: "doc.text.fill", title: "用车报告") { onNavigate(.report) }
                    MineRow(icon: "heart.text.square.fill", title: "数据体检") { onNavigate(.settings) }
                    MineRow(icon: "square.and.arrow.down.on.square.fill", title: "外部导入") { onNavigate(.settings) }
                    MineRow(icon: "archivebox.fill", title: "备份与还原") { onNavigate(.settings) }
                    MineRow(icon: "cloud.fill", title: "WebDAV 同步") { onNavigate(.webdav) }
                }

                MineGroup(label: "应用") {
                    MineRow(icon: "info.circle.fill", title: "关于") { onNavigate(.settings) }
                }

                Text("里程志 iOS · 未签名构建")
                    .font(.system(size: 11))
                    .foregroundColor(MN.outline)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .background(MN.surface)
    }
}

private struct MineMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(MN.onSurface)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(MN.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MineGroup<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(MN.secondary)
                .padding(.leading, 4)
            MNCard {
                content
            }
        }
    }
}

private struct MineRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(MN.primary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(MN.onSurface)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(MN.outline)
            }
            .padding(.vertical, 10)
        }
    }
}
