import CoreAudio
import Foundation

protocol PrivateAudioOutputRouteProviding {
    func isPrivateAudioOutputRoute() -> Bool
}

struct CoreAudioPrivateOutputRouteProvider: PrivateAudioOutputRouteProviding {
    nonisolated init() {}

    func isPrivateAudioOutputRoute() -> Bool {
        guard let deviceID = defaultOutputDeviceID(),
              let name = outputDeviceName(deviceID) else {
            return false
        }

        return Self.isPrivateOutputName(name)
    }

    static func isPrivateOutputName(_ name: String) -> Bool {
        let normalized = name.lowercased()
        return [
            "airpods",
            "earbud",
            "earphone",
            "headphone",
            "headset",
            "beats",
        ].contains { normalized.contains($0) }
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }
        return deviceID
    }

    private func outputDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        )
        guard status == noErr, let value else {
            return nil
        }
        return value.takeUnretainedValue() as String
    }
}
