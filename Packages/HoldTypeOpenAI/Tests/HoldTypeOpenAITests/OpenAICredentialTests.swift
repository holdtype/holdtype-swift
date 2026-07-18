import Testing
@testable import HoldTypeOpenAI

struct OpenAICredentialTests {
    @Test func trimsOnlySurroundingWhitespace() throws {
        let credential = try OpenAICredential(apiKey: "  Sk-Test Key\tValue \n")

        #expect(credential.apiKey == "Sk-Test Key\tValue")
    }

    @Test func rejectsEmptyNormalizedKeysWithATypedValidationError() {
        for apiKey in ["", " \n\t "] {
            #expect(throws: OpenAICredential.ValidationError.missingAPIKey) {
                _ = try OpenAICredential(apiKey: apiKey)
            }
        }
    }

    @Test func equalityUsesTheNormalizedKey() throws {
        let credential = try OpenAICredential(apiKey: "sk-test")

        #expect(credential == (try OpenAICredential(apiKey: " sk-test ")))
        #expect(credential != (try OpenAICredential(apiKey: "SK-TEST")))
    }

    @Test func publicValuesAreSendableButNotTransportContracts() throws {
        requireSendable(OpenAICredential.self)

        let credential = try OpenAICredential(apiKey: "sk-non-codable")
        #expect(((credential as Any) is any Encodable) == false)
        #expect(((credential as Any) is any Decodable) == false)
    }

    @Test func standardDiagnosticsRedactTheKey() throws {
        let apiKeySentinel = "sk-diagnostic-sentinel"
        let credential = try OpenAICredential(apiKey: apiKeySentinel)
        var credentialDump = ""

        dump(credential, to: &credentialDump)

        let diagnosticRepresentations = [
            String(describing: credential),
            String(reflecting: credential),
            credentialDump,
        ]

        for representation in diagnosticRepresentations {
            #expect(!representation.contains(apiKeySentinel))
        }
        #expect(credential.customMirror.children.isEmpty)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
