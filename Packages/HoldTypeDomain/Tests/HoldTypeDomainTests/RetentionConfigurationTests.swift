import Testing
import HoldTypeDomain

struct RetentionConfigurationTests {
    @Test func defaultsMatchTheRetentionContract() {
        let configuration = RetentionConfiguration()

        #expect(configuration == .defaults)
        #expect(configuration.historyEnabled)
        #expect(configuration.recordingCachePolicy == .deleteImmediately)
        #expect(configuration.recordingCachePolicy.keepsRecordings == false)
        #expect(RetentionConfiguration.acceptedHistoryEntryLimit == 20)
        #expect(RetentionConfiguration.failedHistoryEntryLimit == 5)
        #expect(RecordingCachePolicy.defaultRetainedRecordingLimit == 10)
        #expect(RecordingCachePolicy.maximumRetainedRecordingLimit == 999)
    }

    @Test func everyPolicyReportsWhetherItKeepsCompletedRecordings() {
        #expect(RecordingCachePolicy.deleteImmediately.keepsRecordings == false)
        #expect(RecordingCachePolicy.keepLast(0).keepsRecordings)
        #expect(RecordingCachePolicy.keepLast(10).keepsRecordings)
        #expect(RecordingCachePolicy.unlimited.keepsRecordings)
    }

    @Test func keepLastNormalizationClampsEveryIntegerBoundary() {
        #expect(RecordingCachePolicy.keepLast(Int.min).normalized == .keepLast(1))
        #expect(RecordingCachePolicy.keepLast(-1).normalized == .keepLast(1))
        #expect(RecordingCachePolicy.keepLast(0).normalized == .keepLast(1))
        #expect(RecordingCachePolicy.keepLast(1).normalized == .keepLast(1))
        #expect(RecordingCachePolicy.keepLast(10).normalized == .keepLast(10))
        #expect(RecordingCachePolicy.keepLast(999).normalized == .keepLast(999))
        #expect(RecordingCachePolicy.keepLast(1_000).normalized == .keepLast(999))
        #expect(RecordingCachePolicy.keepLast(Int.max).normalized == .keepLast(999))
    }

    @Test func normalizedPoliciesAreIdempotent() {
        let policies: [RecordingCachePolicy] = [
            .deleteImmediately,
            .keepLast(Int.min),
            .keepLast(1),
            .keepLast(999),
            .keepLast(Int.max),
            .unlimited,
        ]

        for policy in policies {
            #expect(policy.normalized.normalized == policy.normalized)
        }
    }

    @Test func retainedLimitUsesNormalizedCountOrTheUIFallback() {
        #expect(RecordingCachePolicy.keepLast(0).retainedRecordingLimit == 1)
        #expect(RecordingCachePolicy.keepLast(25).retainedRecordingLimit == 25)
        #expect(RecordingCachePolicy.keepLast(1_000).retainedRecordingLimit == 999)
        #expect(
            RecordingCachePolicy.deleteImmediately.retainedRecordingLimit ==
                RecordingCachePolicy.defaultRetainedRecordingLimit
        )
        #expect(
            RecordingCachePolicy.unlimited.retainedRecordingLimit ==
                RecordingCachePolicy.defaultRetainedRecordingLimit
        )
    }

    @Test func configurationPreservesRawPolicyUntilAConsumerNormalizesIt() {
        let configuration = RetentionConfiguration(
            historyEnabled: false,
            recordingCachePolicy: .keepLast(0)
        )

        #expect(configuration.historyEnabled == false)
        #expect(configuration.recordingCachePolicy == .keepLast(0))
        #expect(configuration.recordingCachePolicy.normalized == .keepLast(1))
    }
}
