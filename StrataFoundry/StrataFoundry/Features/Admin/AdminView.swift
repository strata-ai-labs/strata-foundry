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
        Group {
            if let model {
                adminContent(model)
            } else {
                SkeletonLoadingView()
            }
        }
        .navigationTitle("Admin")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await model?.loadAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = AdminFeatureModel(adminService: services.adminService, appState: appState)
            }
            await model?.loadAll()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func adminContent(_ model: AdminFeatureModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StrataSpacing.lg) {
                connectivitySection(model)
                Divider()
                configurationSection(model)
                Divider()
                retentionSection(model)
                Divider()
                maintenanceSection(model)
                Divider()
                transactionsSection
            }
            .padding(StrataSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Connectivity

    @ViewBuilder
    private func connectivitySection(_ model: AdminFeatureModel) -> some View {
        HStack {
            Text("Connectivity")
                .strataSectionHeader()
            Spacer()

            if let result = model.pingResult {
                HStack(spacing: StrataSpacing.xxs) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(result)
                        .font(.callout)
                        .foregroundStyle(.green)
                }
            }
            if let error = model.pingError {
                HStack(spacing: StrataSpacing.xxs) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Button("Ping") {
                Task { await model.runPing() }
            }
        }
    }

    // MARK: - Configuration

    @ViewBuilder
    private func configurationSection(_ model: AdminFeatureModel) -> some View {
        HStack {
            Text("Configuration")
                .strataSectionHeader()
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
                    .strataCodeStyle()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        HStack(spacing: StrataSpacing.md) {
            Text("Auto-Embed:")
                .font(.callout)
            if let enabled = model.autoEmbedEnabled {
                HStack(spacing: StrataSpacing.xxs) {
                    Circle()
                        .fill(enabled ? .green : .secondary)
                        .frame(width: 8, height: 8)
                    Text(enabled ? "Enabled" : "Disabled")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(enabled ? .green : .secondary)
                }

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
                .strataSectionHeader()
            Spacer()
        }

        HStack(spacing: StrataSpacing.sm) {
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
                    .strataCodeStyle()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let preview = model.retentionPreview {
            GroupBox("Retention Preview") {
                Text(preview)
                    .strataCodeStyle()
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
                .strataSectionHeader()
            Spacer()
        }

        HStack(spacing: StrataSpacing.sm) {
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
                    .strataCodeStyle()
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
                .strataSectionHeader()
            Spacer()
            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, StrataSpacing.xs)
                .padding(.vertical, StrataSpacing.xxs)
                .background(.quaternary, in: Capsule())
        }

        Text("Transaction commands (Begin, Commit, Rollback, Info, IsActive) are not yet implemented in the executor.")
            .strataSecondaryStyle()

        HStack(spacing: StrataSpacing.sm) {
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
