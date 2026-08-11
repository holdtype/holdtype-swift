import AVFoundation
import Combine
import Foundation

protocol AudioInputDeviceProviding {
    func availableDevices() -> [AudioInputDevice]
}

struct AVFoundationAudioInputDeviceProvider: AudioInputDeviceProviding {
    func availableDevices() -> [AudioInputDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
            .filter { $0.isConnected && !$0.isSuspended }
            .map { AudioInputDevice(id: $0.uniqueID, name: $0.localizedName) }
            .sorted {
                let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
                return nameOrder == .orderedAscending
                    || (nameOrder == .orderedSame && $0.id < $1.id)
            }
    }
}

@MainActor
final class AudioInputDeviceListModel: ObservableObject {
    @Published private(set) var devices: [AudioInputDevice]

    private let provider: any AudioInputDeviceProviding

    init(provider: any AudioInputDeviceProviding) {
        self.provider = provider
        self.devices = provider.availableDevices()
    }

    func refresh() {
        devices = provider.availableDevices()
    }
}
