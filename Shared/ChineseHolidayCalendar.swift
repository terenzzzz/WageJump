import Foundation

struct ChineseHoliday: Identifiable, Equatable {
    let id: String
    let name: String
    let date: Date

    init(name: String, year: Int, month: Int, day: Int, calendar: Calendar = .current) {
        self.name = name
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let resolved = calendar.date(from: components) ?? Date.distantPast
        self.date = calendar.startOfDay(for: resolved)
        self.id = "\(name)-\(year)-\(month)-\(day)"
    }
}

struct HolidayCountdownItem: Identifiable, Equatable {
    let holiday: ChineseHoliday
    let daysRemaining: Int

    var id: String { holiday.id }
}

enum ChineseHolidayCalendar {
    /// 中国重要法定节假日（含农历节日对应公历日期）
    static func holidays(calendar: Calendar = .current) -> [ChineseHoliday] {
        let entries: [(String, Int, Int, Int)] = [
            // 2026
            ("元旦", 2026, 1, 1),
            ("春节", 2026, 2, 17),
            ("清明节", 2026, 4, 5),
            ("劳动节", 2026, 5, 1),
            ("端午节", 2026, 6, 19),
            ("中秋节", 2026, 9, 25),
            ("国庆节", 2026, 10, 1),
            // 2027
            ("元旦", 2027, 1, 1),
            ("春节", 2027, 2, 6),
            ("清明节", 2027, 4, 5),
            ("劳动节", 2027, 5, 1),
            ("端午节", 2027, 6, 9),
            ("中秋节", 2027, 9, 15),
            ("国庆节", 2027, 10, 1),
            // 2028
            ("元旦", 2028, 1, 1),
            ("春节", 2028, 1, 26),
            ("清明节", 2028, 4, 4),
            ("劳动节", 2028, 5, 1),
            ("端午节", 2028, 5, 28),
            ("中秋节", 2028, 10, 3),
            ("国庆节", 2028, 10, 1),
            // 2029
            ("元旦", 2029, 1, 1),
            ("春节", 2029, 2, 13),
            ("清明节", 2029, 4, 4),
            ("劳动节", 2029, 5, 1),
            ("端午节", 2029, 6, 16),
            ("中秋节", 2029, 9, 22),
            ("国庆节", 2029, 10, 1),
        ]

        return entries.map { name, year, month, day in
            ChineseHoliday(name: name, year: year, month: month, day: day, calendar: calendar)
        }
    }

    static func upcomingCountdowns(
        from now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 8
    ) -> [HolidayCountdownItem] {
        let today = calendar.startOfDay(for: now)
        return holidays(calendar: calendar)
            .compactMap { holiday -> HolidayCountdownItem? in
                let days = calendar.dateComponents([.day], from: today, to: holiday.date).day ?? 0
                guard days >= 0 else { return nil }
                return HolidayCountdownItem(holiday: holiday, daysRemaining: days)
            }
            .sorted { lhs, rhs in
                if lhs.daysRemaining != rhs.daysRemaining {
                    return lhs.daysRemaining < rhs.daysRemaining
                }
                return lhs.holiday.name < rhs.holiday.name
            }
            .prefix(limit)
            .map { $0 }
    }
}
