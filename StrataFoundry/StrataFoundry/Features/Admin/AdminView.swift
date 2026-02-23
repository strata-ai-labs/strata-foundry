//
//  AdminView.swift
//  StrataFoundry
//
//  Thin view observing AdminFeatureModel — all business logic delegated to model.
//

import SwiftUI

struct AdminView: View {
    @Environment(AppState.self) private var appState
    @State private var model: AdminFeatureModel?

    var body: some View {
        VStack(spacing: 0) {
            if let model {
                // MARK: Header
                HStack {
                    Text("Admin")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Button {
                        Task { await model.loadAll() }
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
                        connectivitySection(model)

                        Divider()

                        // MARK: Configuration Section
                        configurationSection(model)

                        Divider()

                        // MARK: Retention Section
                        retentionSection(model)

                        Divider()

                        // MARK: Maintenance Section
                        maintenanceSection(model)

                        Divider()

                        // MARK: Transactions (placeholder)
                        transactionsSection
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = AdminFeatureModel(adminService: services.adminService, appState: appState)
            }
            await model?.loadAll()
        }
    }

    // MARK: - Connectivity

    @ViewBuilder
    private func connectivitySection(_ model: AdminFeatureModel) -> some View {
        HStack {
            Text("Connectivity")
                .font(.headline)
            Spacer()
            Button("Ping") {
                Task { await model.runPing() }
            }
        }

        if let result = model.pingResult {
            Text(result).foregroundStyle(.green).font(.callout)
        }
        if let error = model.pingError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Configuration

    @ViewBuilder
    private func configurationSection(_ model: AdminFeatureModel) -> some View {
        HStack {
            Text("Configuration")
                .font(.headline)
            Spacer()
            Button("Load Config") {
                Task { await model.loadConfig() }
            }
        }

        if let error = model.configError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let json = model.configJSON {
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
            if let enabled = model.autoEmbedEnabled {
                Text(enabled ? "Enabled" : "Disabled")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(enabled ? .green : .secondary)

                Button(enabled ? "Disable" : "Enable") {
                    Task { await model.setAutoEmbed(!enabled) }
                }
            } else {
                Text("Unknown")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Check Status") {
                Task { await model.loadAutoEmbedStatus() }
            }
        }

        if let error = model.autoEmbedError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Retention

    @ViewBuilder
    private func retentionSection(_ model: AdminFeatureModel) -> some View {
        HStack {
            Text("Retention / GC")
                .font(.headline)
            Spacer()
        }

        HStack(spacing: 12) {
            Button("Run GC (RetentionApply)") {
                Task { await model.runRetention() }
            }
            Button("Stats") {
                Task { await model.loadRetentionStats() }
            }
            Button("Preview") {
                Task { await model.loadRetentionPreview() }
            }
        }

        if let msg = model.retentionMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let error = model.retentionError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let stats = model.retentionStats {
            GroupBox("Retention Stats") {
                Text(stats)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let preview = model.retentionPreview {
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
    private func maintenanceSection(_ model: AdminFeatureModel) -> some View {
        HStack {
            Text("Maintenance")
                .font(.headline)
            Spacer()
        }

        HStack(spacing: 12) {
            Button("Flush") {
                Task { await model.runFlush() }
            }

            Button("Compact") {
                Task { await model.runCompact() }
            }

            Button("Durability Counters") {
                Task { await model.loadDurabilityCounters() }
            }
        }

        if let msg = model.flushMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let msg = model.compactMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let error = model.maintenanceError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let counters = model.durabilityCounters {
            GroupBox("WAL / Durability Counters") {
                Text(counters)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if let error = model.durabilityError {
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
}
