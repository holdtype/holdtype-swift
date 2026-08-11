import Foundation

struct AudioInputPreference: Equatable, Sendable {
    static let systemDefault = AudioInputPreference(deviceID: nil, deviceName: nil)

    let deviceID: String?
    let deviceName: String?

    init(deviceID: String?, deviceName: String?) {
        let normalizedID = deviceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedID, !normalizedID.isEmpty else {
            self.deviceID = nil
            self.deviceName = nil
            return
        }

        let normalizedName = deviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deviceID = normalizedID
        self.deviceName = normalizedName.flatMap { $0.isEmpty ? nil : $0 }
    }

    var isSystemDefault: Bool {
        deviceID == nil
    }

    var displayName: String {
        deviceName ?? "Selected microphone"
    }
}

struct AudioInputDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}
