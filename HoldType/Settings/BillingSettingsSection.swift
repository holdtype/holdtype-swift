//
//  BillingSettingsSection.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import Charts
import SwiftUI

struct BillingSettingsSection: View {
    let summary: OpenAIUsageSummary
    let storageErrorMessage: String?
    let onResetUsage: () -> Void

    @State private var selectedMetric: BillingChartMetric = .cost
    @State private var isShowingResetConfirmation = false

    var body: some View {
        Section("OpenAI Usage Estimate") {
            BillingStorageErrorMessage(message: storageErrorMessage)

            BillingUsageContent(
                summary: summary,
                selectedMetric: $selectedMetric
            )

            BillingEstimateFootnote()

            BillingResetUsageButton(isDisabled: summary.isEmpty) {
                isShowingResetConfirmation = true
            }
        }
        .confirmationDialog(
            "Reset OpenAI usage estimate?",
            isPresented: $isShowingResetConfirmation
        ) {
            Button("Reset Usage Estimate", role: .destructive, action: onResetUsage)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct BillingStorageErrorMessage: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}

private struct BillingUsageContent: View {
    let summary: OpenAIUsageSummary
    @Binding var selectedMetric: BillingChartMetric

    var body: some View {
        if summary.isEmpty {
            BillingUsageEmptyState()
        } else {
            BillingUsageSummaryRows(summary: summary)

            if summary.hasUnpricedUsage {
                BillingPartialCostWarning()
            }

            BillingUsageChart(
                summary: summary,
                selectedMetric: $selectedMetric
            )
        }
    }
}

private struct BillingUsageEmptyState: View {
    var body: some View {
        Label("Usage estimate appears after successful transcriptions.", systemImage: "chart.bar")
            .foregroundStyle(.secondary)
    }
}

private struct BillingUsageSummaryRows: View {
    let summary: OpenAIUsageSummary

    var body: some View {
        LabeledContent("Today", value: BillingUsageFormatter.usageLine(
            durationSeconds: summary.todayDurationSeconds,
            costUSD: summary.todayEstimatedCostUSD
        ))

        LabeledContent("Average per day", value: BillingUsageFormatter.usageLine(
            durationSeconds: summary.averageDailyDurationSeconds,
            costUSD: summary.averageDailyCostUSD
        ))

        LabeledContent("Last 30 days", value: BillingUsageFormatter.usageLine(
            durationSeconds: summary.totalDurationSeconds,
            costUSD: summary.totalEstimatedCostUSD
        ))

        LabeledContent(
            "Estimated 30-day cost",
            value: BillingUsageFormatter.cost(summary.projected30DayCostUSD)
        )
    }
}

private struct BillingPartialCostWarning: View {
    var body: some View {
        Label(
            "Some recorded minutes use models without local pricing, so cost is partial.",
            systemImage: "exclamationmark.triangle"
        )
        .foregroundStyle(.orange)
    }
}

private struct BillingUsageChart: View {
    let summary: OpenAIUsageSummary
    @Binding var selectedMetric: BillingChartMetric

    var body: some View {
        Picker("Chart", selection: $selectedMetric) {
            ForEach(BillingChartMetric.allCases) { metric in
                Text(metric.title).tag(metric)
            }
        }
        .pickerStyle(.segmented)

        Chart(summary.dailyBuckets) { bucket in
            BarMark(
                x: .value("Day", bucket.day, unit: .day),
                y: .value(selectedMetric.title, selectedMetric.value(for: bucket))
            )
            .foregroundStyle(chartColor(for: bucket))
        }
        .frame(height: 180)
    }

    private func chartColor(for bucket: OpenAIUsageDailyBucket) -> Color {
        if selectedMetric == .cost && bucket.hasUnpricedUsage {
            return .orange
        }

        return .accentColor
    }
}

private struct BillingEstimateFootnote: View {
    var body: some View {
        Text("Estimate only. Actual OpenAI billing may differ.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

private struct BillingResetUsageButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button("Reset Usage Estimate", role: .destructive, action: action)
            .disabled(isDisabled)
    }
}

private enum BillingUsageFormatter {
    static func usageLine(durationSeconds: TimeInterval, costUSD: Double?) -> String {
        "\(minutes(durationSeconds)) / \(cost(costUSD))"
    }

    static func minutes(_ durationSeconds: TimeInterval) -> String {
        let minutes = durationSeconds / 60

        if minutes == 0 {
            return "0 min"
        }

        if minutes < 100 {
            return String(format: "%.1f min", minutes)
        }

        return String(format: "%.0f min", minutes)
    }

    static func cost(_ costUSD: Double?) -> String {
        guard let costUSD else {
            return "Unavailable"
        }

        if costUSD > 0 && costUSD < 0.01 {
            return String(format: "$%.4f", costUSD)
        }

        return String(format: "$%.2f", costUSD)
    }
}

private enum BillingChartMetric: String, CaseIterable, Identifiable {
    case cost
    case minutes

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .cost:
            return "Cost"
        case .minutes:
            return "Minutes"
        }
    }

    func value(for bucket: OpenAIUsageDailyBucket) -> Double {
        switch self {
        case .cost:
            return bucket.estimatedCostUSD
        case .minutes:
            return bucket.minutes
        }
    }
}

#Preview("Billing Usage") {
    Form {
        BillingSettingsSection(
            summary: .previewUsage,
            storageErrorMessage: nil,
            onResetUsage: {}
        )
    }
    .formStyle(.grouped)
    .padding()
}

#Preview("Billing Empty") {
    Form {
        BillingSettingsSection(
            summary: .empty(),
            storageErrorMessage: nil,
            onResetUsage: {}
        )
    }
    .formStyle(.grouped)
    .padding()
}

private extension OpenAIUsageSummary {
    static var previewUsage: OpenAIUsageSummary {
        let pricing = OpenAIUsagePricing.current
        let now = Date()
        let calendar = Calendar.current
        let events = [
            pricing.makeEvent(model: "gpt-4o-transcribe", durationSeconds: 420),
            pricing.makeEvent(
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                model: "gpt-4o-mini-transcribe",
                durationSeconds: 960
            ),
            pricing.makeEvent(
                timestamp: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                model: "custom-model",
                durationSeconds: 180
            ),
        ]

        return OpenAIUsageSummary.make(events: events, now: now, calendar: calendar)
    }
}
