import HoldTypeDomain
import SwiftUI

struct IOSBuiltInEmojiCommandRow: View {
    let command: EmojiCommand

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(command.emoji)
                .font(.title2)
                .frame(minWidth: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(command.primarySpokenPhrase)
                if !command.secondarySpokenPhrases.isEmpty {
                    Text(command.secondarySpokenPhrases.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Built-in emoji command row") {
    List {
        IOSBuiltInEmojiCommandRow(
            command: EmojiCommand(
                id: "launch",
                emoji: "🚀",
                displayName: "Launch",
                aliases: ["emoji launch", "emoji rocket"]
            )
        )
    }
}
