#if DEBUG
import Darwin
import Foundation

@_silgen_name("_NSGetEnviron")
private func devVlogsNSGetEnviron() -> UnsafeMutablePointer<
    UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
>

enum DevVlogsPhase0BProtectedStorageObserverAction: String, CaseIterable {
    case none
    case ensureRecoveryDirectory = "ensure_recovery_directory"
    case copyRecoveryAudio = "copy_recovery_audio"
    case replaceRecoveryIndex = "replace_recovery_index"
    case writeSavedStateMarker = "write_saved_state_marker"
    case writeProcessingCheckpointMarker = "write_processing_checkpoint_marker"
    case writeProviderDispatchMarker = "write_provider_dispatch_marker"
    case deleteSavedStateMarker = "delete_saved_state_marker"
    case deleteProcessingCheckpointMarker = "delete_processing_checkpoint_marker"
    case deleteProviderDispatchMarker = "delete_provider_dispatch_marker"
    case deleteRecoveryAudio = "delete_recovery_audio"
}

enum DevVlogsPhase0BProtectedStorageObserverCategory: String, CaseIterable {
    case observer
    case recoveryDirectory = "recovery_directory"
    case recoveryIndex = "recovery_index"
    case recoveryMarker = "recovery_marker"
    case recoveryAudio = "recovery_audio"
}

enum RecoveryArtifactDeletionKind: CaseIterable {
    case failedAttemptEmergencyAudio
    case savedStateRepairMarker
    case processingCheckpointMarker
    case providerDispatchMarker
    case managedRecoveryAudio

    var observation: (
        action: DevVlogsPhase0BProtectedStorageObserverAction,
        category: DevVlogsPhase0BProtectedStorageObserverCategory
    ) {
        switch self {
        case .failedAttemptEmergencyAudio, .managedRecoveryAudio:
            return (.deleteRecoveryAudio, .recoveryAudio)
        case .savedStateRepairMarker:
            return (.deleteSavedStateMarker, .recoveryMarker)
        case .processingCheckpointMarker:
            return (.deleteProcessingCheckpointMarker, .recoveryMarker)
        case .providerDispatchMarker:
            return (.deleteProviderDispatchMarker, .recoveryMarker)
        }
    }
}

struct DevVlogsPhase0BProtectedStorageObserverInstallConfiguration: Equatable {
    let runID: UUID
    let taskHome: URL
}

@MainActor
enum DevVlogsPhase0BProtectedStorageObserverConfiguration {
    static let modeEnvironmentKey =
        "HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER"
    static let runIDEnvironmentKey =
        "HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_RUN_ID"
    static let caseIDEnvironmentKey =
        "HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER_CASE_ID"
    static let privateHomeValidationEnvironmentKey =
        "HOLDTYPE_DEV_VLOGS_STORAGE_VALIDATE_PRIVATE_HOME"
    static let modeValue = "stderr-json-v1"
    static let caseIDValue = "protected_metadata"

    static let observerKeys = [
        modeEnvironmentKey,
        runIDEnvironmentKey,
        caseIDEnvironmentKey,
    ]

    static func isPresent(environment: [String: String]) -> Bool {
        environment.keys.contains {
            $0.hasPrefix("HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER")
        }
    }

    static func resolveAndInstall(
        environment: [String: String],
        rawEnvironment: [String]? = nil,
        install: (DevVlogsPhase0BProtectedStorageObserverInstallConfiguration) -> Void
    ) -> Result<DevVlogsPhase0BStorageTestHostValidation,
        DevVlogsPhase0BStorageTestHostLaunchError> {
        let acceptedKeys = Set(observerKeys)
        guard !environment.keys.contains(where: {
            $0.hasPrefix("HOLDTYPE_DEV_VLOGS_PHASE_0B_PROTECTED_STORAGE_OBSERVER")
                && !acceptedKeys.contains($0)
        }) else {
            return .failure(.unknownObserverValue)
        }
        let required = observerKeys + [
            DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey,
            privateHomeValidationEnvironmentKey,
            KeychainInteractionPolicy.automationEnvironmentKey,
            KeychainInteractionPolicy.authenticationUIEnvironmentKey,
            "HOME", "CFFIXED_USER_HOME", "TMPDIR",
        ]
        let entries = rawEnvironment ?? environment.map { "\($0.key)=\($0.value)" }
        guard required.allSatisfy({ key in
            entries.lazy.filter { $0.hasPrefix("\(key)=") }.count == 1
        }) else {
            return .failure(.duplicateOrMissingObserverValue)
        }
        guard environment[modeEnvironmentKey] == modeValue,
              environment[caseIDEnvironmentKey] == caseIDValue,
              environment[privateHomeValidationEnvironmentKey] == "1",
              environment[DevVlogsPhase0BStorageTestHostConfiguration.hostEnvironmentKey] == "1",
              environment[KeychainInteractionPolicy.automationEnvironmentKey] == "1",
              environment[KeychainInteractionPolicy.authenticationUIEnvironmentKey]
                == KeychainInteractionPolicy.skipAuthenticationUIValue,
              let rawRunID = environment[runIDEnvironmentKey],
              let runID = UUID(uuidString: rawRunID),
              runID.uuidString.lowercased() == rawRunID,
              let rawHome = environment["HOME"],
              let rawFixedHome = environment["CFFIXED_USER_HOME"],
              rawHome == rawFixedHome,
              let home = standardizedAbsoluteURL(rawHome),
              let rawTemporary = environment["TMPDIR"],
              let temporary = standardizedAbsoluteURL(rawTemporary),
              isStrictDescendant(temporary, of: home) else {
            return .failure(.invalidObserverConfiguration)
        }
        let conflicts = DevVlogsPhase0BStorageTestHostConfiguration.runtimeEnvironmentKeys
            + DevVlogsPhase0BStorageTestHostConfiguration.existingRouteEnvironmentKeys
        guard !conflicts.contains(where: { environment[$0] != nil }) else {
            return .failure(.conflictingRoute)
        }
        install(.init(runID: runID, taskHome: home))
        return .success(.validated)
    }

    static func currentRawEnvironment() -> [String] {
        guard var cursor = devVlogsNSGetEnviron().pointee else { return [] }
        var entries: [String] = []
        while let entry = cursor.pointee {
            entries.append(String(cString: entry))
            cursor = cursor.advanced(by: 1)
        }
        return entries
    }

    private static func standardizedAbsoluteURL(_ value: String) -> URL? {
        guard value.hasPrefix("/"), value != "/", !value.hasSuffix("/"),
              !value.contains("\n") else { return nil }
        let url = URL(fileURLWithPath: value).standardizedFileURL
        return url.path == value ? url : nil
    }

    private static func isStrictDescendant(_ child: URL, of parent: URL) -> Bool {
        child.path.hasPrefix(parent.path + "/")
    }
}

@MainActor
final class DevVlogsPhase0BProtectedStorageObserver {
    static let shared = DevVlogsPhase0BProtectedStorageObserver()
    static let prefix = "HTDV_P0B_PROTECTED_STORAGE_OBSERVER_V1 "
    static let maximumEvents = 128
    static let maximumLineBytes = 512

    private enum Event: String {
        case observerReady = "observer_ready"
        case ownerInitialized = "owner_initialized"
        case mutationBegin = "mutation_begin"
        case mutationEnd = "mutation_end"
        case observerOverflow = "observer_overflow"
    }

    private enum TargetScope: String {
        case notApplicable = "not_applicable"
        case privateTaskHome = "private_task_home"
        case outsidePrivateTaskHome = "outside_private_task_home"
        case indeterminate
    }

    private enum Result: String {
        case ready
        case observed
        case attempted
        case succeeded
        case failed
        case overflow
    }

    private var configuration: DevVlogsPhase0BProtectedStorageObserverInstallConfiguration?
    private var sequence = 0
    private var invalidated = false
    private(set) var ownerInitializationCount = 0
    private(set) var latestOwnerScopeWasPrivate = false
    private var sink: (String) -> Void = { line in
        FileHandle.standardError.write(Data(line.utf8))
    }

    func install(
        _ configuration: DevVlogsPhase0BProtectedStorageObserverInstallConfiguration
    ) {
        guard self.configuration == nil else {
            invalidated = true
            return
        }
        self.configuration = configuration
        emit(
            event: .observerReady,
            action: .none,
            category: .observer,
            scope: .notApplicable,
            result: .ready
        )
    }

    func recordOwnerInitialization(directoryURL: URL) {
        let scope = classifyTargetScope(directoryURL)
        if configuration != nil {
            ownerInitializationCount += 1
            latestOwnerScopeWasPrivate = scope == .privateTaskHome
        }
        emit(
            event: .ownerInitialized,
            action: .none,
            category: .recoveryDirectory,
            scope: scope,
            result: .observed
        )
    }

    func observeMutation<T>(
        action: DevVlogsPhase0BProtectedStorageObserverAction,
        category: DevVlogsPhase0BProtectedStorageObserverCategory,
        targetURL: URL,
        operation: () throws -> T
    ) rethrows -> T {
        let scope = classifyTargetScope(targetURL)
        emit(event: .mutationBegin, action: action, category: category,
             scope: scope, result: .attempted)
        do {
            let value = try operation()
            emit(event: .mutationEnd, action: action, category: category,
                 scope: scope, result: .succeeded)
            return value
        } catch {
            emit(event: .mutationEnd, action: action, category: category,
                 scope: scope, result: .failed)
            throw error
        }
    }

    var evidenceInvalidated: Bool { invalidated }
    var isInstalledForTesting: Bool { configuration != nil && !invalidated }

    func resetForTesting(sink: @escaping (String) -> Void = { line in
        FileHandle.standardError.write(Data(line.utf8))
    }) {
        configuration = nil
        sequence = 0
        invalidated = false
        ownerInitializationCount = 0
        latestOwnerScopeWasPrivate = false
        self.sink = sink
    }

    private func classifyTargetScope(_ url: URL) -> TargetScope {
        guard let configuration,
              url.path.hasPrefix("/"),
              url.standardizedFileURL.path == url.path else { return .indeterminate }
        return url.path.hasPrefix(configuration.taskHome.path + "/")
            ? .privateTaskHome : .outsidePrivateTaskHome
    }

    private func emit(
        event: Event,
        action: DevVlogsPhase0BProtectedStorageObserverAction,
        category: DevVlogsPhase0BProtectedStorageObserverCategory,
        scope: TargetScope,
        result: Result
    ) {
        guard let configuration, !invalidated else { return }
        guard sequence < Self.maximumEvents - 1 else {
            if sequence < Self.maximumEvents {
                sequence += 1
                writeLine(
                    configuration: configuration,
                    event: .observerOverflow,
                    action: .none,
                    category: .observer,
                    scope: .notApplicable,
                    result: .overflow
                )
            }
            invalidated = true
            return
        }
        sequence += 1
        writeLine(
            configuration: configuration,
            event: event,
            action: action,
            category: category,
            scope: scope,
            result: result
        )
    }

    private func writeLine(
        configuration: DevVlogsPhase0BProtectedStorageObserverInstallConfiguration,
        event: Event,
        action: DevVlogsPhase0BProtectedStorageObserverAction,
        category: DevVlogsPhase0BProtectedStorageObserverCategory,
        scope: TargetScope,
        result: Result
    ) {
        let line = Self.prefix
            + "{\"schema_version\":1,\"run_id\":\"\(configuration.runID.uuidString.lowercased())\","
            + "\"case_id\":\"protected_metadata\",\"sequence\":\(sequence),"
            + "\"event\":\"\(event.rawValue)\",\"action\":\"\(action.rawValue)\","
            + "\"category\":\"\(category.rawValue)\",\"target_scope\":\"\(scope.rawValue)\","
            + "\"result\":\"\(result.rawValue)\"}\n"
        guard line.utf8.count <= Self.maximumLineBytes else {
            invalidated = true
            return
        }
        sink(line)
    }
}
#endif
