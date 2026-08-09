#if DEBUG
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BDictationNonRegressionTests {
    @Test func standardSuccessPairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .standard_success) } }
    @Test func correctedSuccessPairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .corrected_success) } }
    @Test func translatedSuccessPairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .translated_success) } }
    @Test func explicitCancelPairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .explicit_cancel) } }
    @Test func cameraUnavailablePairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .camera_unavailable) } }
    @Test func cameraBusyPairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .camera_busy) } }
    @Test("Slow preparation closes cancellation races before success")
    func cameraSlowTimeoutPairMatchesBaseline() async throws {
        if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .camera_slow_timeout) }
    }
    @Test func destinationUnavailablePairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .destination_unavailable) } }
    @Test func destinationDisconnectPairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .destination_disconnect) } }
    @Test func muxFailurePairMatchesBaseline() async throws { if #available(macOS 15.0, *) { try await DevVlogsPhase0BE07PairHarness().assertPair(caseID: .mux_failure) } }
    @Test("Evidence schemas close functional results and measurement order")
    func evidenceArtifactsMatchClosedSchemasAndRedactionPolicy() throws {
        try DevVlogsPhase0BE07EvidenceValidator().validate(fromTestFilePath: #filePath)
    }
}
#endif
