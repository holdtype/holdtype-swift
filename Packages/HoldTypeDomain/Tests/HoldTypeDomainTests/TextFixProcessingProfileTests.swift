import Testing
import HoldTypeDomain

struct TextFixProcessingProfileTests {
    @Test func presetsResolveExactProviderValuesAndTimeouts() {
        let inherited = TextFixProcessingProfile.inherit.resolved(
            inheritedModel: "saved-model"
        )
        let terra = TextFixProcessingProfile.gpt56Terra.resolved(
            inheritedModel: "ignored"
        )
        let sol = TextFixProcessingProfile.gpt56SolMax.resolved(
            inheritedModel: "ignored"
        )

        #expect(inherited.model == "saved-model")
        #expect(inherited.reasoningEffort == .low)
        #expect(inherited.requestTimeoutSeconds == 20)
        #expect(terra.model == "gpt-5.6-terra")
        #expect(terra.reasoningEffort == .medium)
        #expect(terra.requestTimeoutSeconds == 20)
        #expect(sol.model == "gpt-5.6-sol")
        #expect(sol.reasoningEffort == .max)
        #expect(sol.requestTimeoutSeconds == 60)
    }

    @Test func customProfileNormalizesAndValidatesTheModelIdentifier() throws {
        let profile = try TextFixProcessingProfile.custom(
            model: "  gpt-custom  ",
            reasoningEffort: .xhigh
        )
        let resolved = profile.resolved(inheritedModel: "ignored")

        #expect(profile.customModel == "gpt-custom")
        #expect(profile.customReasoningEffort == .xhigh)
        #expect(resolved.model == "gpt-custom")
        #expect(resolved.reasoningEffort == .xhigh)
        #expect(resolved.requestTimeoutSeconds == 20)
        #expect(throws: TextFixProcessingProfile.ValidationError.emptyCustomModel) {
            try TextFixProcessingProfile.custom(model: " \n ", reasoningEffort: .low)
        }
    }
}
