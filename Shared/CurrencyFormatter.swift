import Foundation

enum CurrencyFormatter {
    static func string(amount: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    /// 实时入账展示用，保留更多小数，方便每秒跳动可见。
    static func liveString(amount: Double, currencyCode: String, fractionDigits: Int = 4) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.\(fractionDigits)f", amount)
    }
}
