import Foundation

enum WorkPhase: String, Codable, Equatable {
    case offDuty
    case working
    case lunch
}

struct IncomeSnapshot: Codable, Equatable {
    var todayIncome: Double
    var monthIncome: Double
    var yearIncome: Double
    var hourlyIncome: Double
    var minuteIncome: Double
    var todayProgress: Double
    var monthProgress: Double
    var daysUntilPayday: Int
    var workPhase: WorkPhase

    static let empty = IncomeSnapshot(
        todayIncome: 0,
        monthIncome: 0,
        yearIncome: 0,
        hourlyIncome: 0,
        minuteIncome: 0,
        todayProgress: 0,
        monthProgress: 0,
        daysUntilPayday: 0,
        workPhase: .offDuty
    )
}

/// 主 App 写入、小组件原样读取的共享状态。
struct SharedWidgetState: Codable, Equatable {
    var updatedAt: Date
    var snapshot: IncomeSnapshot
    var currencyCode: String
    var dailyWorkMinutes: Int
    var workEndMinutes: Int
    var workingWeekdays: [Int]
    var monthlySalary: Double
    var config: SalaryConfig?

    static let empty = SharedWidgetState(
        updatedAt: .distantPast,
        snapshot: .empty,
        currencyCode: "CNY",
        dailyWorkMinutes: 0,
        workEndMinutes: 0,
        workingWeekdays: [],
        monthlySalary: 0,
        config: nil
    )
}

enum SharedWidgetStateStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func save(_ state: SharedWidgetState) {
        AppGroupPaths.ensureContainer()
        guard let data = try? encoder.encode(state) else { return }

        defaults?.set(data, forKey: AppConstants.widgetStateKey)
        defaults?.synchronize()

        for url in AppGroupPaths.allFileURLs(named: AppConstants.widgetStateKey) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // 先写临时文件再替换，避免小组件读到半截 JSON
            let temp = url.appendingPathExtension("tmp")
            do {
                try data.write(to: temp, options: .atomic)
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try FileManager.default.moveItem(at: temp, to: url)
            } catch {
                try? data.write(to: url, options: .atomic)
                try? FileManager.default.removeItem(at: temp)
            }
        }
    }

    static func load() -> SharedWidgetState? {
        AppGroupPaths.ensureContainer()

        var best: (state: SharedWidgetState, date: Date)?
        for url in AppGroupPaths.allFileURLs(named: AppConstants.widgetStateKey) {
            guard let data = try? Data(contentsOf: url),
                  let state = decode(data) else { continue }
            if best == nil || state.updatedAt > best!.date {
                best = (state, state.updatedAt)
            }
        }
        if let best { return best.state }

        defaults?.synchronize()
        if let data = defaults?.data(forKey: AppConstants.widgetStateKey),
           let state = decode(data) {
            return state
        }
        return nil
    }

    private static func decode(_ data: Data) -> SharedWidgetState? {
        if let state = try? decoder.decode(SharedWidgetState.self, from: data) {
            return state
        }
        return try? JSONDecoder().decode(SharedWidgetState.self, from: data)
    }
}
