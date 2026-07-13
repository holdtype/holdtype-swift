#if DEBUG
/// DEBUG-only opaque write ordering for rendered-state qualification.
/// Release builds cannot import or construct these fixture tokens.
@_spi(HoldTypeIOSCore)
public enum IOSTranscriptionUsageQualificationFixture {
    public static func writeToken(
        revision: UInt64
    ) -> IOSTranscriptionUsageWriteToken {
        IOSTranscriptionUsageWriteToken(revision: revision)
    }
}
#endif
