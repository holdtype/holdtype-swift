//
//  OpenAIUsageEstimate.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import Foundation
import HoldTypeDomain

typealias OpenAIUsageEvent = TranscriptionUsageEvent
typealias OpenAIUsagePricing = TranscriptionUsagePricing
typealias OpenAIUsageDailyBucket = TranscriptionUsageDailyBucket
typealias OpenAIUsageSummary = TranscriptionUsageSummary

extension OpenAIUsageSummary {
    static func empty() -> OpenAIUsageSummary {
        .empty(
            now: Date(),
            calendar: .current,
            windowDays: defaultWindowDays
        )
    }
}
