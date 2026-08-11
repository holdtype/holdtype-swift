import AppKit
import Testing
@testable import HoldType

@MainActor
struct AppWindowActivationTests {
    @Test func configuredPolicyMatchesDockPreference() {
        #expect(AppWindowActivation.configuredPolicy(showInDock: false) == .accessory)
        #expect(AppWindowActivation.configuredPolicy(showInDock: true) == .regular)
    }

    @Test func applyingConfiguredPolicyUsesTheResolvedPolicy() {
        var appliedPolicy: NSApplication.ActivationPolicy?

        let didApply = AppWindowActivation.applyConfiguredPolicy(
            showInDock: false,
            setActivationPolicy: { policy in
                appliedPolicy = policy
                return true
            }
        )

        #expect(didApply)
        #expect(appliedPolicy == .accessory)
    }

    @Test func windowPresentationAppliesPreferenceBeforeActivation() {
        var events: [String] = []

        AppWindowActivation.activateForWindowPresentation(
            showInDock: false,
            setActivationPolicy: { policy in
                events.append(policy == .accessory ? "accessory" : "regular")
                return true
            },
            activate: {
                events.append("activate")
            }
        )

        #expect(events == ["accessory", "activate"])
    }
}
