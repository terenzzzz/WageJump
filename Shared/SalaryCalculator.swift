import Foundation

protocol SalaryCalculating {
    func snapshot(config: SalaryConfig, now: Date) -> IncomeSnapshot
}

struct SalaryCalculator: SalaryCalculating {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(config: SalaryConfig, now: Date) -> IncomeSnapshot {
        guard config.monthlySalary > 0, config.dailyWorkMinutes > 0 else {
            return .empty
        }

        let workdaysThisMonth = max(1, countWorkingDaysInMonth(containing: now, config: config))
        let dailyIncome = config.monthlySalary / Double(workdaysThisMonth)
        let dailyWorkSeconds = Double(config.dailyWorkMinutes * 60)
        let secondIncome = dailyIncome / dailyWorkSeconds
        let minuteIncome = secondIncome * 60
        let hourlyIncome = minuteIncome * 60

        let todaySeconds = workedSeconds(on: now, until: now, config: config)
        let todayIncome = todaySeconds * secondIncome
        let todayProgress = min(1, max(0, todaySeconds / dailyWorkSeconds))

        let monthIncome = accumulatedIncomeInMonth(now: now, config: config, secondIncome: secondIncome)
        let yearIncome = accumulatedIncomeInYear(now: now, config: config)
        let monthProgress = min(1, max(0, monthIncome / config.monthlySalary))
        let daysUntilPayday = daysUntilPayday(from: now, payday: config.payday)

        return IncomeSnapshot(
            todayIncome: todayIncome,
            monthIncome: monthIncome,
            yearIncome: yearIncome,
            hourlyIncome: hourlyIncome,
            minuteIncome: minuteIncome,
            todayProgress: todayProgress,
            monthProgress: monthProgress,
            daysUntilPayday: daysUntilPayday,
            workPhase: workPhase(now: now, config: config)
        )
    }

    private func workPhase(now: Date, config: SalaryConfig) -> WorkPhase {
        guard isWorkingDay(date: now, config: config) else { return .offDuty }

        let dayStart = calendar.startOfDay(for: now)
        let workStart = calendar.date(byAdding: .minute, value: config.workStartMinutes, to: dayStart) ?? now
        let workEnd = calendar.date(byAdding: .minute, value: config.workEndMinutes, to: dayStart) ?? now
        let lunchStart = calendar.date(byAdding: .minute, value: config.lunchStartMinutes, to: dayStart) ?? now
        let lunchEnd = calendar.date(byAdding: .minute, value: config.lunchStartMinutes + config.lunchDurationMinutes, to: dayStart) ?? now

        guard now >= workStart, now < workEnd else { return .offDuty }
        if config.lunchDurationMinutes > 0, now >= lunchStart, now < lunchEnd {
            return .lunch
        }
        return .working
    }

    private func accumulatedIncomeInMonth(now: Date, config: SalaryConfig, secondIncome: Double) -> Double {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthRange = calendar.range(of: .day, in: .month, for: now) else {
            return 0
        }

        var total = 0.0
        let todayDay = calendar.component(.day, from: now)
        let dailyWorkSeconds = Double(config.dailyWorkMinutes * 60)

        for day in monthRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            if !isWorkingDay(date: date, config: config) { continue }

            if day < todayDay {
                total += dailyWorkSeconds * secondIncome
            } else if day == todayDay {
                total += workedSeconds(on: date, until: now, config: config) * secondIncome
            }
        }
        return total
    }

    private func accumulatedIncomeInYear(now: Date, config: SalaryConfig) -> Double {
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
            return 0
        }
        var total = 0.0
        let currentMonth = calendar.component(.month, from: now)
        let currentMonthIncome = snapshotCurrentMonthIncome(now: now, config: config)

        for month in 1..<currentMonth {
            guard let date = calendar.date(byAdding: .month, value: month - 1, to: yearStart) else { continue }
            let workdays = max(1, countWorkingDaysInMonth(containing: date, config: config))
            total += config.monthlySalary / Double(workdays) * Double(workdays)
        }

        return total + currentMonthIncome
    }

    private func snapshotCurrentMonthIncome(now: Date, config: SalaryConfig) -> Double {
        guard config.monthlySalary > 0, config.dailyWorkMinutes > 0 else { return 0 }
        let workdays = max(1, countWorkingDaysInMonth(containing: now, config: config))
        let dailyIncome = config.monthlySalary / Double(workdays)
        let secondIncome = dailyIncome / Double(config.dailyWorkMinutes * 60)
        return accumulatedIncomeInMonth(now: now, config: config, secondIncome: secondIncome)
    }

    private func countWorkingDaysInMonth(containing date: Date, config: SalaryConfig) -> Int {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthRange = calendar.range(of: .day, in: .month, for: date) else {
            return 0
        }

        var count = 0
        for day in monthRange {
            guard let each = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            if isWorkingDay(date: each, config: config) {
                count += 1
            }
        }
        return count
    }

    private func workedSeconds(on day: Date, until now: Date, config: SalaryConfig) -> TimeInterval {
        guard isWorkingDay(date: day, config: config) else { return 0 }
        let dayStart = calendar.startOfDay(for: day)

        let workStart = calendar.date(byAdding: .minute, value: config.workStartMinutes, to: dayStart) ?? day
        let workEnd = calendar.date(byAdding: .minute, value: config.workEndMinutes, to: dayStart) ?? day

        guard workEnd > workStart else { return 0 }

        let lunchStart = calendar.date(byAdding: .minute, value: config.lunchStartMinutes, to: dayStart) ?? day
        let lunchEnd = calendar.date(byAdding: .minute, value: config.lunchStartMinutes + config.lunchDurationMinutes, to: dayStart) ?? day

        let effectiveNow = min(max(now, workStart), workEnd)
        guard effectiveNow > workStart else { return 0 }

        let raw = effectiveNow.timeIntervalSince(workStart)
        let lunchOverlap = overlapSeconds(startA: workStart, endA: effectiveNow, startB: lunchStart, endB: lunchEnd)
        return max(0, raw - lunchOverlap)
    }

    private func overlapSeconds(startA: Date, endA: Date, startB: Date, endB: Date) -> TimeInterval {
        let start = max(startA, startB)
        let end = min(endA, endB)
        guard end > start else { return 0 }
        return end.timeIntervalSince(start)
    }

    private func isWorkingDay(date: Date, config: SalaryConfig) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return config.workingWeekdays.contains(weekday)
    }

    private func daysUntilPayday(from now: Date, payday: Int) -> Int {
        let today = calendar.startOfDay(for: now)
        let currentDay = calendar.component(.day, from: today)
        if currentDay <= payday {
            return payday - currentDay
        }

        var nextMonthComp = calendar.dateComponents([.year, .month], from: today)
        nextMonthComp.month = (nextMonthComp.month ?? 1) + 1
        nextMonthComp.day = 1

        guard let nextMonthDate = calendar.date(from: nextMonthComp),
              let range = calendar.range(of: .day, in: .month, for: nextMonthDate) else {
            return 0
        }

        let validPayday = min(max(1, payday), range.count)
        var paydayComp = calendar.dateComponents([.year, .month], from: nextMonthDate)
        paydayComp.day = validPayday

        guard let nextPaydayDate = calendar.date(from: paydayComp) else { return 0 }
        let days = calendar.dateComponents([.day], from: today, to: nextPaydayDate).day ?? 0
        return max(0, days)
    }
}
