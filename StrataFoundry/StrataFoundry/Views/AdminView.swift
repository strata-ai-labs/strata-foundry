//
//  AdminView.swift
//  StrataFoundry
//
//  Admin operations — config, retention, maintenance.
//

import SwiftUI

struct AdminView: View {
    @Environment(AppState.self) private var appState

    // Config
    @State private var configJSON: String?
    @State private var configError: String?
    @State private var autoEmbedEnabled: Bool?
    @State private var autoEmbedError: String?

    // Ping
    @State private var pingResult: String?
    @State private var pingError: String?

    // Retention
    @State private var retentionMessage: String?
    @State private var retentionError: String?
    @State private var retentionStats: String?
    @State private var retentionPreview: String?

    // Maintenance
    @State private var flushMessage: String?
    @State private var compactMessage: String?
    @State private var maintenanceError: String?
    @State private var durabilityCounters: String?
    @State private var durabilityError: String?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Text("Admin")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    Task { await loadAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: Connectivity
                    connectivitySection

                    Divider()

                    // MARK: Configuration Section
                    configurationSection

                    Divider()

                    // MARK: Retention Section
                    retentionSection

                    Divider()

                    // MARK: Maintenance Section
                    maintenanceSection

                    Divider()

                    // MARK: Transactions (placeholder)
                    transactionsSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: appState.reloadToken) {
            await loadAll()
        }
    }

    // MARK: - Connectivity

    @ViewBuilder
    private var connectivitySection: some View {
        HStack {
            Text("Connectivity")
                .font(.headline)
            Spacer()
            Button("Ping") {
                Task { await runPing() }
            }
        }

        if let result = pingResult {
            Text(result).foregroundStyle(.green).font(.callout)
        }
        if let error = pingError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Configuration

    @ViewBuilder
    private var configurationSection: some View {
        HStack {
            Text("Configuration")
                .font(.headline)
            Spacer()
            Button("Load Config") {
                Task { await loadConfig() }
            }
        }

        if let error = configError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let json = configJSON {
            GroupBox {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        HStack(spacing: 16) {
            Text("Auto-Embed:")
                .font(.callout)
            if let enabled = autoEmbedEnabled {
                Text(enabled ? "Enabled" : "Disabled")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(enabled ? .green : .secondary)

                Button(enabled ? "Disable" : "Enable") {
                    Task { await setAutoEmbed(!enabled) }
                }
            } else {
                Text("Unknown")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Check Status") {
                Task { await loadAutoEmbedStatus() }
            }
        }

        if let error = autoEmbedError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Retention

    @ViewBuilder
    private var retentionSection: some View {
        HStack {
            Text("Retention / GC")
                .font(.headline)
            Spacer()
        }

        HStack(spacing: 12) {
            Button("Run GC (RetentionApply)") {
                Task { await runRetention() }
            }
            Button("Stats") {
                Task { await loadRetentionStats() }
            }
            Button("Preview") {
                Task { await loadRetentionPreview() }
            }
        }

        if let msg = retentionMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let error = retentionError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let stats = retentionStats {
            GroupBox("Retention Stats") {
                Text(stats)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let preview = retentionPreview {
            GroupBox("Retention Preview") {
                Text(preview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Maintenance

    @ViewBuilder
    private var maintenanceSection: some View {
        HStack {
            Text("Maintenance")
                .font(.headline)
            Spacer()
        }

        HStack(spacing: 12) {
            Button("Flush") {
                Task { await runFlush() }
            }

            Button("Compact") {
                Task { await runCompact() }
            }

            Button("Durability Counters") {
                Task { await loadDurabilityCounters() }
            }
        }

        if let msg = flushMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let msg = compactMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let error = maintenanceError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let counters = durabilityCounters {
            GroupBox("WAL / Durability Counters") {
                Text(counters)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if let error = durabilityError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Transactions (placeholder)

    @ViewBuilder
    private var transactionsSection: some View {
        HStack {
            Text("Transactions")
                .font(.headline)
            Spacer()
            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }

        Text("Transaction commands (Begin, Commit, Rollback, Info, IsActive) are not yet implemented in the executor.")
            .font(.callout)
            .foregroundStyle(.secondary)

        HStack(spacing: 12) {
            Button("Begin") {}
                .disabled(true)
            Button("Commit") {}
                .disabled(true)
            Button("Rollback") {}
                .disabled(true)
            Button("Info") {}
                .disabled(true)
        }
    }

    // MARK: - API Operations

    private func loadAll() async {
        await runPing()
        await loadConfig()
        await loadAutoEmbedStatus()
        await loadDurabilityCounters()
    }

    private func runPing() async {
        guard let client = appState.client else { return }
        pingResult = nil
        pingError = nil
        do {
            let json = try await client.executeRaw("{\"Ping\": null}")
            if let data = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pong = root["Pong"] as? String {
                pingResult = "Pong: \(pong)"
            } else {
                pingResult = "Connected"
            }
        } catch {
            pingError = error.localizedDescription
        }
    }

    private func loadConfig() async {
        guard let client = appState.client else { return }
        configJSON = nil
        configError = nil
        do {
            let json = try await client.executeRaw("{\"ConfigGet\": {}}")
            if let data = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let config = root["Config"] as? [String: Any] {
                let prettyData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
                configJSON = String(data: prettyData, encoding: .utf8)
            } else {
                configJSON = json
            }
        } catch {
            configError = error.localizedDescription
        }
    }

    private func loadAutoEmbedStatus() async {
        guard let client = appState.client else { return }
        autoEmbedError = nil
        do {
            let json = try await client.executeRaw("{\"AutoEmbedStatus\": {}}")
            if let data = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = root["Bool"] as? Bool {
                autoEmbedEnabled = status
            } else {
                autoEmbedError = "Could not parse auto-embed status"
            }
        } catch {
            autoEmbedError = error.localizedDescription
        }
    }

    private func setAutoEmbed(_ enabled: Bool) async {
        guard let client = appState.client else { return }
        autoEmbedError = nil
        do {
            let wrapper: [String: Any] = ["ConfigSetAutoEmbed": ["enabled": enabled]]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            autoEmbedEnabled = enabled
        } catch {
            autoEmbedError = error.localizedDescription
        }
    }

    private func runRetention() async {
        guard let client = appState.client else { return }
        retentionMessage = nil
        retentionError = nil
        retentionStats = nil
        retentionPreview = nil
        do {
            _ = try await client.executeRaw("{\"RetentionApply\": {}}")
            retentionMessage = "GC completed."
        } catch {
            retentionError = error.localizedDescription
        }
    }

    private func loadRetentionStats() async {
        guard let client = appState.client else { return }
        retentionStats = nil
        retentionError = nil
        do {
            let json = try await client.executeRaw("{\"RetentionStats\": {}}")
            if let data = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Try to extract structured data, fall back to raw
                if let stats = root["RetentionStats"] as? [String: Any] {
                    let prettyData = try JSONSerialization.data(withJSONObject: stats, options: [.prettyPrinted, .sortedKeys])
                    retentionStats = String(data: prettyData, encoding: .utf8)
                } else {
                    retentionStats = json
                }
            } else {
                retentionStats = json
            }
        } catch {
            retentionError = error.localizedDescription
        }
    }

    private func loadRetentionPreview() async {
        guard let client = appState.client else { return }
        retentionPreview = nil
        retentionError = nil
        do {
            let json = try await client.executeRaw("{\"RetentionPreview\": {}}")
            if let data = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let preview = root["RetentionPreview"] as? [String: Any] {
                    let prettyData = try JSONSerialization.data(withJSONObject: preview, options: [.prettyPrinted, .sortedKeys])
                    retentionPreview = String(data: prettyData, encoding: .utf8)
                } else {
                    retentionPreview = json
                }
            } else {
                retentionPreview = json
            }
        } catch {
            retentionError = error.localizedDescription
        }
    }

    private func runFlush() async {
        guard let client = appState.client else { return }
        flushMessage = nil
        compactMessage = nil
        maintenanceError = nil
        do {
            _ = try await client.executeRaw("{\"Flush\": {}}")
            flushMessage = "Flush completed."
        } catch {
            maintenanceError = error.localizedDescription
        }
    }

    private func runCompact() async {
        guard let client = appState.client else { return }
        flushMessage = nil
        compactMessage = nil
        maintenanceError = nil
        do {
            _ = try await client.executeRaw("{\"Compact\": {}}")
            compactMessage = "Compaction completed."
        } catch {
            maintenanceError = error.localizedDescription
        }
    }

    private func loadDurabilityCounters() async {
        guard let client = appState.client else { return }
        durabilityCounters = nil
        durabilityError = nil
        do {
            let json = try await client.executeRaw("{\"DurabilityCounters\": {}}")
            if let data = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let counters = root["DurabilityCounters"] as? [String: Any] {
                let prettyData = try JSONSerialization.data(withJSONObject: counters, options: [.prettyPrinted, .sortedKeys])
                durabilityCounters = String(data: prettyData, encoding: .utf8)
            } else {
                durabilityCounters = json
            }
        } catch {
            durabilityError = error.localizedDescription
        }
    }
}
