import Foundation
#if os(macOS)
import Darwin
#endif

enum AppGroupPaths {
#if os(macOS)
    /// 真实用户主目录（沙盒内 home 会指向 Container）。
    static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty, path != "/", !path.contains("/Library/Containers/") {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }

        let sandboxed = FileManager.default.homeDirectoryForCurrentUser
        let path = sandboxed.path
        if let range = path.range(of: "/Library/Containers/") {
            return URL(fileURLWithPath: String(path[..<range.lowerBound]), isDirectory: true)
        }
        return sandboxed
    }

    /// Mac 上 App ↔ Widget 最稳的共享目录（配合 temporary-exception）。
    static var applicationScriptsGroupURL: URL {
        realHomeDirectory
            .appendingPathComponent("Library/Application Scripts", isDirectory: true)
            .appendingPathComponent(AppConstants.appGroupID, isDirectory: true)
    }

    static var sharedGroupURL: URL {
        realHomeDirectory
            .appendingPathComponent("Library/Group Containers", isDirectory: true)
            .appendingPathComponent(AppConstants.appGroupID, isDirectory: true)
    }
#endif

    static var systemContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        )
    }

#if os(macOS)
    private static func isInsideAppSandbox(_ url: URL) -> Bool {
        url.path.contains("/Library/Containers/")
    }
#endif

    /// 所有可读写的共享根目录。
    /// iOS 使用系统 App Group container；macOS 额外写入真实 Group Containers / Application Scripts。
    static var sharedDirectories: [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL?) {
            guard let url else { return }
#if os(macOS)
            guard !isInsideAppSandbox(url) else { return }
#endif
            let key = url.standardizedFileURL.path
            if seen.insert(key).inserted {
                urls.append(url)
            }
        }

#if os(macOS)
        append(applicationScriptsGroupURL)
        append(sharedGroupURL)
#endif
        append(systemContainerURL)
        return urls
    }

    static func allFileURLs(named name: String) -> [URL] {
        sharedDirectories.map { $0.appendingPathComponent(name) }
    }

    static func ensureContainer() {
        for dir in sharedDirectories {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

protocol SalaryConfigStoring {
    func load() -> SalaryConfig
    func save(_ config: SalaryConfig)
    var hasCompletedSetup: Bool { get }
    func markSetupComplete()
}

final class SalaryConfigStore: SalaryConfigStoring {
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    private var configFileName: String { "\(AppConstants.salaryConfigKey).json" }
    private var setupFileName: String { "\(AppConstants.hasCompletedSetupKey).flag" }

    var hasCompletedSetup: Bool {
        AppGroupPaths.ensureContainer()
        for url in AppGroupPaths.allFileURLs(named: setupFileName) where FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        return sharedDefaults?.bool(forKey: AppConstants.hasCompletedSetupKey) == true
    }

    func markSetupComplete() {
        AppGroupPaths.ensureContainer()
        sharedDefaults?.set(true, forKey: AppConstants.hasCompletedSetupKey)
        sharedDefaults?.synchronize()
        write(Data([1]), named: setupFileName)
    }

    func load() -> SalaryConfig {
        AppGroupPaths.ensureContainer()
        for url in AppGroupPaths.allFileURLs(named: configFileName) {
            if let data = try? Data(contentsOf: url),
               let config = decodeConfig(data) {
                return config
            }
        }
        if let data = sharedDefaults?.data(forKey: AppConstants.salaryConfigKey),
           let config = decodeConfig(data) {
            return config
        }
        return .default
    }

    func save(_ config: SalaryConfig) {
        AppGroupPaths.ensureContainer()
        guard let data = encodeConfig(config) else { return }
        sharedDefaults?.set(data, forKey: AppConstants.salaryConfigKey)
        sharedDefaults?.synchronize()
        write(data, named: configFileName)
    }

    private func encodeConfig(_ config: SalaryConfig) -> Data? {
        try? JSONEncoder().encode(config)
    }

    private func decodeConfig(_ data: Data) -> SalaryConfig? {
        try? JSONDecoder().decode(SalaryConfig.self, from: data)
    }

    private func write(_ data: Data, named name: String) {
        for url in AppGroupPaths.allFileURLs(named: name) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        }
    }
}
