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
        let cases = DevVlogsPhase0BE07CaseID.allCases.map(\.rawValue); let passing = cases.map { ($0, true) }
        let truthfulFail = cases.map { ($0, $0 != DevVlogsPhase0BE07CaseID.camera_busy.rawValue) }; let twoFailures = cases.map { ($0, ![DevVlogsPhase0BE07CaseID.camera_busy.rawValue, DevVlogsPhase0BE07CaseID.mux_failure.rawValue].contains($0)) }
        let truthfulFailedCases = truthfulFail.compactMap { $0.1 ? nil : $0.0 }; let twoFailedCases = twoFailures.compactMap { $0.1 ? nil : $0.0 }
        #expect(passing.compactMap { $0.1 ? nil : $0.0 }.isEmpty); #expect(truthfulFailedCases == [DevVlogsPhase0BE07CaseID.camera_busy.rawValue])
        #expect(zip(truthfulFail, truthfulFail).allSatisfy { $0.0.1 == $0.1.1 }); #expect(!zip(truthfulFail, passing).allSatisfy { $0.0.1 == $0.1.1 })
        #expect([DevVlogsPhase0BE07CaseID.mux_failure.rawValue] != truthfulFailedCases); #expect(!truthfulFailedCases.isEmpty); #expect(passing.allSatisfy { $0.1 })
        #expect([DevVlogsPhase0BE07CaseID.camera_busy.rawValue, DevVlogsPhase0BE07CaseID.camera_busy.rawValue] != truthfulFailedCases); #expect([DevVlogsPhase0BE07CaseID.mux_failure.rawValue, DevVlogsPhase0BE07CaseID.camera_busy.rawValue] != twoFailedCases)
        #expect((Array(passing.dropLast()) + [passing[0]]).map(\.0) != cases); #expect(([passing[1], passing[0]] + Array(passing.dropFirst(2))).map(\.0) != cases)
        try DevVlogsPhase0BE07EvidenceValidator().validate(fromTestFilePath: #filePath)
    }
}
#endif
