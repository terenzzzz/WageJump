import Combine
import Foundation
import WidgetKit

final class DashboardViewModel: ObservableObject {
    @Published var config: SalaryConfig
    @Published private(set) var snapshot: IncomeSnapshot = .empty
    @Published private(set) var hasCompletedSetup: Bool

    private let store: SalaryConfigStoring
    private let calculator: SalaryCalculating
    private var ticker: AnyCancellable?
    private var lastWidgetReloadAt: Date?

    init(store: SalaryConfigStoring = SalaryConfigStore(), calculator: SalaryCalculating = SalaryCalculator()) {
        self.store = store
        self.calculator = calculator
        self.config = store.load()
        self.hasCompletedSetup = store.hasCompletedSetup
        store.save(config)
        recalculate()
        reloadWidget(force: true)
        startTicker()
    }

    func saveConfig(_ newConfig: SalaryConfig, markSetupComplete: Bool = false) {
        config = newConfig
        store.save(newConfig)
        if markSetupComplete {
            store.markSetupComplete()
            hasCompletedSetup = true
        }
        recalculate()
        reloadWidget(force: true)
    }

    func recalculate() {
        snapshot = calculator.snapshot(config: config, now: Date())
        publishWidgetState()
        // 数字由小组件自行按配置实时计算；App 只在配置变更或低频心跳时 reload，避免被系统节流
        reloadWidget(force: false)
    }

    private func startTicker() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.recalculate()
            }
    }

    private func publishWidgetState() {
        let state = SharedWidgetState(
            updatedAt: Date(),
            snapshot: snapshot,
            currencyCode: config.currencyCode,
            dailyWorkMinutes: config.dailyWorkMinutes,
            workEndMinutes: config.workEndMinutes,
            workingWeekdays: Array(config.workingWeekdays),
            monthlySalary: config.monthlySalary,
            config: config
        )
        SharedWidgetStateStore.save(state)
    }

    private func reloadWidget(force: Bool) {
        let now = Date()
        // App 在前台时每 30 秒补一次 timeline；关 App 后靠小组件自己的预生成条目推进
        let minInterval: TimeInterval = 30
        if force || lastWidgetReloadAt == nil || now.timeIntervalSince(lastWidgetReloadAt!) >= minInterval {
            lastWidgetReloadAt = now
            WidgetCenter.shared.reloadTimelines(ofKind: "WageJumpWidget")
        }
    }
}
