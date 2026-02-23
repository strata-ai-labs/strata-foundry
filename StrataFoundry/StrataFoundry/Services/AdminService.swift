//
//  AdminService.swift
//  StrataFoundry
//
//  Administrative database operations.
//

import Foundation

final class AdminService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func ping() async throws -> String {
        let output = try await client.execute(.ping)
        guard case .pong(let version) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Pong", got: output.variantName)
        }
        return version
    }

    func info() async throws -> StrataDatabaseInfo {
        let output = try await client.execute(.info)
        guard case .databaseInfo(let info) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "DatabaseInfo", got: output.variantName)
        }
        return info
    }

    func flush() async throws {
        let output = try await client.execute(.flush)
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func compact() async throws {
        let output = try await client.execute(.compact)
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func timeRange(branch: String? = nil) async throws -> (oldestTs: UInt64?, latestTs: UInt64?) {
        let output = try await client.execute(.timeRange(branch: branch))
        guard case .timeRange(let oldest, let latest) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "TimeRange", got: output.variantName)
        }
        return (oldestTs: oldest, latestTs: latest)
    }

    func configGet() async throws -> StrataConfig {
        let output = try await client.execute(.configGet)
        guard case .config(let config) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Config", got: output.variantName)
        }
        return config
    }

    func setAutoEmbed(enabled: Bool) async throws {
        let output = try await client.execute(.configSetAutoEmbed(enabled: enabled))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func autoEmbedStatus() async throws -> Bool {
        let output = try await client.execute(.autoEmbedStatus)
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }

    func retentionApply(branch: String? = nil) async throws {
        _ = try await client.execute(.retentionApply(branch: branch))
    }

    func retentionStats(branch: String? = nil) async throws -> String {
        let raw = try await client.executeRawJSON(.retentionStats(branch: branch))
        return prettyPrintJSON(raw) ?? raw
    }

    func retentionPreview(branch: String? = nil) async throws -> String {
        let raw = try await client.executeRawJSON(.retentionPreview(branch: branch))
        return prettyPrintJSON(raw) ?? raw
    }

    private func prettyPrintJSON(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return nil }
        return str
    }

    func durabilityCounters() async throws -> WalCounters {
        let output = try await client.execute(.durabilityCounters)
        guard case .durabilityCounters(let counters) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "DurabilityCounters", got: output.variantName)
        }
        return counters
    }
}
