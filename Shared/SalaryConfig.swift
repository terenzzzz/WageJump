import Foundation

struct SalaryConfig: Codable, Equatable {
    var monthlySalary: Double
    var payday: Int
    var workStartMinutes: Int
    var workEndMinutes: Int
    var lunchStartMinutes: Int
    var lunchDurationMinutes: Int
    var workingWeekdays: Set<Int>
    var currencyCode: String

    static let `default` = SalaryConfig(
        monthlySalary: 12000,
        payday: 15,
        workStartMinutes: 9 * 60,
        workEndMinutes: 18 * 60,
        lunchStartMinutes: 12 * 60,
        lunchDurationMinutes: 60,
        workingWeekdays: [2, 3, 4, 5, 6],
        currencyCode: "CNY"
    )

    var dailyWorkMinutes: Int {
        let total = max(0, workEndMinutes - workStartMinutes)
        return max(0, total - lunchDurationMinutes)
    }
}
