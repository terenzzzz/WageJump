import Foundation
import Testing
@testable import WageJump

struct SalaryCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func excludesWeekendFromTodayIncome() throws {
        let config = SalaryConfig(
            monthlySalary: 22000,
            payday: 15,
            workStartMinutes: 9 * 60,
            workEndMinutes: 18 * 60,
            lunchStartMinutes: 12 * 60,
            lunchDurationMinutes: 60,
            workingWeekdays: [2, 3, 4, 5, 6],
            currencyCode: "CNY"
        )

        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 18
        components.hour = 12
        components.minute = 30
        let saturday = calendar.date(from: components)!

        let snapshot = SalaryCalculator(calendar: calendar).snapshot(config: config, now: saturday)
        #expect(snapshot.todayIncome == 0)
        #expect(snapshot.todayProgress == 0)
    }

    @Test func calculatesTodayIncomeAtNoon() throws {
        let config = SalaryConfig.default
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 20
        components.hour = 12
        components.minute = 0
        let mondayNoon = calendar.date(from: components)!

        let snapshot = SalaryCalculator(calendar: calendar).snapshot(config: config, now: mondayNoon)
        #expect(snapshot.todayIncome > 0)
        #expect(snapshot.todayProgress > 0)
        #expect(snapshot.todayProgress < 1)
    }

    @Test func pausesIncomeDuringLunch() throws {
        let config = SalaryConfig.default
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 20
        components.hour = 12
        components.minute = 0
        let lunchStart = calendar.date(from: components)!

        components.minute = 30
        let lunchMid = calendar.date(from: components)!

        let calculator = SalaryCalculator(calendar: calendar)
        let atStart = calculator.snapshot(config: config, now: lunchStart)
        let atMid = calculator.snapshot(config: config, now: lunchMid)

        #expect(atStart.workPhase == .lunch)
        #expect(atMid.workPhase == .lunch)
        #expect(atStart.todayIncome == atMid.todayIncome)
    }

    @Test func marksWorkingPhaseOutsideLunch() throws {
        let config = SalaryConfig.default
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 20
        components.hour = 10
        components.minute = 0
        let morning = calendar.date(from: components)!

        let snapshot = SalaryCalculator(calendar: calendar).snapshot(config: config, now: morning)
        #expect(snapshot.workPhase == .working)
    }
}
