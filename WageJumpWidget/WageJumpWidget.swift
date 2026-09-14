import WidgetKit
import SwiftUI

struct WageJumpEntry: TimelineEntry {
    let date: Date
    let snapshot: IncomeSnapshot
    let currencyCode: String
    let dailyWorkMinutes: Int
    let workEndMinutes: Int
    let workingWeekdays: Set<Int>
    let configLoaded: Bool
}

private enum WidgetConfigLoader {
    private static let store = SalaryConfigStore()

    static func loadConfig() -> (config: SalaryConfig, loaded: Bool) {
        if let state = SharedWidgetStateStore.load(),
           state.updatedAt > .distantPast {
            if let config = state.config {
                return (config, true)
            }
            if state.monthlySalary > 0 {
                var config = store.load()
                config.monthlySalary = state.monthlySalary
                if !state.currencyCode.isEmpty {
                    config.currencyCode = state.currencyCode
                }
                if state.workEndMinutes > 0 {
                    config.workEndMinutes = state.workEndMinutes
                }
                if !state.workingWeekdays.isEmpty {
                    config.workingWeekdays = Set(state.workingWeekdays)
                }
                return (config, true)
            }
        }

        let config = store.load()
        return (config, config.monthlySalary > 0)
    }
}

struct WageJumpProvider: TimelineProvider {
    private let calculator = SalaryCalculator()

    func placeholder(in context: Context) -> WageJumpEntry {
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WageJumpEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WageJumpEntry>) -> Void) {
        let now = Date()
        let loaded = WidgetConfigLoader.loadConfig()
        let config = loaded.config
        let entries = makeEntries(from: now, config: config, loaded: loaded.loaded)

        // 在最后一条之前请求下一段 timeline，避免空窗
        let reloadDate = entries.dropLast().last?.date
            ?? now.addingTimeInterval(5 * 60)
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }

    private func entry(at date: Date) -> WageJumpEntry {
        let loaded = WidgetConfigLoader.loadConfig()
        return makeEntry(at: date, config: loaded.config, loaded: loaded.loaded)
    }

    private func makeEntry(at date: Date, config: SalaryConfig, loaded: Bool) -> WageJumpEntry {
        WageJumpEntry(
            date: date,
            snapshot: calculator.snapshot(config: config, now: date),
            currencyCode: config.currencyCode,
            dailyWorkMinutes: max(config.dailyWorkMinutes, 1),
            workEndMinutes: config.workEndMinutes,
            workingWeekdays: config.workingWeekdays,
            configLoaded: loaded
        )
    }

    /// 工作时段每 30 秒一条（约 30 分钟），下班后每 15 分钟。
    /// 条目不宜过多，否则 macOS WidgetKit 会直接丢弃 timeline。
    private func makeEntries(from now: Date, config: SalaryConfig, loaded: Bool) -> [WageJumpEntry] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let isWorkingDay = config.workingWeekdays.contains(weekday)
        let dayStart = calendar.startOfDay(for: now)
        let workStart = calendar.date(byAdding: .minute, value: config.workStartMinutes, to: dayStart) ?? now
        let workEnd = calendar.date(byAdding: .minute, value: config.workEndMinutes, to: dayStart) ?? now
        let inWork = isWorkingDay && now >= workStart && now < workEnd

        let interval: TimeInterval = inWork ? 30 : 15 * 60
        let count = inWork ? 60 : 8

        return (0..<count).map { index in
            let date = now.addingTimeInterval(Double(index) * interval)
            return makeEntry(at: date, config: config, loaded: loaded)
        }
    }
}

struct WageJumpWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WageJumpEntry

    var body: some View {
        // 直接展示 timeline entry（已按未来时间预计算），不依赖 TimelineView / App 前台
        content(snapshot: entry.snapshot, now: entry.date)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                Color.widgetBackground
            }
    }

    @ViewBuilder
    private func content(snapshot: IncomeSnapshot, now: Date) -> some View {
        switch family {
        case .systemMedium:
            mediumView(snapshot: snapshot, now: now)
        default:
            smallView(snapshot: snapshot, now: now)
        }
    }

    private func smallView(snapshot: IncomeSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    statusDot(snapshot: snapshot)
                    Text("今日入账")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    syncTimeText
                }
                amountRow(snapshot: snapshot, symbolSize: 22, amountSize: 28)
                progressTrack(progress: snapshot.todayProgress, height: 10, knob: 12)
            }

            Text("发薪 \(snapshot.daysUntilPayday) 天")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private func mediumView(snapshot: IncomeSnapshot, now: Date) -> some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 6) {
                        statusDot(snapshot: snapshot)
                        Text("今日入账")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    syncTimeText
                }

                amountRow(snapshot: snapshot, symbolSize: 26, amountSize: 34)
                progressTrack(progress: snapshot.todayProgress, height: 12, knob: 14)
            }

            HStack {
                labeledStat(title: "已工作", value: workedTimeText(snapshot: snapshot))
                Spacer()
                labeledStat(title: "距离下班", value: remainingTimeText(now: now))
                Spacer()
                labeledStat(title: "发薪", value: "\(snapshot.daysUntilPayday) 天")
            }
        }
        .padding(16)
    }

    private var syncTimeText: some View {
        Text(entry.configLoaded ? "最后同步 \(formattedSyncTime(entry.date))" : "未同步")
            .font(.caption2.weight(.medium))
            .foregroundStyle(entry.configLoaded ? Color.secondary.opacity(0.7) : Color.orange)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func formattedSyncTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm:ss"
        } else {
            formatter.dateFormat = "M/d HH:mm"
        }
        return formatter.string(from: date)
    }

    private func statusDot(snapshot: IncomeSnapshot) -> some View {
        Circle()
            .fill(workStatusColor(snapshot: snapshot))
            .frame(width: 7, height: 7)
    }

    private func amountRow(snapshot: IncomeSnapshot, symbolSize: CGFloat, amountSize: CGFloat) -> some View {
        let symbol = currencySymbol(entry.currencyCode)
        let full = CurrencyFormatter.liveString(
            amount: snapshot.todayIncome,
            currencyCode: entry.currencyCode,
            fractionDigits: 2
        )
        let amount = full
            .replacingOccurrences(of: symbol, with: "")
            .trimmingCharacters(in: .whitespaces)

        return HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(symbol)
                .font(.system(size: symbolSize, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
            Text(amount)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private func labeledStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func progressTrack(progress: Double, height: CGFloat, knob: CGFloat) -> some View {
        GeometryReader { proxy in
            let clamped = min(1, max(0, progress))
            let width = proxy.size.width
            let fillWidth = max(knob, width * CGFloat(clamped))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: height)
                Capsule()
                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fillWidth, height: height)
                Circle()
                    .fill(Color.orange)
                    .overlay(Circle().stroke(Color.widgetBackground, lineWidth: 2))
                    .frame(width: knob, height: knob)
                    .offset(x: max(0, min(width - knob, fillWidth - knob / 2)))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: max(height, knob))
    }

    private func workStatusColor(snapshot: IncomeSnapshot) -> Color {
        switch snapshot.workPhase {
        case .working: return .green
        case .lunch: return .red
        case .offDuty: return .secondary
        }
    }

    private func currencySymbol(_ code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? "¥"
    }

    private func workedTimeText(snapshot: IncomeSnapshot) -> String {
        formatMinutes(Int(Double(entry.dailyWorkMinutes) * snapshot.todayProgress))
    }

    private func remainingTimeText(now: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        guard entry.workingWeekdays.contains(weekday) else { return formatMinutes(0) }
        let dayStart = calendar.startOfDay(for: now)
        guard let workEnd = calendar.date(byAdding: .minute, value: entry.workEndMinutes, to: dayStart) else {
            return formatMinutes(0)
        }
        return formatMinutes(max(0, Int(workEnd.timeIntervalSince(now) / 60)))
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }
}

struct WageJumpWidget: Widget {
    let kind = "WageJumpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WageJumpProvider()) { entry in
            WageJumpWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("WageJump")
        .description("实时查看今日收入与工作进度。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension Color {
    /// 跟随系统浅色 / 暗黑模式的小组件背景。
    static var widgetBackground: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }
}
