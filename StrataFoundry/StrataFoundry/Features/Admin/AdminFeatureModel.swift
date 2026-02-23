import Foundation

@Observable
final class AdminFeatureModel {
    private let adminService: AdminService
    private let appState: AppState

    // Config
    var configJSON: String?
    var configError: String?
    var autoEmbedEnabled: Bool?
    var autoEmbedError: String?

    // Ping
    var pingResult: String?
    var pingError: String?

    // Retention
    var retentionMessage: String?
    var retentionError: String?
    var retentionStats: String?
    var retentionPreview: String?

    // Maintenance
    var flushMessage: String?
    var compactMessage: String?
    var maintenanceError: String?
    var durabilityCounters: String?
    var durabilityError: String?

    init(adminService: AdminService, appState: AppState) {
        self.adminService = adminService
        self.appState = appState
    }

    func loadAll() async {
        await runPing()
        await loadConfig()
        await loadAutoEmbedStatus()
        await loadDurabilityCounters()
    }

    func runPing() async {
        pingResult = nil
        pingError = nil
        do {
            let pong = try await adminService.ping()
            pingResult = "Pong: \(pong)"
        } catch {
            pingError = error.localizedDescription
        }
    }

    func loadConfig() async {
        configJSON = nil
        configError = nil
        do {
            let config = try await adminService.configGet()
            let data = try JSONEncoder.strataEncoder.encode(config)
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                configJSON = str
            } else {
                configJSON = String(data: data, encoding: .utf8)
            }
        } catch {
            configError = error.localizedDescription
        }
    }

    func loadAutoEmbedStatus() async {
        autoEmbedError = nil
        do {
            autoEmbedEnabled = try await adminService.autoEmbedStatus()
        } catch {
            autoEmbedError = error.localizedDescription
        }
    }

    func setAutoEmbed(_ enabled: Bool) async {
        autoEmbedError = nil
        do {
            try await adminService.setAutoEmbed(enabled: enabled)
            autoEmbedEnabled = enabled
        } catch {
            autoEmbedError = error.localizedDescription
        }
    }

    func runRetention() async {
        retentionMessage = nil
        retentionError = nil
        retentionStats = nil
        retentionPreview = nil
        do {
            try await adminService.retentionApply()
            retentionMessage = "GC completed."
        } catch {
            retentionError = error.localizedDescription
        }
    }

    func loadRetentionStats() async {
        retentionStats = nil
        retentionError = nil
        do {
            let stats = try await adminService.retentionStats()
            retentionStats = stats.prettyJSON
        } catch {
            retentionError = error.localizedDescription
        }
    }

    func loadRetentionPreview() async {
        retentionPreview = nil
        retentionError = nil
        do {
            let preview = try await adminService.retentionPreview()
            retentionPreview = preview.prettyJSON
        } catch {
            retentionError = error.localizedDescription
        }
    }

    func runFlush() async {
        flushMessage = nil
        compactMessage = nil
        maintenanceError = nil
        do {
            try await adminService.flush()
            flushMessage = "Flush completed."
        } catch {
            maintenanceError = error.localizedDescription
        }
    }

    func runCompact() async {
        flushMessage = nil
        compactMessage = nil
        maintenanceError = nil
        do {
            try await adminService.compact()
            compactMessage = "Compaction completed."
        } catch {
            maintenanceError = error.localizedDescription
        }
    }

    func loadDurabilityCounters() async {
        durabilityCounters = nil
        durabilityError = nil
        do {
            let counters = try await adminService.durabilityCounters()
            let data = try JSONEncoder.strataEncoder.encode(counters)
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                durabilityCounters = str
            } else {
                durabilityCounters = String(data: data, encoding: .utf8)
            }
        } catch {
            durabilityError = error.localizedDescription
        }
    }
}
