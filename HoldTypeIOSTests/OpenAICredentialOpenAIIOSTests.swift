import HoldTypeOpenAI
import Testing

struct OpenAICredentialOpenAIIOSTests {
    @Test func publicCredentialContractWorksThroughANormalIOSImport() throws {
        let expected = try OpenAICredential(apiKey: "  sk-ios-test \n")
        let resolver: any OpenAICredentialResolving =
            IOSOpenAICredentialResolver(credential: expected)

        #expect(expected.apiKey == "sk-ios-test")
        #expect(expected.source == .runtimeStorage)
        #expect(try resolver.resolveOpenAICredential() == expected)
        requireSendable(OpenAICredential.self)
        requireSendable(OpenAICredentialSource.self)
        #expect(((expected as Any) is any Encodable) == false)
        #expect(((expected as Any) is any Decodable) == false)
    }

    @Test func blankCredentialFailsWithThePublicValidationError() {
        #expect(throws: OpenAICredential.ValidationError.missingAPIKey) {
            _ = try OpenAICredential(apiKey: " \n\t ")
        }
    }

    @Test func publicCredentialDiagnosticsStayRedactedOnIOS() throws {
        let apiKeySentinel = "sk-ios-diagnostic-sentinel"
        let credential = try OpenAICredential(apiKey: apiKeySentinel)
        var output = ""

        dump(credential, to: &output)

        #expect(!String(describing: credential).contains(apiKeySentinel))
        #expect(!String(reflecting: credential).contains(apiKeySentinel))
        #expect(!output.contains(apiKeySentinel))
        #expect(credential.customMirror.children.isEmpty)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}

private struct IOSOpenAICredentialResolver: OpenAICredentialResolving {
    let credential: OpenAICredential

    func resolveOpenAICredential() throws -> OpenAICredential {
        credential
    }
}
