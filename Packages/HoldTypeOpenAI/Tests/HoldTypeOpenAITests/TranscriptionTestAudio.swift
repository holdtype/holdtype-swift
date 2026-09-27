import Foundation

enum TranscriptionTestAudio {
    static var wav: Data {
        var data = Data("RIFF".utf8)
        func append(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        append(65_572)
        data.append(Data("WAVEfmt ".utf8))
        append(16)
        data.append(contentsOf: [1, 0, 1, 0])
        append(8192)
        append(16384)
        data.append(contentsOf: [2, 0, 16, 0])
        data.append(Data("data".utf8))
        append(65_536)
        data.append(Data(repeating: 0, count: 65_536))
        return data
    }
}
