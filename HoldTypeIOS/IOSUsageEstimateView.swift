import Charts
import Foundation
import HoldTypeDomain
import SwiftUI

struct IOSUsageEstimateView: View {
    @Environment(IOSUsageEstimateStateOwner.self)
    private var stateOwner
    @State private var selectedMetric = IOSUsageChartMetric.cost
    @State private var showsResetConfirmation = false

    var body: some View {
        Group {
            switch stateOwner.state {
            case .notLoaded:
                IOSDestinationLoadingView(
                    title: "Loading Usage Estimate"
                )
            case .loadFailed(lastConfirmed: nil),
                 .resetFailed(lastConfirmed: nil):
                unavailableContent
            case .ready(let summary),
                 .loadFailed(lastConfirmed: .some(let summary)),
                 .resetFailed(lastConfirmed: .some(let summary)):
                usageList(summary)
            }
        }
        .navigationTitle("Transcription Usage Estimate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshToolbarItem
            }
        }
        .task {
            await stateOwner.refresh()
        }
        .confirmationDialog(
            "Reset Usage Estimate?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Usage Estimate", role: .destructive) {
                Task { await stateOwner.reset() }
            }
            .disabled(!stateOwner.canReset || stateOwner.isBusy)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This removes only the estimate on this iPhone. It does not "
                    + "change OpenAI billing or other HoldType data."
            )
        }
        .accessibilityIdentifier("ios.settings.usage-estimate")
    }

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label(
                "Usage Estimate Unavailable",
                systemImage: "chart.bar.xaxis"
            )
        } description: {
            VStack(spacing: 12) {
                Text(unavailableMessage)
                if let notice = stateOwner.notice {
                    Label {
                        Text(notice.message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .accessibilityIdentifier("ios.usage.write-warning")
                }
            }
        } actions: {
            Button("Try Again") {
                Task { await stateOwner.refresh() }
            }
            .disabled(stateOwner.isBusy)

            Button("Reset Usage Estimate", role: .destructive) {
                showsResetConfirmation = true
            }
            .disabled(!stateOwner.canReset || stateOwner.isBusy)
            .accessibilityIdentifier("ios.usage.reset")

            if stateOwner.notice != nil {
                Button("Dismiss Usage Warning") {
                    stateOwner.dismissNotice()
                }
                .accessibilityIdentifier(
                    "ios.usage.write-warning.dismiss"
                )
            }
        }
    }

    private var unavailableMessage: String {
        if case .resetFailed(lastConfirmed: nil) = stateOwner.state {
            return "HoldType couldn’t reset the estimate. Try again."
        }
        return "HoldType couldn’t load the estimate. Try again."
    }

    @ViewBuilder
    private var refreshToolbarItem: some View {
        if stateOwner.isBusy {
            ProgressView()
                .accessibilityLabel(
                    stateOwner.operation.isResetting
                        ? "Resetting usage estimate"
                        : "Refreshing usage estimate"
                )
        } else {
            Button {
                Task { await stateOwner.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("ios.usage.refresh")
        }
    }

    private func usageList(
        _ summary: TranscriptionUsageSummary
    ) -> some View {
        List {
            if let notice = stateOwner.notice {
                Section {
                    Label {
                        Text(notice.message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .accessibilityIdentifier("ios.usage.write-warning")

                    Button("Dismiss") {
                        stateOwner.dismissNotice()
                    }
                    .accessibilityIdentifier(
                        "ios.usage.write-warning.dismiss"
                    )
                }
            }

            if case .loadFailed = stateOwner.state {
                IOSUsageLocalFailureSection(
                    message:
                        "The estimate couldn’t be refreshed. The last "
                        + "confirmed summary remains visible."
                )
            }
            if case .resetFailed = stateOwner.state {
                IOSUsageLocalFailureSection(
                    message:
                        "The estimate couldn’t be reset. The last confirmed "
                        + "summary remains visible."
                )
            }

            if summary.isEmpty {
                Section {
                    Label(
                        "An estimate appears after successful "
                            + "transcriptions on this device.",
                        systemImage: "chart.bar"
                    )
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ios.usage.empty")
                }
            } else {
                IOSUsageSummarySection(summary: summary)

                if summary.hasUnpricedUsage {
                    IOSUsagePricingWarning(summary: summary)
                }

                IOSUsageChartSection(
                    summary: summary,
                    selectedMetric: $selectedMetric
                )
            }

            Section {
                Text(
                    "Estimated from successful transcriptions on this iPhone. "
                        + "Your OpenAI bill may differ. "
                        + "Correction and translation are not included."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Button("Reset Usage Estimate", role: .destructive) {
                    showsResetConfirmation = true
                }
                .disabled(!stateOwner.canReset || stateOwner.isBusy)
                .accessibilityIdentifier("ios.usage.reset")
            }
        }
        .refreshable {
            guard !stateOwner.isBusy else { return }
            await stateOwner.refresh()
        }
    }
}

private struct IOSUsageLocalFailureSection: View {
    let message: String

    var body: some View {
        Section {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .accessibilityIdentifier("ios.usage.local-failure")
        }
    }
}

private struct IOSUsageSummarySection: View {
    let summary: TranscriptionUsageSummary

    var body: some View {
        Section("Estimate") {
            IOSUsageSummaryRow(
                title: "Today",
                value: IOSUsageEstimateFormatter.usageLine(
                    durationSeconds: summary.todayDurationSeconds,
                    costUSD: summary.todayEstimatedCostUSD
                )
            )
            IOSUsageSummaryRow(
                title: "Average per day",
                value: IOSUsageEstimateFormatter.usageLine(
                    durationSeconds: summary.averageDailyDurationSeconds,
                    costUSD: summary.averageDailyCostUSD
                )
            )
            IOSUsageSummaryRow(
                title: "Last 30 days",
                value: IOSUsageEstimateFormatter.usageLine(
                    durationSeconds: summary.totalDurationSeconds,
                    costUSD: summary.totalEstimatedCostUSD
                )
            )
            IOSUsageSummaryRow(
                title: "Estimated 30-day cost",
                value: IOSUsageEstimateFormatter.cost(
                    summary.projected30DayCostUSD
                )
            )
        }
    }
}

private struct IOSUsageSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer(minLength: 12)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(value)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

private struct IOSUsagePricingWarning: View {
    let summary: TranscriptionUsageSummary

    var body: some View {
        Section {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .accessibilityIdentifier("ios.usage.pricing-warning")
        }
    }

    private var message: String {
        if summary.totalEstimatedCostUSD == nil {
            return "Cost is unavailable because the local price is unknown "
                + "for every recorded model. Minutes remain complete."
        }
        return "Cost is partial because some recorded minutes use models "
            + "without a known local price."
    }
}

private struct IOSUsageChartSection: View {
    let summary: TranscriptionUsageSummary
    @Binding var selectedMetric: IOSUsageChartMetric

    var body: some View {
        Section("Daily") {
            Picker("Chart metric", selection: $selectedMetric) {
                ForEach(IOSUsageChartMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("ios.usage.chart-metric")

            Chart(summary.dailyBuckets) { bucket in
                BarMark(
                    x: .value("Day", bucket.day, unit: .day),
                    y: .value(
                        selectedMetric.title,
                        selectedMetric.value(for: bucket)
                    )
                )
                .foregroundStyle(
                    selectedMetric == .cost && bucket.hasUnpricedUsage
                        ? Color.orange
                        : Color.accentColor
                )
                .accessibilityLabel(
                    Text(
                        bucket.day.formatted(
                            date: .abbreviated,
                            time: .omitted
                        )
                    )
                )
                .accessibilityValue(
                    Text(selectedMetric.accessibilityValue(for: bucket))
                )
            }
            .frame(minHeight: 210)
            .accessibilityIdentifier("ios.usage.chart")
        }
        .onChange(
            of: summary.totalEstimatedCostUSD,
            initial: true
        ) { _, cost in
            if cost == nil {
                selectedMetric = .minutes
            }
        }
    }
}

enum IOSUsageChartMetric: String, CaseIterable, Identifiable, Sendable {
    case cost
    case minutes

    var id: Self { self }

    var title: String {
        switch self {
        case .cost:
            "Cost"
        case .minutes:
            "Minutes"
        }
    }

    func value(for bucket: TranscriptionUsageDailyBucket) -> Double {
        switch self {
        case .cost:
            bucket.estimatedCostUSD
        case .minutes:
            bucket.minutes
        }
    }

    func accessibilityValue(
        for bucket: TranscriptionUsageDailyBucket
    ) -> String {
        switch self {
        case .cost:
            if bucket.hasUnpricedUsage, bucket.estimatedCostUSD == 0 {
                return "Cost unavailable"
            }
            let value = IOSUsageEstimateFormatter.cost(
                bucket.estimatedCostUSD
            )
            return bucket.hasUnpricedUsage ? "\(value), partial" : value
        case .minutes:
            return IOSUsageEstimateFormatter.minutes(
                bucket.durationSeconds
            )
        }
    }
}

enum IOSUsageEstimateFormatter {
    static func usageLine(
        durationSeconds: TimeInterval,
        costUSD: Double?
    ) -> String {
        "\(minutes(durationSeconds)) · \(cost(costUSD))"
    }

    static func minutes(_ durationSeconds: TimeInterval) -> String {
        let minutes = durationSeconds / 60
        if minutes == 0 { return "0 min" }
        if minutes > 0, minutes < 0.1 { return "<0.1 min" }
        if minutes < 100 {
            return String(format: "%.1f min", minutes)
        }
        return String(format: "%.0f min", minutes)
    }

    static func cost(_ costUSD: Double?) -> String {
        guard let costUSD else { return "Unavailable" }
        if costUSD > 0, costUSD < 0.0001 { return "<$0.0001" }
        if costUSD > 0, costUSD < 0.01 {
            return String(format: "$%.4f", costUSD)
        }
        return String(format: "$%.2f", costUSD)
    }
}
