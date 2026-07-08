//
//  SoftwareUpdateService.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import Combine
import Foundation
import Sparkle

struct SoftwareUpdateConfiguration: Equatable {
    let feedURL: URL?
    let publicKey: String?

    var isConfigured: Bool {
        feedURL != nil && publicKey?.isEmpty == false
    }

    var feedDisplayText: String {
        guard let feedURL else {
            return "Not configured"
        }

        return feedURL.absoluteString
    }
}

@MainActor
enum SoftwareUpdateRelaunchState {
    private(set) static var isUpdaterRelaunchInProgress = false

    static func prepareForUpdaterRelaunch() {
        isUpdaterRelaunchInProgress = true
    }
}

@MainActor
final class SoftwareUpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = SoftwareUpdateService()

    @Published private(set) var canCheckForUpdates = false

    let configuration: SoftwareUpdateConfiguration
    let currentVersionText: String
    let currentBuildText: String

    private var updaterController: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?

    private override init() {
        let bundle = Bundle.main
        configuration = Self.loadConfiguration(from: bundle)
        currentVersionText = Self.stringValue(
            for: "CFBundleShortVersionString",
            in: bundle,
            fallback: "Unknown"
        )
        currentBuildText = Self.stringValue(
            for: "CFBundleVersion",
            in: bundle,
            fallback: "Unknown"
        )

        super.init()

        guard configuration.isConfigured else {
            return
        }

        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.updaterController = updaterController
        canCheckForUpdates = updaterController.updater.canCheckForUpdates
        canCheckObservation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            DispatchQueue.main.async { [weak self] in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    var isConfigured: Bool {
        updaterController != nil
    }

    var versionAndBuildText: String {
        "Version \(currentVersionText) (\(currentBuildText))"
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            updaterController?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            updaterController?.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            updaterController?.updater.automaticallyDownloadsUpdates ?? false
        }
        set {
            updaterController?.updater.automaticallyDownloadsUpdates = newValue
            objectWillChange.send()
        }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
        SoftwareUpdateRelaunchState.prepareForUpdaterRelaunch()
        return true
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        SoftwareUpdateRelaunchState.prepareForUpdaterRelaunch()
    }

    private static func loadConfiguration(from bundle: Bundle) -> SoftwareUpdateConfiguration {
        let feedURLString = trimmedInfoValue(for: "SUFeedURL", in: bundle)
        let publicKey = trimmedInfoValue(for: "SUPublicEDKey", in: bundle)

        return SoftwareUpdateConfiguration(
            feedURL: feedURLString.flatMap(URL.init(string:)),
            publicKey: publicKey
        )
    }

    private static func stringValue(for key: String, in bundle: Bundle, fallback: String) -> String {
        trimmedInfoValue(for: key, in: bundle) ?? fallback
    }

    private static func trimmedInfoValue(for key: String, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
