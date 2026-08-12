import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSTextFixCatalogRepositoryTests {
    @Test func storageContractIsStablePrivateBoundedAndRedacted() {
        let root = URL(
            fileURLWithPath: "/private/app/Library/Application Support",
            isDirectory: true
        )

        #expect(
            IOSTextFixCatalogStorageLocation.fileURL(in: root).path ==
                "/private/app/Library/Application Support/HoldType/ios-text-fixes.json"
        )
        #expect(IOSTextFixCatalogStorageLocation.directoryName == "HoldType")
        #expect(IOSTextFixCatalogStorageLocation.fileName == "ios-text-fixes.json")
        #expect(IOSTextFixCatalogRepository.maximumByteCount == 1_024 * 1_024)

        let publicRepository = IOSTextFixCatalogRepository(
            applicationSupportDirectoryURL: root
        )
        #expect(
            String(describing: publicRepository) ==
                "TextFixCatalogRepository(redacted)"
        )
        let repository = makeTextFixCatalogRepository(
            fileSystem: TextFixCatalogFileSystemFake()
        )
        #expect(
            String(describing: repository) ==
                "TextFixCatalogRepository(redacted)"
        )
        #expect(
            String(reflecting: repository) ==
                "TextFixCatalogRepository(redacted)"
        )
    }

    @Test func runtimeCatalogIsNotAWireDTOAndRedactsPromptValues() throws {
        let action = try makeCustomTextFixAction(
            title: "PRIVATE-TITLE",
            prompt: "PRIVATE-PROMPT"
        )
        let catalog = try makeTextFixCatalog(customActions: [action])

        #expect(((catalog as Any) is any Encodable) == false)
        #expect(((catalog as Any) is any Decodable) == false)
        #expect(!String(describing: action).contains("PRIVATE-PROMPT"))
        #expect(!String(reflecting: action).contains("PRIVATE-TITLE"))
        #expect(!String(describing: catalog).contains("PRIVATE-PROMPT"))
        #expect(!String(reflecting: catalog).contains("PRIVATE-PROMPT"))
    }

    @Test func missingFileReturnsDefaultsWithoutWriting() async throws {
        let fileSystem = TextFixCatalogFileSystemFake()
        let repository = makeTextFixCatalogRepository(fileSystem: fileSystem)

        #expect(try await repository.load() == .defaults)
        #expect(fileSystem.data == nil)
        #expect(fileSystem.replacementCallCount == 0)
        #expect(fileSystem.readPolicies == [expectedTextFixCatalogFilePolicy])
    }

    @Test func legacyBuiltInFixTitleMigratesWithoutChangingCustomActions()
        async throws {
        let custom = try makeCustomTextFixAction(
            id: "custom.legacy",
            title: "Keep this title",
            prompt: "Keep this prompt exactly."
        )
        var actions = textFixBuiltInActionObjects()
        actions[1]["title"] = "Fix"
        actions.append(textFixActionObject(custom))
        let fileSystem = TextFixCatalogFileSystemFake(
            data: try textFixRootData(actions: actions)
        )
        let repository = makeTextFixCatalogRepository(fileSystem: fileSystem)

        let loaded = try await repository.load()

        #expect(loaded.actions[1].id == TextFixAction.fixIdentifier)
        #expect(loaded.actions[1].title == "Correct Text")
        #expect(loaded.actions[2] == custom)
        #expect(loaded.actions[2].processingProfile == .inherit)
        #expect(!loaded.actions[2].usesBuiltInWritingSkill)
        #expect(fileSystem.replacementCallCount == 0)
    }

    @Test func canonicalV3SaveRoundTripsSkillProfilesOrderStateAndExactPromptWhitespace()
        async throws {
        let first = try makeCustomTextFixAction(
            id: "custom.first",
            title: " First title ",
            icon: .rewrite,
            prompt: " \n  Preserve all of this whitespace. \t ",
            processingProfile: .gpt56Terra,
            usesBuiltInWritingSkill: true,
            isEnabled: false
        )
        let customProfile = try TextFixProcessingProfile.custom(
            model: "  gpt-custom-fix  ",
            reasoningEffort: .xhigh
        )
        let second = try makeCustomTextFixAction(
            id: "custom.second",
            title: "Second",
            icon: .formal,
            prompt: "Return the result.",
            processingProfile: customProfile
        )
        let catalog = try makeTextFixCatalog(customActions: [first, second])
        let fileSystem = TextFixCatalogFileSystemFake()
        let repository = makeTextFixCatalogRepository(fileSystem: fileSystem)

        let committed = try await repository.save(catalog)
        let loaded = try await repository.load()

        #expect(committed == catalog)
        #expect(loaded == catalog)
        #expect(loaded.actions.map(\.id) == [
            TextFixAction.translateIdentifier,
            TextFixAction.fixIdentifier,
            "custom.first",
            "custom.second",
        ])
        #expect(
            loaded.actions[2].prompt ==
                " \n  Preserve all of this whitespace. \t "
        )
        #expect(loaded.actions[2].title == " First title ")
        #expect(!loaded.actions[2].isEnabled)
        #expect(loaded.actions[2].processingProfile == .gpt56Terra)
        #expect(loaded.actions[2].usesBuiltInWritingSkill)
        #expect(loaded.actions[3].processingProfile.customModel == "gpt-custom-fix")
        #expect(loaded.actions[3].processingProfile.customReasoningEffort == .xhigh)
        #expect(fileSystem.replacementPolicies == [
            expectedTextFixCatalogFilePolicy,
        ])

        let data = try #require(fileSystem.data)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(Set(root.keys) == ["schemaVersion", "actions"])
        #expect(root["schemaVersion"] as? Int == 3)
        let rows = try #require(root["actions"] as? [[String: Any]])
        #expect(rows.count == 4)
        #expect(rows[0]["prompt"] == nil)
        #expect(rows[2]["prompt"] as? String == first.prompt)
        #expect(rows[2]["processingProfile"] as? String == "gpt-5.6-terra")
        #expect(rows[2]["usesBuiltInWritingSkill"] as? Bool == true)
        #expect(rows[3]["usesBuiltInWritingSkill"] as? Bool == false)
        #expect(rows[3]["processingProfile"] as? String == "custom")
        #expect(rows[3]["customModel"] as? String == "gpt-custom-fix")
        #expect(rows[3]["reasoningEffort"] as? String == "xhigh")
    }

    @Test func failedReadAndAtomicReplacementUseTypedErrorsAndPreserveBytes()
        async throws {
        let readFailure = TextFixCatalogFileSystemFake(
            readError: TextFixCatalogFileSystemFakeError.readFailed
        )
        await expectError(.readFailed) {
            _ = try await makeTextFixCatalogRepository(
                fileSystem: readFailure
            ).load()
        }

        let durable = Data("durable-private-bytes".utf8)
        let writeFailure = TextFixCatalogFileSystemFake(
            data: durable,
            replacementError:
                TextFixCatalogFileSystemFakeError.replacementFailed
        )
        await expectError(.writeFailed) {
            _ = try await makeTextFixCatalogRepository(
                fileSystem: writeFailure
            ).save(.defaults)
        }
        #expect(writeFailure.data == durable)
        #expect(writeFailure.replacementCallCount == 1)
    }

    @Test func errorsNeverEchoAttackerControlledNamesOrValues() async {
        let privateName = "PRIVATE-FIELD-NAME"
        let privateValue = "PRIVATE-PROMPT-VALUE"
        let data = Data(
            """
            {"actions":[],"\(privateName)":"\(privateValue)","schemaVersion":1}
            """.utf8
        )
        let fileSystem = TextFixCatalogFileSystemFake(data: data)

        do {
            _ = try await makeTextFixCatalogRepository(
                fileSystem: fileSystem
            ).load()
            Issue.record("Expected an unexpected-field error")
        } catch let error as IOSTextFixCatalogRepositoryError {
            #expect(error == .unexpectedFields(path: "$"))
            #expect(!String(describing: error).contains(privateName))
            #expect(!String(reflecting: error).contains(privateValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(fileSystem.data == data)
        #expect(fileSystem.replacementCallCount == 0)
    }

    private func expectError(
        _ expected: IOSTextFixCatalogRepositoryError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expected)")
        } catch let error as IOSTextFixCatalogRepositoryError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
