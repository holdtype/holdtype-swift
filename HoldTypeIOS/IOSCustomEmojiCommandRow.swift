import Foundation
import HoldTypeDomain
import SwiftUI

struct IOSCustomEmojiCommandRow: View {
    let command: CustomEmojiCommand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command.normalizedEmoji)
                .font(.title2)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            Text(command.displayCommand)
            let aliases = Array(command.normalizedSpokenPhrases.dropFirst())
            if !aliases.isEmpty {
                Text(aliases.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

extension IOSCustomEmojiCommandRow: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

#Preview("Custom emoji command row") {
    List {
        IOSCustomEmojiCommandRow(
            command: CustomEmojiCommand(
                id: UUID(
                    uuid: (
                        0x30, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 1
                    )
                ),
                emoji: "🚀",
                command: "emoji launch",
                aliases: ["emoji rocket"]
            )
        )
    }
}
