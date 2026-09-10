//
//  ContentView.swift
//  WageJump
//
//  Created by 蒋志聪 on 20/07/2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isPresentingSettings = false

    var body: some View {
        Group {
            if viewModel.hasCompletedSetup {
                dashboard
            } else {
                OnboardingView(config: viewModel.config) { updated in
                    viewModel.saveConfig(updated, markSetupComplete: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView(config: viewModel.config) { updated in
                viewModel.saveConfig(updated)
            }
#if os(macOS)
            .frame(width: 520, height: 720)
#endif
#if os(iOS)
            .presentationDetents([.large])
#endif
        }
    }

    private var dashboard: some View {
        GeometryReader { proxy in
            let layout = DashboardLayout(width: proxy.size.width)

            ScrollView {
                VStack(spacing: layout.sectionSpacing) {
                    mainIncomeCard
                    holidayCountdownSection(columns: layout.holidayColumns)
                }
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.top, layout.topPadding)
                .padding(.bottom, layout.bottomPadding)
                .frame(maxWidth: layout.contentMaxWidth, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
    }

    private struct DashboardLayout {
        let width: CGFloat

        var usesTwoHolidayColumns: Bool {
#if os(macOS)
            return width >= 560
#else
            return width >= 700
#endif
        }

        var holidayColumns: Int { usesTwoHolidayColumns ? 2 : 1 }

        var horizontalPadding: CGFloat {
#if os(macOS)
            return 24
#else
            return 20
#endif
        }

        var topPadding: CGFloat {
#if os(macOS)
            return 12
#else
            return 8
#endif
        }

        var bottomPadding: CGFloat {
#if os(macOS)
            return 28
#else
            return 24
#endif
        }

        var sectionSpacing: CGFloat {
#if os(macOS)
            return 22
#else
            return 20
#endif
        }

        var contentMaxWidth: CGFloat {
#if os(macOS)
            return 720
#else
            return .infinity
#endif
        }
    }

    private func holidayCountdownSection(columns: Int) -> some View {
        let items = ChineseHolidayCalendar.upcomingCountdowns()
        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: columns
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("法定节假日")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            if columns > 1 {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(items) { item in
                        holidayCard(item)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        holidayRow(item)
                        if index < items.count - 1 {
                            Divider()
                                .opacity(0.5)
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.97, blue: 0.975))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func holidayCard(_ item: HolidayCountdownItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.holiday.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(holidayDateText(item.holiday.date))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(countdownText(item.daysRemaining))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.daysRemaining == 0 ? Color.orange : Color.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.97, green: 0.97, blue: 0.975))
        )
    }

    private func holidayRow(_ item: HolidayCountdownItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.holiday.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(holidayDateText(item.holiday.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(countdownText(item.daysRemaining))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.daysRemaining == 0 ? Color.orange : Color.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func holidayDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
        formatter.dateFormat = sameYear ? "M月d日" : "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func countdownText(_ days: Int) -> String {
        if days == 0 {
            return "今天"
        }
        return "还有 \(days) 天"
    }

    private var mainIncomeCard: some View {
        VStack(spacing: 24) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(workStatusColor)
                        .frame(width: 8, height: 8)
                    Text(workStatusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                toolbarIcon("slider.horizontal.3") { isPresentingSettings = true }
            }

            VStack(spacing: 8) {
                Text("今日入账")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(currencySymbol)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text(mainAmount)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.2), value: mainAmount)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    statColumn(title: "已工作", value: workedTimeText)
                    dividerLine
                    statColumn(title: "距离下班", value: remainingTimeText)
                    dividerLine
                    statColumn(title: "今日预计", value: projectedIncomeText)
                }
                .padding(.vertical, 14)

                progressTrack
            }

            HStack(alignment: .top, spacing: 12) {
                Text("发薪倒计时 \(viewModel.snapshot.daysUntilPayday) 天")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("本月 \(CurrencyFormatter.string(amount: viewModel.snapshot.monthIncome, currencyCode: viewModel.config.currencyCode))")
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func toolbarIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1, height: 52)
            .padding(.horizontal, 8)
    }

    private var progressTrack: some View {
        GeometryReader { proxy in
            let progress = min(1, max(0, viewModel.snapshot.todayProgress))
            let width = proxy.size.width
            let fillWidth = max(28, width * progress)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 22)
                Capsule()
                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fillWidth, height: 22)
                Circle()
                    .fill(.orange)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .frame(width: 24, height: 24)
                    .offset(x: max(0, min(width - 24, fillWidth - 12)))
            }
        }
        .frame(height: 24)
    }

    private var workStatusText: String {
        switch viewModel.snapshot.workPhase {
        case .working:
            return "正在上班"
        case .lunch:
            return "午休中"
        case .offDuty:
            return "暂未工作"
        }
    }

    private var workStatusColor: Color {
        switch viewModel.snapshot.workPhase {
        case .working:
            return .green
        case .lunch:
            return .red
        case .offDuty:
            return .secondary
        }
    }

    private var workedTimeText: String {
        let workedMinutes = Int(Double(viewModel.config.dailyWorkMinutes) * viewModel.snapshot.todayProgress)
        return formatMinutes(workedMinutes)
    }

    private var remainingTimeText: String {
        formatMinutes(minutesUntilWorkEnd)
    }

    private var projectedIncomeText: String {
        // 今日预计 = 当天完整工时收入，固定不变
        let projected = Double(viewModel.config.dailyWorkMinutes) * viewModel.snapshot.minuteIncome
        return CurrencyFormatter.string(amount: projected, currencyCode: viewModel.config.currencyCode)
    }

    /// 按下班时间倒计时（墙上时钟），不是剩余有效工时。
    private var minutesUntilWorkEnd: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        guard viewModel.config.workingWeekdays.contains(weekday) else { return 0 }

        let dayStart = calendar.startOfDay(for: now)
        guard let workEnd = calendar.date(byAdding: .minute, value: viewModel.config.workEndMinutes, to: dayStart) else {
            return 0
        }
        return max(0, Int(workEnd.timeIntervalSince(now) / 60))
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.config.currencyCode
        return formatter.currencySymbol ?? "¥"
    }

    private var mainAmount: String {
        let full = CurrencyFormatter.liveString(
            amount: viewModel.snapshot.todayIncome,
            currencyCode: viewModel.config.currencyCode,
            fractionDigits: 2
        )
        let symbol = currencySymbol
        return full.replacingOccurrences(of: symbol, with: "").trimmingCharacters(in: .whitespaces)
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }
}

struct OnboardingView: View {
    @State var config: SalaryConfig
    var onComplete: (SalaryConfig) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    welcomeHeader
                    SettingsForm(config: $config)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .frame(maxWidth: macContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                startButton
                    .frame(maxWidth: macContentMaxWidth)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(onboardingBackground)
            .navigationTitle("首次配置")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }

    private var macContentMaxWidth: CGFloat {
#if os(macOS)
        return 560
#else
        return .infinity
#endif
    }

    private var welcomeHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(0.28),
                                Color.orange.opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 54
                        )
                    )
                    .frame(width: 108, height: 108)

                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.orange)
                    .shadow(color: Color.orange.opacity(0.25), radius: 10, y: 4)
            }

            VStack(spacing: 8) {
                Text("WageJump")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("填好基础信息，立刻看到今天赚了多少。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var startButton: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)
            Button {
                onComplete(config)
            } label: {
                Text("开始使用")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    private var onboardingBackground: some View {
        ZStack {
            SettingsTheme.pageBackground
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.10),
                    Color.clear,
                    SettingsTheme.pageBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State var config: SalaryConfig
    var onSave: (SalaryConfig) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                SettingsForm(config: $config)
                    .frame(maxWidth: macContentMaxWidth, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(SettingsTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("基础配置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(config)
                        dismiss()
                    }
                }
            }
        }
    }

    private var macContentMaxWidth: CGFloat {
#if os(macOS)
        return 520
#else
        return .infinity
#endif
    }
}

private enum SettingsTheme {
    static let pageBackground = Color(red: 0.965, green: 0.965, blue: 0.97)
    static let cardBorder = Color.black.opacity(0.06)
    static let fieldFill = Color(red: 0.97, green: 0.97, blue: 0.975)
    static let fieldBorder = Color.black.opacity(0.08)
    static let label = Color.secondary
    static let selectedFill = Color(red: 1.0, green: 0.93, blue: 0.86)
    static let selectedBorder = Color.orange.opacity(0.35)
}

struct SettingsForm: View {
    @Binding var config: SalaryConfig

    private let weekdayOptions: [(Int, String)] = [
        (2, "一"),
        (3, "二"),
        (4, "三"),
        (5, "四"),
        (6, "五"),
        (7, "六"),
        (1, "日")
    ]

    var body: some View {
        VStack(spacing: 14) {
            sectionCard(title: "薪资") {
                VStack(spacing: 12) {
                    editableValueRow(title: "月薪") {
                        HStack(spacing: 6) {
                            TextField("0", value: $config.monthlySalary, format: .number)
                                .font(.body.weight(.semibold))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                            Text("元")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }

                    stepperValueRow(
                        title: "发薪日",
                        display: "\(config.payday)日",
                        value: $config.payday,
                        range: 1...31
                    )
                }
            }

            sectionCard(title: "每周工作日") {
                HStack(spacing: 8) {
                    ForEach(weekdayOptions, id: \.0) { weekday, label in
                        weekdayChip(weekday: weekday, label: label)
                    }
                }
            }

            sectionCard(title: "工作时间") {
                VStack(spacing: 12) {
                    stepperValueRow(
                        title: "上班",
                        display: timeString(config.workStartMinutes),
                        value: $config.workStartMinutes,
                        range: 0...(23 * 60 + 45),
                        step: 15
                    )
                    stepperValueRow(
                        title: "下班",
                        display: timeString(config.workEndMinutes),
                        value: $config.workEndMinutes,
                        range: 0...(23 * 60 + 45),
                        step: 15
                    )
                    stepperValueRow(
                        title: "午休开始",
                        display: timeString(config.lunchStartMinutes),
                        value: $config.lunchStartMinutes,
                        range: 0...(23 * 60 + 45),
                        step: 15
                    )
                    stepperValueRow(
                        title: "午休时长",
                        display: "\(config.lunchDurationMinutes) 分钟",
                        value: $config.lunchDurationMinutes,
                        range: 0...180,
                        step: 5
                    )
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SettingsTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    private func weekdayChip(weekday: Int, label: String) -> some View {
        let selected = config.workingWeekdays.contains(weekday)
        return Button {
            if selected {
                config.workingWeekdays.remove(weekday)
            } else {
                config.workingWeekdays.insert(weekday)
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? SettingsTheme.selectedFill : SettingsTheme.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? SettingsTheme.selectedBorder : SettingsTheme.fieldBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func editableValueRow<Content: View>(
        title: String,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(SettingsTheme.label)
                .fixedSize()
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(fieldBackground)
    }

    private func stepperValueRow(
        title: String,
        display: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1
    ) -> some View {
        editableValueRow(title: title) {
            HStack(spacing: 10) {
                Text(display)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: true, vertical: false)
                CompactStepper(value: value, range: range, step: step)
            }
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(SettingsTheme.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SettingsTheme.fieldBorder, lineWidth: 1)
            )
    }

    private func timeString(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60
        return String(format: "%02d:%02d", h, m)
    }
}

private struct CompactStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus") {
                value = max(range.lowerBound, value - step)
            }
            .disabled(value <= range.lowerBound)

            Divider()
                .frame(height: 18)

            stepButton(systemName: "plus") {
                value = min(range.upperBound, value + step)
            }
            .disabled(value >= range.upperBound)
        }
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(SettingsTheme.fieldBorder, lineWidth: 1)
        )
        .fixedSize()
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
