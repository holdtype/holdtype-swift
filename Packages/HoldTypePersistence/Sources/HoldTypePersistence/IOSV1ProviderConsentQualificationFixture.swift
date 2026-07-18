import Foundation

#if DEBUG
/// Content-free observations used only by rendered-state qualification.
@_spi(HoldTypeIOSCore)
public enum IOSV1ProviderConsentQualificationFixture {
    private static let ownerID = UUID()
    private static let generation = UUID()

    public static func notReviewedObservation()
        -> IOSV1ProviderConsentObservation {
        observation(for: .missing)
    }

    public static func acceptedObservation()
        -> IOSV1ProviderConsentObservation {
        let record = IOSV1ProviderConsentRecord(
            revision: 1,
            disclosureVersion:
                IOSV1ProviderConsentCoordinator.currentDisclosureVersion,
            decision: .accepted,
            decisionAtMilliseconds: 1_767_225_600_000
        )
        let bytes = (try? IOSV1ProviderConsentWireCodec.encode(record))
            ?? Data()
        return observation(for: .record(record, bytes))
    }

    public static func resettableUnreadableObservation()
        -> IOSV1ProviderConsentObservation {
        observation(for: .unreadable(Data("invalid".utf8)))
    }

    public static func localDataUnavailableObservation()
        -> IOSV1ProviderConsentObservation {
        observation(for: .unavailable)
    }

    public static func isAuthorizationReady(
        for observation: IOSV1ProviderConsentObservation
    ) -> Bool {
        observation.status == .acceptedCurrentDisclosure
    }

    public static func hasSameObservationAuthority(
        _ candidate: IOSV1ProviderConsentObservation,
        as current: IOSV1ProviderConsentObservation
    ) -> Bool {
        candidate.token == current.token
    }

    private static func observation(
        for source: IOSV1ProviderConsentSource
    ) -> IOSV1ProviderConsentObservation {
        IOSV1ProviderConsentObservation(
            source: source,
            token: IOSV1ProviderConsentObservationToken(
                ownerID: ownerID,
                source: source,
                fenceGeneration: generation
            )
        )
    }
}
#endif
