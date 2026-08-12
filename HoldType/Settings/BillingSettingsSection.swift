import Charts
import HoldTypeDomain
import HoldTypeOpenAI
import SwiftUI

struct BillingSettingsSection: View {
    let summary: OpenAIUsageSummary
    let storageErrorMessage: String?
    let estimateNoticeMessage: String?
    let onResetUsage: () -> Void

    @State private var selectedMetric: BillingChartMetric = .cost
    @State private var isShowingResetConfirmation = false

    var body: some View {
        Section("OpenAI Usage Estimate") {
            Text("Successful OpenAI requests made by HoldType on this Mac.")
                .foregroundStyle(.secondary)

            if let storageErrorMessage {
                Label(storageErrorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            if let estimateNoticeMessage {
                Label(estimateNoticeMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if summary.isEmpty {
                Label(
                    "Usage appears after successful OpenAI requests.",
                    systemImage: "chart.bar"
                )
                .foregroundStyle(.secondary)
            } else {
                BillingCostSummary(summary: summary)
                if summary.hasUnpricedUsage { BillingPartialCostWarning() }
                BillingUsageChart(summary: summary, selectedMetric: $selectedMetric)
                BillingCategoryBreakdown(summary: summary)
                if summary.hasTextUsage {
                    BillingUsageDetails(summary: summary)
                }
            }

            Text("Local estimate only. Actual OpenAI billing may differ.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Reset Usage Estimate", role: .destructive) {
                isShowingResetConfirmation = true
            }
            .disabled(summary.isEmpty && storageErrorMessage == nil && estimateNoticeMessage == nil)
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

private struct BillingCostSummary: View {
    let summary: OpenAIUsageSummary

    var body: some View {
        LabeledContent("Today", value: BillingUsageFormatter.cost(summary.todayEstimatedCostUSD))
        LabeledContent(
            "Last 30 days",
            value: BillingUsageFormatter.cost(summary.totalEstimatedCostUSD)
        )
        LabeledContent(
            "Average per day",
            value: BillingUsageFormatter.cost(summary.averageDailyCostUSD)
        )
        LabeledContent(
            "Estimated 30-day cost",
            value: BillingUsageFormatter.cost(summary.projected30DayCostUSD)
        )
    }
}

private struct BillingPartialCostWarning: View {
    var body: some View {
        Label(
            "Some requests use models without local pricing, so cost is partial.",
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

        if chartPoints.isEmpty {
            ContentUnavailableView {
                Label(selectedMetric.emptyTitle, systemImage: selectedMetric.emptySystemImage)
            } description: {
                Text(selectedMetric.emptyDescription)
            }
            .frame(height: 160)
        } else {
            Chart(chartPoints) { point in
                BarMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value(selectedMetric.title, point.value)
                )
                .foregroundStyle(by: .value("Category", point.category.title))
                .accessibilityLabel("\(point.category.title), \(point.day.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityValue(selectedMetric.formatted(point.value))
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
            .frame(height: 200)
        }
    }

    private var chartPoints: [BillingChartPoint] {
        summary.dailyBuckets.flatMap { bucket in
            OpenAIUsageCategory.allCases.compactMap { category in
                guard let metrics = bucket.categories[category],
                      let value = selectedMetric.value(for: metrics, category: category),
                      value > 0 else { return nil }
                return BillingChartPoint(day: bucket.day, category: category, value: value)
            }
        }
    }
}

private struct BillingCategoryBreakdown: View {
    let summary: OpenAIUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By feature").font(.headline)
            ForEach(OpenAIUsageCategory.allCases) { category in
                if let metrics = summary.categories[category], metrics.requestCount > 0 {
                    LabeledContent(category.title) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(BillingUsageFormatter.costLine(metrics))
                            Text(BillingUsageFormatter.primaryMeasurement(metrics, category: category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BillingUsageDetails: View {
    let summary: OpenAIUsageSummary

    var body: some View {
        DisclosureGroup("Usage details") {
            ForEach(OpenAIUsageCategory.allCases) { category in
                if let metrics = summary.categories[category], metrics.textTokens > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title).font(.subheadline.weight(.medium))
                        LabeledContent("Input", value: BillingUsageFormatter.tokens(metrics.inputTokens))
                        LabeledContent("Cached input", value: BillingUsageFormatter.tokens(metrics.cachedInputTokens))
                        LabeledContent("Output", value: BillingUsageFormatter.tokens(metrics.outputTokens))
                        LabeledContent("Reasoning", value: BillingUsageFormatter.tokens(metrics.reasoningTokens))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct BillingChartPoint: Identifiable {
    let day: Date
    let category: OpenAIUsageCategory
    let value: Double
    var id: String { "\(day.timeIntervalSinceReferenceDate)-\(category.rawValue)" }
}

private enum BillingUsageFormatter {
    static func cost(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        if value > 0 && value < 0.01 { return String(format: "$%.4f", value) }
        return String(format: "$%.2f", value)
    }

    static func costLine(_ metrics: OpenAIUsageCategoryMetrics) -> String {
        guard metrics.pricedRequestCount > 0 else { return "Unavailable" }
        let formatted = cost(metrics.estimatedCostUSD)
        return metrics.hasUnpricedUsage ? "\(formatted) partial" : formatted
    }

    static func primaryMeasurement(
        _ metrics: OpenAIUsageCategoryMetrics,
        category: OpenAIUsageCategory
    ) -> String {
        let requests = metrics.requestCount == 1 ? "1 request" : "\(metrics.requestCount) requests"
        if category == .transcription {
            return "\(minutes(metrics.audioDurationSeconds)) · \(requests)"
        }
        return "\(tokens(metrics.textTokens)) tokens · \(requests)"
    }

    static func minutes(_ seconds: TimeInterval) -> String {
        let value = seconds / 60
        return value < 100 ? String(format: "%.1f min", value) : String(format: "%.0f min", value)
    }

    static func tokens(_ value: Int) -> String { value.formatted() }
}

private enum BillingChartMetric: String, CaseIterable, Identifiable {
    case cost
    case audio
    case text

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var emptyTitle: String {
        switch self {
        case .cost: return "No priced usage"
        case .audio: return "No audio usage"
        case .text: return "No text usage"
        }
    }

    var emptyDescription: String {
        switch self {
        case .cost: return "Cost appears when a recorded model has local pricing."
        case .audio: return "Audio appears after a successful transcription."
        case .text: return "Text appears after a successful Fix, correction, or translation."
        }
    }

    var emptySystemImage: String {
        switch self {
        case .cost: return "dollarsign"
        case .audio: return "waveform"
        case .text: return "text.word.spacing"
        }
    }

    func value(
        for metrics: OpenAIUsageCategoryMetrics,
        category: OpenAIUsageCategory
    ) -> Double? {
        switch self {
        case .cost: return metrics.pricedRequestCount > 0 ? metrics.estimatedCostUSD : nil
        case .audio: return category == .transcription ? metrics.audioDurationSeconds / 60 : nil
        case .text: return category == .transcription ? nil : Double(metrics.textTokens)
        }
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .cost: return BillingUsageFormatter.cost(value)
        case .audio: return String(format: "%.1f minutes", value)
        case .text: return "\(Int(value).formatted()) tokens"
        }
    }
}

#Preview("Mixed Usage") {
    Form {
        BillingSettingsSection(
            summary: .previewUsage,
            storageErrorMessage: nil,
            estimateNoticeMessage: nil,
            onResetUsage: {}
        )
    }
    .formStyle(.grouped)
    .padding()
}

#Preview("Empty Usage") {
    Form {
        BillingSettingsSection(
            summary: .empty(),
            storageErrorMessage: nil,
            estimateNoticeMessage: nil,
            onResetUsage: {}
        )
    }
    .formStyle(.grouped)
    .padding()
}

private extension OpenAIUsageSummary {
    static var previewUsage: OpenAIUsageSummary {
        let now = Date()
        let transcription = try? OpenAIUsagePricing.current.makeEvent(
            timestamp: now,
            model: "gpt-transcribe",
            durationSeconds: 420
        )
        let textUsage = try? OpenAITextResponseUsage(
            model: "gpt-5.4-mini",
            inputTokens: 1_200,
            cachedInputTokens: 200,
            outputTokens: 500,
            reasoningTokens: 100
        )
        var events = transcription.map { [OpenAIUsageEvent(transcription: $0)] } ?? []
        if let textUsage {
            events.append(OpenAIUsageEvent(timestamp: now, category: .fixes, usage: textUsage))
        }
        return .make(events: events, now: now)
    }
}
