import Darwin
import Foundation
import Testing
protocol DevVlogsStorageCapacityProviding { func usefulCapacity(at destinationURL: URL) throws -> Int64? }
protocol DevVlogsStorageDestinationStateProviding { func state(at destinationURL: URL) throws -> DevVlogsStorageDestinationState }
struct DevVlogsStorageDestinationState: Equatable { let isAvailable: Bool, isLocal: Bool, isReadOnly: Bool }
enum DevVlogsStorageSkipReason: String, Equatable { case unavailable, nonlocal; case readOnly = "read_only", capacityUnknown = "capacity_unknown"; case insufficientCapacity = "insufficient_capacity" }
enum DevVlogsStoragePreflightResult: Equatable { case proceed(usefulCapacity: Int64, suppliedReserve: Int64); case skip(DevVlogsStorageSkipReason) }
struct DevVlogsStoragePreflight {
    let capacityProvider: any DevVlogsStorageCapacityProviding; let destinationStateProvider: any DevVlogsStorageDestinationStateProviding
    func evaluate(destinationURL: URL, suppliedReserve: Int64) throws -> DevVlogsStoragePreflightResult {
        let state = try destinationStateProvider.state(at: destinationURL)
        guard state.isAvailable else { return .skip(.unavailable) }
        guard state.isLocal else { return .skip(.nonlocal) }
        guard !state.isReadOnly else { return .skip(.readOnly) }
        guard let capacity = try capacityProvider.usefulCapacity(at: destinationURL) else { return .skip(.capacityUnknown) }
        guard capacity >= suppliedReserve else { return .skip(.insufficientCapacity) }
        return .proceed(usefulCapacity: capacity, suppliedReserve: suppliedReserve)
    }
}
struct DevVlogsURLStorageCapacityProvider: DevVlogsStorageCapacityProviding {
    func usefulCapacity(at destinationURL: URL) throws -> Int64? {
        try destinationURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }
}
enum DevVlogsStorageMediaValidation: String, Equatable { case playable, unvalidated, unusable }
enum DevVlogsStorageClipClassification: String, Equatable { case ready, incomplete, failed }
enum DevVlogsStorageCleanupClassification: String, Equatable { case complete; case pendingReconnect = "pending_reconnect" }
struct DevVlogsStorageTerminalState: Equatable {
    let clip: DevVlogsStorageClipClassification; let cleanup: DevVlogsStorageCleanupClassification
    static func classify(byteCount: Int64?, validation: DevVlogsStorageMediaValidation,
                         destinationAvailable: Bool) -> Self {
        let clip: DevVlogsStorageClipClassification = (byteCount ?? 0) <= 0 || validation == .unusable
            ? .failed : validation == .playable ? .ready : .incomplete
        return Self(clip: clip, cleanup: destinationAvailable ? .complete : .pendingReconnect)
    }
}
struct DevVlogsStorageEvidenceRecord: Codable, Equatable {
    let runID: String, caseID: String, attemptID: String
    let destinationClass: String, filesystemClass: String, relativePathClass: String
    let byteCount: Int64; let bookmarkWasStale: Bool; let result: String
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(self)
    }
}
@Suite(.serialized)
struct DevVlogsStorageFeasibilityTests {
    @Test func markerOwnershipRequiresExactMatchAndExactPrefix() throws {
        let root = try makeRoot()
        defer { restoreMarkerAndCleanup(root) }
        try root.validateOwnership()
        let expectedPrefix = FileManager.default.temporaryDirectory
            .appendingPathComponent(DevVlogsStorageRunRoot.prefixName, isDirectory: true)
            .standardizedFileURL
        #expect(root.rootURL.deletingLastPathComponent().standardizedFileURL == expectedPrefix)
        #expect(root.rootURL.lastPathComponent == root.runID.uuidString.lowercased())
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outside")
        #expect(throws: DevVlogsStorageHarnessError.outOfScope) { _ = try root.ownedURL(relativePath: outside.path) }
        let marker = root.rootURL.appendingPathComponent(DevVlogsStorageRunRoot.markerName)
        try Data(UUID().uuidString.utf8).write(to: marker)
        #expect(throws: DevVlogsStorageHarnessError.markerMismatch) { try root.cleanup() }
        #expect(FileManager.default.fileExists(atPath: root.rootURL.path))
    }
    @Test func missingMarkerAndSymlinkedComponentCannotAuthorizeCleanupOrIO() throws {
        let root = try makeRoot()
        defer { restoreMarkerAndCleanup(root) }
        let marker = root.rootURL.appendingPathComponent(DevVlogsStorageRunRoot.markerName)
        try FileManager.default.removeItem(at: marker)
        #expect(throws: DevVlogsStorageHarnessError.markerMissing) { try root.cleanup() }
        try root.restoreMissingMarkerForInternalTestTeardown()
        let target = try root.ownedURL(relativePath: "owned-target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let link = try root.ownedURL(relativePath: "linked-target")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(throws: DevVlogsStorageHarnessError.symbolicLink) { _ = try root.ownedURL(relativePath: "linked-target/clip.mov") }
    }
    @Test func cleanupRemovesOnlyMarkerVerifiedRunRoot() throws {
        let first = try makeRoot(); let second = try makeRoot()
        defer { cleanupIfOwned(second) }
        try first.cleanup()
        #expect(!FileManager.default.fileExists(atPath: first.rootURL.path))
        #expect(FileManager.default.fileExists(atPath: second.rootURL.path))
        try second.validateOwnership()
    }
    @Test func cleanupRejectsRedirectedPrefixAndPreservesRedirectedContent() throws {
        let unrelatedRoot = try makeRoot()
        defer { cleanupIfOwned(unrelatedRoot) }
        let outerRoot = try makeRoot()
        defer { cleanupIfOwned(outerRoot) }
        let fixtureBase = try outerRoot.ownedURL(relativePath: "redirected-prefix-fixture")
        try FileManager.default.createDirectory(at: fixtureBase, withIntermediateDirectories: false)
        let redirectedRun = try DevVlogsStorageRunRoot(
            runID: UUID(),
            authority: .nestedAttackFixture(fixtureBase)
        )
        let requiredPrefix = redirectedRun.rootURL.deletingLastPathComponent(); let savedPrefix = fixtureBase.appendingPathComponent("saved-prefix", isDirectory: true)
        let redirectedPrefix = fixtureBase.appendingPathComponent("redirected-prefix", isDirectory: true); let redirectedRoot = redirectedPrefix.appendingPathComponent(redirectedRun.runID.uuidString.lowercased(), isDirectory: true)
        let unrelated = fixtureBase.appendingPathComponent("unrelated-sentinel"); try Data("unrelated".utf8).write(to: unrelated, options: .atomic)
        var prefixWasMoved = false
        defer {
            unlinkSymbolicLinkIfPresent(at: requiredPrefix)
            if prefixWasMoved, !FileManager.default.fileExists(atPath: requiredPrefix.path),
               FileManager.default.fileExists(atPath: savedPrefix.path) { try? FileManager.default.moveItem(at: savedPrefix, to: requiredPrefix) }
            cleanupIfOwned(redirectedRun)
        }
        try FileManager.default.moveItem(at: requiredPrefix, to: savedPrefix)
        prefixWasMoved = true
        try FileManager.default.createDirectory(at: redirectedRoot, withIntermediateDirectories: true)
        let redirectedMarker = redirectedRoot.appendingPathComponent(DevVlogsStorageRunRoot.markerName)
        try Data(redirectedRun.runID.uuidString.lowercased().utf8).write(to: redirectedMarker, options: .atomic)
        let redirectedContent = redirectedRoot.appendingPathComponent("must-survive"); try Data("redirected-content".utf8).write(to: redirectedContent, options: .atomic)
        try FileManager.default.createSymbolicLink(at: requiredPrefix, withDestinationURL: redirectedPrefix)
        #expect(throws: DevVlogsStorageHarnessError.symbolicLink) { try redirectedRun.cleanup() }
        #expect(try Data(contentsOf: redirectedContent) == Data("redirected-content".utf8)); #expect(try Data(contentsOf: unrelated) == Data("unrelated".utf8))
        unlinkSymbolicLinkIfPresent(at: requiredPrefix); try FileManager.default.moveItem(at: savedPrefix, to: requiredPrefix); prefixWasMoved = false
        try redirectedRun.cleanup()
        try outerRoot.cleanup()
        #expect(FileManager.default.fileExists(atPath: unrelatedRoot.rootURL.path))
        try unrelatedRoot.validateOwnership()
    }
    @Test func ordinaryBookmarkFollowsRunOwnedRenameAndReportsStaleFlag() throws {
        let root = try makeRoot()
        defer { cleanupIfOwned(root) }
        let source = try root.ownedURL(relativePath: "bookmark-source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        let bookmark = try DevVlogsOrdinaryBookmark.create(for: source)
        let renamed = try root.ownedURL(relativePath: "bookmark-renamed")
        try FileManager.default.moveItem(at: source, to: renamed)
        let resolution = try DevVlogsOrdinaryBookmark.resolve(bookmark)
        #expect(resolution.url.standardizedFileURL == renamed.standardizedFileURL)
        let report = DevVlogsStorageEvidenceRecord(
            runID: "bookmark-run",
            caseID: "rename-following",
            attemptID: "bookmark-attempt",
            destinationClass: "internal",
            filesystemClass: "apfs",
            relativePathClass: "renamed_folder",
            byteCount: 0,
            bookmarkWasStale: resolution.isStale,
            result: "resolved"
        )
        let decodedReport = try JSONDecoder().decode(
            DevVlogsStorageEvidenceRecord.self,
            from: report.encoded()
        )
        #expect(decodedReport.bookmarkWasStale == resolution.isStale)
    }
    @Test(arguments: capacityCases)
    func destinationAndCapacityMatrix(caseItem: CapacityCase) throws {
        let preflight = DevVlogsStoragePreflight(
            capacityProvider: FixedCapacityProvider(capacity: caseItem.capacity),
            destinationStateProvider: FixedDestinationProvider(state: caseItem.state)
        )
        let result = try preflight.evaluate(
            destinationURL: URL(fileURLWithPath: "/redacted/internal-run"),
            suppliedReserve: caseItem.reserve
        )
        #expect(result == caseItem.expected)
    }
    @Test func actualLocalResourceHintsAreAvailableWithoutChoosingAReserve() throws {
        let root = try makeRoot()
        defer { cleanupIfOwned(root) }
        let state = try DevVlogsURLStorageDestinationStateProvider().state(at: root.rootURL); let capacity = try DevVlogsURLStorageCapacityProvider().usefulCapacity(at: root.rootURL)
        #expect(state.isAvailable); #expect(state.isLocal); #expect(!state.isReadOnly); #expect((capacity ?? 0) > 0)
    }
    @Test func synchronizedWritePromotesExclusivelyOnTheSameVolume() throws {
        let root = try makeRoot()
        defer { cleanupIfOwned(root) }
        let bytes = Data("controlled-storage-fixture".utf8)
        _ = try root.writeSynchronously(bytes, relativePath: "active/attempt-1.partial")
        let final = try root.promoteExclusively(
            fragmentRelativePath: "active/attempt-1.partial",
            finalRelativePath: "final/attempt-1.mov"
        )
        #expect(try Data(contentsOf: final) == bytes)
        #expect(!FileManager.default.fileExists(
            atPath: try root.ownedURL(relativePath: "active/attempt-1.partial").path
        ))
    }
    @Test func exclusivePromotionCollisionDoesNotOverwriteExistingFinal() throws {
        let root = try makeRoot()
        defer { cleanupIfOwned(root) }
        let original = Data("existing-final".utf8)
        let candidate = Data("new-candidate".utf8)
        _ = try root.writeSynchronously(original, relativePath: "final/attempt.mov")
        _ = try root.writeSynchronously(candidate, relativePath: "active/attempt.partial")
        #expect(throws: DevVlogsStorageHarnessError.itemExists) {
            _ = try root.promoteExclusively(
                fragmentRelativePath: "active/attempt.partial",
                finalRelativePath: "final/attempt.mov"
            )
        }
        let final = try root.ownedURL(relativePath: "final/attempt.mov")
        let fragment = try root.ownedURL(relativePath: "active/attempt.partial")
        #expect(try Data(contentsOf: final) == original)
        #expect(try Data(contentsOf: fragment) == candidate)
    }
    @Test func exclusiveCreateAndOutOfRootPromotionFailWithoutFallback() throws {
        let root = try makeRoot()
        defer { cleanupIfOwned(root) }
        let bytes = Data("first".utf8)
        _ = try root.writeSynchronously(bytes, relativePath: "active/existing.partial")
        #expect(throws: DevVlogsStorageHarnessError.itemExists) {
            _ = try root.writeSynchronously(Data("second".utf8), relativePath: "active/existing.partial")
        }
        #expect(throws: DevVlogsStorageHarnessError.outOfScope) {
            _ = try root.promoteExclusively(
                fragmentRelativePath: "active/existing.partial",
                finalRelativePath: "../outside.mov"
            )
        }
        #expect(try Data(contentsOf: try root.ownedURL(relativePath: "active/existing.partial")) == bytes)
    }
    @Test func interruptionAndPartialClassificationNeverInventReadyMedia() {
        #expect(DevVlogsStorageTerminalState.classify(byteCount: 128, validation: .unvalidated,
            destinationAvailable: false) == .init(clip: .incomplete, cleanup: .pendingReconnect))
        #expect(DevVlogsStorageTerminalState.classify(byteCount: 0, validation: .unvalidated,
            destinationAvailable: false) == .init(clip: .failed, cleanup: .pendingReconnect))
        #expect(DevVlogsStorageTerminalState.classify(byteCount: 128, validation: .unusable,
            destinationAvailable: true) == .init(clip: .failed, cleanup: .complete))
        #expect(DevVlogsStorageTerminalState.classify(byteCount: 128, validation: .playable,
            destinationAvailable: true).clip == .ready)
    }
    @Test func unavailableAndReadOnlyStatesSkipWithoutDestinationFallback() throws {
        for reason in [DevVlogsStorageSkipReason.unavailable, .readOnly] {
            let state = DevVlogsStorageDestinationState(isAvailable: reason != .unavailable,
                isLocal: true, isReadOnly: reason == .readOnly)
            let result = try DevVlogsStoragePreflight(capacityProvider: FixedCapacityProvider(capacity: Int64.max),
                destinationStateProvider: FixedDestinationProvider(state: state)).evaluate(
                    destinationURL: URL(fileURLWithPath: "/redacted/selected"), suppliedReserve: 1)
            #expect(result == .skip(reason))
        }
    }
    @Test func evidenceRecordIsRedactedAndContainsNoPathOrBookmarkPayload() throws {
        let record = DevVlogsStorageEvidenceRecord(runID: "run-1", caseID: "promotion-collision",
            attemptID: "attempt-1", destinationClass: "internal", filesystemClass: "apfs",
            relativePathClass: "active_fragment", byteCount: 13, bookmarkWasStale: false, result: "incomplete")
        let payload = try #require(String(data: record.encoded(), encoding: .utf8))
        #expect(!payload.contains(FileManager.default.temporaryDirectory.path))
        #expect(!payload.contains("/Users/"))
        #expect(!payload.contains("bookmarkData"))
        #expect(!payload.contains("volumeIdentifier"))
        #expect(!payload.contains("NSError"))
    }
    @Test func wrapperExecutesTheClosedEnvironmentOnTheActualTestPath() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let wrapperURL = repositoryRoot.appendingPathComponent("script/dev_vlogs_phase_0_b_external_storage.sh")
        let wrapper = try String(contentsOf: wrapperURL, encoding: .utf8); let cleanupCall = try #require(wrapper.range(of: "cleanup_task_home || fail")); let successClaim = try #require(wrapper.range(of: "result=pass cleanup=complete")); #expect(cleanupCall.lowerBound < successClaim.lowerBound)
        let homeCall = try #require(wrapper.range(of: "\ncreate_task_home || fail")); let derivedCall = try #require(wrapper.range(of: "\ncreate_derived_data || fail")); let buildCall = try #require(wrapper.range(of: "\nrun_external_storage_build\n")); #expect(homeCall.lowerBound < derivedCall.lowerBound && derivedCall.lowerBound < buildCall.lowerBound)
        func shellFunction(_ name: String) throws -> Substring {
            let start = try #require(wrapper.range(of: "\(name)() {")); let tail = wrapper[start.lowerBound...]
            let end = try #require(tail.range(of: "\n}\n")); return tail[..<end.upperBound]
        }
        let shell = """
        \(try shellFunction("run_external_storage_build"))
        \(try shellFunction("run_external_storage_test"))
        run_bounded() { /usr/bin/printf '%s\\n' "$@"; }
        validate_derived_data() { return 0; }
        build_timeout_seconds=600 test_timeout_seconds=180 volume_root=/Volumes/redacted-fixture
        expected_class=external-ssd expected_filesystem=apfs case_id=mechanics_case
        run_id=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee
        task_home=/private/tmp/holdtype-dev-vlogs-storage-home.Ab12Cd34
        derived_data_path=$task_home/DerivedData
        print -r -- phase=build; run_external_storage_build
        print -r -- phase=test; run_external_storage_test
        """
        let process = Process(); let output = Pipe(); process.executableURL = URL(fileURLWithPath: "/bin/zsh"); process.arguments = ["-c", shell]
        process.standardOutput = output; try process.run(); process.waitUntilExit()
        let arguments = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self); #expect(process.terminationStatus == 0)
        let derivedPath = "/private/tmp/holdtype-dev-vlogs-storage-home.Ab12Cd34/DerivedData"; #expect(arguments.components(separatedBy: "\n").filter { $0 == derivedPath }.count == 2)
        #expect(arguments.components(separatedBy: "\n").filter { $0 == "-derivedDataPath" }.count == 2); #expect(try #require(arguments.range(of: "phase=build")?.upperBound) < (try #require(arguments.range(of: "phase=test")?.lowerBound)))
        #expect(!String(arguments[..<(try #require(arguments.range(of: "phase=test"))).lowerBound]).contains("HOME="))
        for expected in ["HOME=/private/tmp/holdtype-dev-vlogs-storage-home.Ab12Cd34",
            "CFFIXED_USER_HOME=/private/tmp/holdtype-dev-vlogs-storage-home.Ab12Cd34",
            "HOLDTYPE_DEV_VLOGS_STORAGE_VALIDATE_PRIVATE_HOME=1", "HOLDTYPE_AUTOMATION=1", "HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI=skip",
            "HOLDTYPE_DEV_VLOGS_PHASE_0B_STORAGE_TEST_HOST=1", "/usr/bin/xcodebuild", "test-without-building",
            "-only-testing:HoldTypeTests/DevVlogsExternalStorageRuntimeTests"] { #expect(arguments.split(separator: "\n").contains(Substring(expected))) }
        let rejectedRoot = "/Volumes/private-fixture-token"
        let nonExecuteCases: [([String], Int32)] = [(["--help"], 0), ([], 64),
            (["--execute-external", "--volume-root", rejectedRoot, "--destination-class", "invalid",
              "--filesystem-class", "apfs", "--case-id", "mechanics_case", "--run-id",
              "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"], 64)]
        for (arguments, expectedStatus) in nonExecuteCases {
            let check = Process(); let captured = Pipe(); check.executableURL = URL(fileURLWithPath: "/bin/zsh"); check.arguments = [wrapperURL.path] + arguments
            check.standardOutput = captured; check.standardError = captured; try check.run(); check.waitUntilExit()
            let text = String(decoding: captured.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self); #expect(check.terminationStatus == expectedStatus)
            for secret in ["HOME=", "CFFIXED_USER_HOME", "HOLDTYPE_DEV_VLOGS_STORAGE_VALIDATE_PRIVATE_HOME", "HOLDTYPE_AUTOMATION", "HOLDTYPE_KEYCHAIN_AUTHENTICATION_UI",
                "HOLDTYPE_DEV_VLOGS_PHASE_0B_STORAGE_TEST_HOST", "-derivedDataPath", rejectedRoot] { #expect(!text.contains(secret)) }
        }
        let homeFunctions = try ["task_home_path_identity", "create_task_home", "validate_task_home", "derived_data_path_identity", "create_derived_data", "validate_derived_data", "cleanup_task_home", "cleanup", "run_external_storage_build", "run_external_storage_test"].map { try shellFunction($0) }.joined(separator: "\n")
        let lifecycleShell = """
        \(homeFunctions)
        zmodload zsh/system
        metadata_timeout_seconds=15
        race_mode=none
        run_metadata_probe() {
            if [[ "$race_mode" == replace && "$1" == /bin/zsh && "$2" == -c && "$4" == task-home-cleanup ]]; then race_mode=done
                /bin/mv "$task_home" "$moved_home" || return 70; /bin/mkdir -m 700 "$task_home" || return 70; fi; "$@"
        }
        terminate_supervisor() { return 0; }
        stop_caffeinate() { return 0; }
        phase_executions=0; run_bounded() { phase_executions=$(( phase_executions + 1 )); return 0; }
        run_case() {
            local action=$1 expected=$2 actual; ( task_home="" task_home_identity="" derived_data_path="" derived_data_identity=""; create_task_home || exit 71; create_derived_data || exit 71
              trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
              case "$action" in success) exit 0;; failure) exit 9;; timeout) exit 124;; int) kill -INT $sysparams[pid];; term) kill -TERM $sysparams[pid];; esac )
            actual=$?; [[ "$actual" == "$expected" ]]
        }
        run_case success 0 && run_case failure 9 && run_case timeout 124 && run_case int 130 && run_case term 143 || exit 72
        task_home="" task_home_identity="" derived_data_path="" derived_data_identity=""; create_task_home || exit 73; create_derived_data || exit 73; retained_home=$task_home; /bin/chmod 755 "$derived_data_path"; validate_derived_data && exit 73; /bin/chmod 700 "$derived_data_path"
        sibling="${task_home}.sibling"; /bin/mkdir -m 700 "$sibling" || exit 74; /bin/chmod 755 "$task_home"
        cleanup_task_home && exit 74; [[ -d "$retained_home" ]] || exit 75; /bin/chmod 700 "$task_home"; cleanup_task_home || exit 76
        [[ ! -e "$retained_home" && -d "$sibling" ]] || exit 77; /bin/rmdir "$sibling" || exit 78
        task_home="" task_home_identity="" derived_data_path="" derived_data_identity=""; create_task_home || exit 79; create_derived_data || exit 79; pinned_home=$task_home; moved_home="${task_home}.original"
        sibling="${task_home}.sibling" replacement="${task_home}.cleanup"; /bin/mkdir -m 700 "$sibling" || exit 80; race_mode=replace
        result=$(cleanup_task_home && print -r -- 'cleanup=complete'); actual=$?
        [[ "$actual" == 70 && "$result" != *cleanup=complete* ]] || exit 81; [[ ! -e "$pinned_home" && -d "$moved_home" && -d "$replacement" && -d "$sibling" ]] || exit 82
        [[ "$(/usr/bin/stat -f '%u|%Lp|%d|%i' "$moved_home")" == "$task_home_identity" && -n "$task_home" && -n "$task_home_identity" ]] || exit 83
        /bin/rmdir "$moved_home/DerivedData" "$moved_home" "$replacement" "$sibling" || exit 85; race_mode=none
        task_home="" task_home_identity="" derived_data_path="" derived_data_identity=""; create_task_home || exit 86; create_derived_data || exit 86; collision="${task_home}.cleanup"; /bin/mkdir -m 700 "$collision"
        result=$(cleanup_task_home && print -r -- 'cleanup=complete'); actual=$?; [[ "$actual" == 70 && "$result" != *cleanup=complete* && -d "$task_home" && -d "$collision" ]] || exit 87; /bin/rmdir "$task_home/DerivedData" "$task_home" "$collision"
        task_home="" task_home_identity="" derived_data_path="" derived_data_identity=""; create_task_home || exit 88; create_derived_data || exit 88; build_timeout_seconds=600; run_external_storage_build || exit 88
        original="${derived_data_path}.original" sibling="${derived_data_path}.sibling"; /bin/mv "$derived_data_path" "$original"; /bin/mkdir -m 700 "$derived_data_path" "$sibling"
        result=$(run_external_storage_test && print -r -- 'test=executed'); actual=$?; [[ "$actual" == 70 && "$phase_executions" == 1 && "$result" != *test=executed* ]] || exit 89
        result=$(cleanup_task_home && print -r -- 'cleanup=complete'); actual=$?; [[ "$actual" == 70 && "$result" != *cleanup=complete* && -n "$derived_data_identity" ]] || exit 90
        [[ -d "$original" && -d "$derived_data_path" && -d "$sibling" && "$(/usr/bin/stat -f '%u|%Lp|%d|%i' "$original")" == "$derived_data_identity" ]] || exit 91
        /bin/rmdir "$original" "$derived_data_path" "$sibling" "$task_home" || exit 92
        print -r -- home_cleanup_matrix=pass
        """
        let lifecycle = Process(); let lifecycleOutput = Pipe(); lifecycle.executableURL = URL(fileURLWithPath: "/bin/zsh"); lifecycle.arguments = ["-c", lifecycleShell]
        lifecycle.standardOutput = lifecycleOutput; lifecycle.standardError = lifecycleOutput; try lifecycle.run(); lifecycle.waitUntilExit()
        let result = String(decoding: lifecycleOutput.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(lifecycle.terminationStatus == 0); #expect(result == "home_cleanup_matrix=pass\n")
    }
    @Test func hostedFoundationPathsAreConfinedBeforeExternalIO() throws { if getenv("HOLDTYPE_DEV_VLOGS_STORAGE_VALIDATE_PRIVATE_HOME") != nil { try validateFoundationStorageIsolation() } }
    @Test func externalAuthorityEvidenceIsClosedAndFailClosedWithoutExternalIO() throws {
        let root = URL(fileURLWithPath: "/Volumes/redacted-fixture", isDirectory: true)
        let authorization = DevVlogsExternalStorageAuthorization(volumeRootURL: root,
            destinationClass: .externalSSD, filesystemClass: .apfs)
        func evidence(mount: URL = root, destination: DevVlogsStorageDestinationClass? = .externalSSD, filesystem: DevVlogsStorageFilesystemClass? = .apfs,
            external: Bool = true, local: Bool = true,
            writable: Bool = true, symlink: Bool = false) -> DevVlogsExternalVolumeEvidence {
            .init(mountRootURL: mount, destinationClass: destination, filesystemClass: filesystem,
                  isPhysicalExternal: external, isLocal: local, isWritable: writable, containsSymbolicLink: symlink)
        }
        try DevVlogsStorageRunRoot.validateExternalAuthorization(authorization, evidence: evidence())
        func reject(_ candidateEvidence: DevVlogsExternalVolumeEvidence, authorization candidate: DevVlogsExternalStorageAuthorization = authorization) {
            #expect(throws: DevVlogsStorageHarnessError.invalidExternalAuthorization) { try DevVlogsStorageRunRoot.validateExternalAuthorization(candidate, evidence: candidateEvidence) }
        }
        reject(evidence(mount: URL(fileURLWithPath: "/")), authorization: .init(volumeRootURL:
            URL(fileURLWithPath: "/"), destinationClass: .externalSSD, filesystemClass: .apfs)); let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        for broad in [home, home.deletingLastPathComponent()] { reject(evidence(mount: broad),
            authorization: .init(volumeRootURL: broad, destinationClass: .externalSSD, filesystemClass: .apfs)) }
        reject(evidence(external: false)); reject(evidence(destination: .externalHDD))
        reject(evidence(destination: nil)); reject(evidence(filesystem: .exfat)); reject(evidence(filesystem: nil)); reject(evidence(local: false)); reject(evidence(writable: false))
        reject(evidence(mount: URL(fileURLWithPath: "/Volumes/alias"))); reject(evidence(symlink: true))
    }
    @Test func simulatedExternalAuthorityCapsWritesAndRemovesItsExactPrefix() throws {
        let outer = try makeRoot()
        defer { cleanupIfOwned(outer) }
        let base = try outer.ownedURL(relativePath: "simulated-volume")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        let prefix = base.appendingPathComponent(DevVlogsStorageRunRoot.externalPrefixName)
        #expect(!FileManager.default.fileExists(atPath: prefix.path))
        let root = try DevVlogsStorageRunRoot(runID: UUID(), authority: .simulatedExternalFixture(base))
        defer { cleanupIfOwned(root) }
        _ = try root.writeSynchronously(Data(count: 64 * 1024), relativePath: "active/bounded.partial")
        #expect(throws: DevVlogsStorageHarnessError.writeLimitExceeded) {
            _ = try root.writeSynchronously(Data(count: 64 * 1024 + 1), relativePath: "active/too-large")
        }
        #expect(try root.cleanup() == .complete)
        #expect(!FileManager.default.fileExists(atPath: prefix.path))
    }
    @Test func externalPrefixMustBeNewAndAmbiguousCleanupStaysPending() throws {
        let outer = try makeRoot()
        defer { cleanupIfOwned(outer) }
        let base = try outer.ownedURL(relativePath: "simulated-volume")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        let prefix = base.appendingPathComponent(DevVlogsStorageRunRoot.externalPrefixName)
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: false)
        #expect(throws: DevVlogsStorageHarnessError.prefixAlreadyExists) {
            _ = try DevVlogsStorageRunRoot(runID: UUID(), authority: .simulatedExternalFixture(base))
        }
        try FileManager.default.removeItem(at: prefix)
        let root = try DevVlogsStorageRunRoot(runID: UUID(), authority: .simulatedExternalFixture(base))
        defer { cleanupIfOwned(root) }
        let unexpected = prefix.appendingPathComponent("unexpected")
        try Data("owned-fixture".utf8).write(to: unexpected, options: .withoutOverwriting)
        #expect(root.cleanupClassification() == .pendingReconnect)
        #expect(FileManager.default.fileExists(atPath: root.rootURL.path))
        try FileManager.default.removeItem(at: unexpected)
        #expect(try root.cleanup() == .complete)
    }
    @Test func actualExternalAuthorityRejectsInternalOrSymlinkBaseBeforeScratchCreation() throws {
        let internalBase = FileManager.default.temporaryDirectory.standardizedFileURL
        let prefix = internalBase.appendingPathComponent(DevVlogsStorageRunRoot.externalPrefixName)
        let existed = FileManager.default.fileExists(atPath: prefix.path)
        #expect(throws: DevVlogsStorageHarnessError.invalidExternalAuthorization) {
            _ = try DevVlogsStorageRunRoot(runID: UUID(), authority: .explicitlyAuthorizedExternal(
                .init(volumeRootURL: internalBase, destinationClass: .externalSSD,
                      filesystemClass: .apfs)))
        }
        #expect(FileManager.default.fileExists(atPath: prefix.path) == existed)
        let outer = try makeRoot(); defer { cleanupIfOwned(outer) }
        let target = try outer.ownedURL(relativePath: "external-target")
        let alias = try outer.ownedURL(relativePath: "external-alias")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        #expect(throws: DevVlogsStorageHarnessError.symbolicLink) {
            _ = try DevVlogsStorageRunRoot(runID: UUID(), authority: .explicitlyAuthorizedExternal(
                .init(volumeRootURL: alias, destinationClass: .externalSSD, filesystemClass: .apfs)))
        }
    }
    private func makeRoot() throws -> DevVlogsStorageRunRoot { try DevVlogsStorageRunRoot(runID: UUID()) }
    private func cleanupIfOwned(_ root: DevVlogsStorageRunRoot) {
        if FileManager.default.fileExists(atPath: root.rootURL.path) { _ = try? root.cleanup() }
    }
    private func restoreMarkerAndCleanup(_ root: DevVlogsStorageRunRoot) {
        guard FileManager.default.fileExists(atPath: root.rootURL.path) else { return }
        let marker = root.rootURL.appendingPathComponent(DevVlogsStorageRunRoot.markerName)
        if FileManager.default.fileExists(atPath: marker.path) {
            try? Data(root.runID.uuidString.lowercased().utf8).write(to: marker)
        } else { try? root.restoreMissingMarkerForInternalTestTeardown() }
        _ = try? root.cleanup()
    }
    private func unlinkSymbolicLinkIfPresent(at url: URL) {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0, (metadata.st_mode & S_IFMT) == S_IFLNK else { return }
        _ = unlink(url.path)
    }
}
@Suite(.serialized)
struct DevVlogsExternalStorageRuntimeTests {
    @Test func explicitExternalRootRunsBoundedMechanicsOnlyWhenEnabled() throws {
        guard let configuration = try DevVlogsExternalStorageRuntimeConfiguration.load() else { return }
        do {
            try validateFoundationStorageIsolation()
            let root = try DevVlogsStorageRunRoot(runID: configuration.runID,
                authority: .explicitlyAuthorizedExternal(configuration.authorization))
            defer { let cleanup = root.cleanupClassification()
                print("case=\(configuration.caseID) cleanup=\(cleanup.rawValue)"); #expect(cleanup == .complete) }
            let capacity = try DevVlogsURLStorageCapacityProvider().usefulCapacity(at: root.rootURL)
            #expect((capacity ?? 0) > 0)
            let bytes = Data("external-mechanics-fixture".utf8)
            _ = try root.writeSynchronously(bytes, relativePath: "active/attempt.partial")
            let final = try root.promoteExclusively(fragmentRelativePath: "active/attempt.partial",
                finalRelativePath: "final/attempt.fixture")
            #expect(try Data(contentsOf: final) == bytes)
            _ = try root.writeSynchronously(Data("existing".utf8), relativePath: "final/collision.fixture")
            _ = try root.writeSynchronously(Data("candidate".utf8), relativePath: "active/collision.partial")
            #expect(throws: DevVlogsStorageHarnessError.itemExists) {
                _ = try root.promoteExclusively(fragmentRelativePath: "active/collision.partial",
                    finalRelativePath: "final/collision.fixture")
            }
            #expect(try Data(contentsOf: root.ownedURL(relativePath: "final/collision.fixture")) == Data("existing".utf8))
            #expect(try Data(contentsOf: root.ownedURL(relativePath: "active/collision.partial")) == Data("candidate".utf8))
            let folder = try root.ownedURL(relativePath: "bookmark-source")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            let bookmark = try DevVlogsOrdinaryBookmark.create(for: folder)
            let renamed = try root.ownedURL(relativePath: "bookmark-renamed")
            try FileManager.default.moveItem(at: folder, to: renamed)
            let resolution = try DevVlogsOrdinaryBookmark.resolve(bookmark)
            #expect(resolution.url.standardizedFileURL == renamed.standardizedFileURL)
            print("case=\(configuration.caseID) destination=\(configuration.authorization.destinationClass.rawValue) filesystem=\(configuration.authorization.filesystemClass.rawValue) write_bytes=\(bytes.count) promotion=pass collision=pass bookmark_rename=pass stale=\(resolution.isStale)")
        } catch {
            print("case=\(configuration.caseID) result=failed error=redacted")
            Issue.record("External storage mechanics failed with a redacted error.")
        }
    }
}
private func validateFoundationStorageIsolation() throws {
    let fileManager = FileManager.default; let home = fileManager.homeDirectoryForCurrentUser.resolvingSymlinksInPath()
    let prefix = "holdtype-dev-vlogs-storage-home."; let name = home.lastPathComponent
    guard home.deletingLastPathComponent().path == "/private/tmp", name.hasPrefix(prefix),
          name.dropFirst(prefix.count).count == 8,
          name.dropFirst(prefix.count).allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
        throw DevVlogsStoragePrivateHomeError.homeDirectory }
    guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory,
        in: .userDomainMask).first?.resolvingSymlinksInPath() else { throw DevVlogsStoragePrivateHomeError.applicationSupport }
    let recovery = applicationSupport.appendingPathComponent("HoldType", isDirectory: true)
        .appendingPathComponent("TranscriptionRecovery", isDirectory: true).standardizedFileURL
    let homeComponents = home.pathComponents
    guard [applicationSupport, recovery].allSatisfy({ $0.pathComponents.count > homeComponents.count &&
        Array($0.pathComponents.prefix(homeComponents.count)) == homeComponents }) else {
        throw DevVlogsStoragePrivateHomeError.descendant }
}
private enum DevVlogsStoragePrivateHomeError: Error { case homeDirectory, applicationSupport, descendant }
private struct FixedCapacityProvider: DevVlogsStorageCapacityProviding { let capacity: Int64?; func usefulCapacity(at destinationURL: URL) throws -> Int64? { capacity } }
private struct FixedDestinationProvider: DevVlogsStorageDestinationStateProviding { let state: DevVlogsStorageDestinationState; func state(at destinationURL: URL) throws -> DevVlogsStorageDestinationState { state } }
struct CapacityCase: CustomTestStringConvertible, Sendable { let name: String; let state: DevVlogsStorageDestinationState; let capacity: Int64?
    let reserve: Int64; let expected: DevVlogsStoragePreflightResult; var testDescription: String { name } }
private let capacityCases: [CapacityCase] = [
    .init(name: "unavailable", state: .init(isAvailable: false, isLocal: true, isReadOnly: false), capacity: 100, reserve: 50, expected: .skip(.unavailable)),
    .init(name: "read-only", state: .init(isAvailable: true, isLocal: true, isReadOnly: true), capacity: 100, reserve: 50, expected: .skip(.readOnly)),
    .init(name: "nonlocal", state: .init(isAvailable: true, isLocal: false, isReadOnly: false), capacity: 100, reserve: 50, expected: .skip(.nonlocal)),
    .init(name: "capacity-nil", state: .init(isAvailable: true, isLocal: true, isReadOnly: false), capacity: nil, reserve: 50, expected: .skip(.capacityUnknown)),
    .init(name: "below-reserve", state: .init(isAvailable: true, isLocal: true, isReadOnly: false), capacity: 49, reserve: 50, expected: .skip(.insufficientCapacity)),
    .init(name: "exact-reserve", state: .init(isAvailable: true, isLocal: true, isReadOnly: false), capacity: 50, reserve: 50, expected: .proceed(usefulCapacity: 50, suppliedReserve: 50)),
    .init(name: "sufficient", state: .init(isAvailable: true, isLocal: true, isReadOnly: false), capacity: 51, reserve: 50, expected: .proceed(usefulCapacity: 51, suppliedReserve: 50)),
]
