import Foundation

enum DevVlogsApplicationPolicyMode: String, CaseIterable, Codable, Equatable {
    case onlySelectedApps
    case allAppsExceptExcludedApps

    var title: String {
        switch self {
        case .onlySelectedApps:
            return "Only selected apps"
        case .allAppsExceptExcludedApps:
            return "All apps except excluded apps"
        }
    }
}

struct DevVlogsApplication: Codable, Equatable, Identifiable {
    let bundleIdentifier: String
    let displayName: String

    var id: String {
        bundleIdentifier
    }

    init?(bundleIdentifier: String, displayName: String) {
        let normalizedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBundleIdentifier.isEmpty else {
            return nil
        }

        self.bundleIdentifier = normalizedBundleIdentifier
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = normalizedDisplayName.isEmpty ? normalizedBundleIdentifier : normalizedDisplayName
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        let displayName = try container.decode(String.self, forKey: .displayName)
        guard let application = Self(bundleIdentifier: bundleIdentifier, displayName: displayName) else {
            throw DecodingError.dataCorruptedError(
                forKey: .bundleIdentifier,
                in: container,
                debugDescription: "Dev Vlogs applications require a bundle identifier."
            )
        }

        self = application
    }
}

enum DevVlogsApplicationPolicyError: Error, Equatable {
    case featureDisabled
    case duplicateBundleIdentifier
}

struct DevVlogsApplicationPolicy: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let defaultPolicy = DevVlogsApplicationPolicy(
        mode: .onlySelectedApps,
        selectedApps: [],
        excludedApps: []
    )

    let schemaVersion: Int
    private(set) var mode: DevVlogsApplicationPolicyMode
    private(set) var selectedApps: [DevVlogsApplication]
    private(set) var excludedApps: [DevVlogsApplication]

    init(
        mode: DevVlogsApplicationPolicyMode,
        selectedApps: [DevVlogsApplication],
        excludedApps: [DevVlogsApplication]
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.mode = mode
        self.selectedApps = selectedApps
        self.excludedApps = excludedApps
    }

    var activeApplications: [DevVlogsApplication] {
        switch mode {
        case .onlySelectedApps:
            selectedApps
        case .allAppsExceptExcludedApps:
            excludedApps
        }
    }

    var hasEffectiveEligibility: Bool {
        switch mode {
        case .onlySelectedApps:
            !selectedApps.isEmpty
        case .allAppsExceptExcludedApps:
            true
        }
    }

    mutating func setMode(_ mode: DevVlogsApplicationPolicyMode) {
        self.mode = mode
    }

    mutating func add(_ application: DevVlogsApplication) throws {
        switch mode {
        case .onlySelectedApps:
            guard !selectedApps.contains(where: { $0.bundleIdentifier == application.bundleIdentifier }) else {
                throw DevVlogsApplicationPolicyError.duplicateBundleIdentifier
            }
            selectedApps.append(application)
        case .allAppsExceptExcludedApps:
            guard !excludedApps.contains(where: { $0.bundleIdentifier == application.bundleIdentifier }) else {
                throw DevVlogsApplicationPolicyError.duplicateBundleIdentifier
            }
            excludedApps.append(application)
        }
    }

    mutating func remove(bundleIdentifier: String) {
        switch mode {
        case .onlySelectedApps:
            selectedApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        case .allAppsExceptExcludedApps:
            excludedApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case mode
        case selectedApps
        case excludedApps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "This Dev Vlogs application policy uses an unsupported schema."
            )
        }

        let mode = try container.decode(DevVlogsApplicationPolicyMode.self, forKey: .mode)
        let selectedApps = try container.decode([DevVlogsApplication].self, forKey: .selectedApps)
        let excludedApps = try container.decode([DevVlogsApplication].self, forKey: .excludedApps)
        guard Self.hasUniqueBundleIdentifiers(selectedApps), Self.hasUniqueBundleIdentifiers(excludedApps) else {
            throw DecodingError.dataCorruptedError(
                forKey: .selectedApps,
                in: container,
                debugDescription: "Dev Vlogs application policies cannot contain duplicate bundle identifiers."
            )
        }

        self.schemaVersion = schemaVersion
        self.mode = mode
        self.selectedApps = selectedApps
        self.excludedApps = excludedApps
    }

    private static func hasUniqueBundleIdentifiers(_ applications: [DevVlogsApplication]) -> Bool {
        Set(applications.map(\.bundleIdentifier)).count == applications.count
    }
}
