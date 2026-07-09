import HoldTypeDomain
import Testing

struct RetentionConfigurationDomainIOSTests {
    @Test func resolvesPortableRetentionConfigurationOnIOS() {
        let defaults = RetentionConfiguration.defaults

        #expect(defaults.historyEnabled)
        #expect(defaults.recordingCachePolicy == .deleteImmediately)
        #expect(defaults.recordingCachePolicy.keepsRecordings == false)
        #expect(RetentionConfiguration.acceptedHistoryEntryLimit == 20)
        #expect(RetentionConfiguration.failedHistoryEntryLimit == 5)
        #expect(RecordingCachePolicy.keepLast(0) == .keepLast(0))
        #expect(RecordingCachePolicy.keepLast(0).normalized == .keepLast(1))
        #expect(RecordingCachePolicy.keepLast(10).normalized == .keepLast(10))
        #expect(RecordingCachePolicy.keepLast(1_000).normalized == .keepLast(999))
        #expect(RecordingCachePolicy.keepLast(25).retainedRecordingLimit == 25)
        #expect(RecordingCachePolicy.unlimited.keepsRecordings)
        #expect(
            RecordingCachePolicy.unlimited.retainedRecordingLimit ==
                RecordingCachePolicy.defaultRetainedRecordingLimit
        )
    }
}
