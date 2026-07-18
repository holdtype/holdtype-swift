import Foundation
import HoldTypeDomain
import HoldTypePersistence
import Testing

struct IOSLibraryPersistenceIOSTests {
    private static let commandID = UUID(
        uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
    )!
    private static let ruleID = UUID(
        uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
    )!

    @Test func publicRepositoryUsesStableProtectedBackupEligibleLocation() async throws {
        let containerURL = makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: containerURL) }
        let applicationSupportURL = containerURL.appendingPathComponent(
            "Library/Application Support",
            isDirectory: true
        )
        let fileURL = applicationSupportURL
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent("ios-library.json", isDirectory: false)
        #expect(IOSLibraryStorageLocation.fileURL(in: applicationSupportURL) == fileURL)

        let repository = IOSLibraryRepository(
            applicationSupportDirectoryURL: applicationSupportURL
        )
        #expect(try await repository.load() == .defaults)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))

        try await repository.save(fixtureContent())
        let loaded = try await repository.load()
        #expect(loaded.customDictionary.entries == ["HoldType", "Alpha,Beta"])
        #expect(loaded.emojiCommandsConfiguration.enabledBuiltInSetIDs == ["fr"])
        #expect(loaded.emojiCommandsConfiguration.customCommands.count == 1)
        #expect(loaded.emojiCommandsConfiguration.customCommands[0].command == "launch now")
        #expect(loaded.replacementRules.map(\.search) == ["", ""])
        #expect(
            try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
                .isExcludedFromBackup == false
        )

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        #if targetEnvironment(simulator)
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            #expect(protection == .complete)
        }
        #else
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        #endif
    }

    private func fixtureContent() -> IOSLibraryContent {
        IOSLibraryContent(
            customDictionary: CustomDictionary(entries: [
                " HoldType ", "holdtype", "Alpha,Beta",
            ]),
            emojiCommandsConfiguration: EmojiCommandsConfiguration(
                enabledBuiltInSetIDs: ["fr"],
                customCommands: [
                    CustomEmojiCommand(
                        id: Self.commandID,
                        emoji: " 🚀 ",
                        command: " ",
                        aliases: [" launch   now "],
                        isEnabled: true
                    ),
                ]
            ),
            replacementRules: [
                TextReplacementRule(
                    id: Self.ruleID,
                    search: "",
                    replacement: "one"
                ),
                TextReplacementRule(
                    search: "",
                    replacement: "two",
                    isEnabled: false
                ),
            ]
        )
    }

    private func makeTemporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-ios-library-tests-\(UUID().uuidString)",
            isDirectory: true
        )
    }
}
