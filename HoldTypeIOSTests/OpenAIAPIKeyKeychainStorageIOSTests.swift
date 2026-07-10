import Foundation
import HoldTypePersistence
import Testing

struct OpenAIAPIKeyKeychainStorageIOSTests {
    @Test func publicAppOnlyContractWorksThroughANormalIOSImport() throws {
        let fixtureAccessGroup = "TESTTEAMID.app.holdtype.HoldType.ios"
        let storage: any OpenAIAPIKeyStoring = try OpenAIAPIKeyKeychainStorage(
            applicationIdentifierAccessGroup: fixtureAccessGroup
        )

        #expect(
            OpenAIAPIKeyKeychainStorage.containingAppBundleIdentifier
                == "app.holdtype.HoldType.ios"
        )
        #expect(OpenAIAPIKeyKeychainStorage.service == "app.holdtype.HoldType.ios")
        #expect(OpenAIAPIKeyKeychainStorage.account == "openai-api-key")
        #expect(
            OpenAIAPIKeyKeychainStorage.applicationIdentifierAccessGroupInfoKey
                == "HoldTypeApplicationIdentifierAccessGroup"
        )
        requireSendableValue(storage)
        requireSendable(OpenAIAPIKeyKeychainStorage.self)
        requireSendable(OpenAIAPIKeyKeychainStorageError.self)
    }

    @Test func publicErrorsExposeNoSecretOrRawStatusPayload() {
        let forbiddenValues = ["sk-ios-secret", "-25308", "-25291", "-34018"]
        let errors: [OpenAIAPIKeyKeychainStorageError] = [
            .invalidApplicationIdentifierAccessGroup,
            .emptyAPIKey,
            .unavailableWhileLocked,
            .invalidResult,
            .invalidStoredAPIKey,
            .keychainFailure,
        ]

        for error in errors {
            let renderings = [
                error.description,
                error.debugDescription,
                error.localizedDescription,
                String(reflecting: error),
            ]

            for rendering in renderings {
                for forbiddenValue in forbiddenValues {
                    #expect(!rendering.contains(forbiddenValue))
                }
            }
            #expect(error.customMirror.children.isEmpty)
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
    private func requireSendableValue<Value: Sendable>(_: Value) {}
}
