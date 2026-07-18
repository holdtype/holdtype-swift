import Foundation
import HoldTypeDomain
import SwiftUI

struct IOSReplacementRuleRowModel: Identifiable, Equatable {
    let rule: TextReplacementRule
    let position: Int
    let totalCount: Int

    var id: UUID { rule.id }

    static func makeRows(
        from rules: [TextReplacementRule]
    ) -> [IOSReplacementRuleRowModel] {
        rules.enumerated().map { index, rule in
            IOSReplacementRuleRowModel(
                rule: rule,
                position: index,
                totalCount: rules.count
            )
        }
    }

    static func filter(
        _ rows: [IOSReplacementRuleRowModel],
        normalizedQuery: String
    ) -> [IOSReplacementRuleRowModel] {
        guard !normalizedQuery.isEmpty else { return rows }
        return rows.filter { row in
            row.rule.search.localizedStandardContains(normalizedQuery)
                || row.rule.replacement.localizedStandardContains(
                    normalizedQuery
                )
        }
    }
}

struct IOSReplacementRuleListRow: View {
    let row: IOSReplacementRuleRowModel
    let operationInFlight: Bool
    let allowsReordering: Bool
    let onSetEnabled: (TextReplacementRule, Bool) -> Void
    let onRequestDelete: (TextReplacementRule) -> Void
    let onMove: (UUID, IOSReplacementRulesMoveDirection) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(
                "Enable Rule",
                isOn: Binding(
                    get: { row.rule.isEnabled },
                    set: { onSetEnabled(row.rule, $0) }
                )
            )
            .labelsHidden()
            .accessibilityLabel(toggleAccessibilityLabel)
            .disabled(operationInFlight)

            NavigationLink(
                value: IOSLibraryRoute.replacementRule(row.rule.id)
            ) {
                rowContent
            }
            .accessibilityActions {
                Button("Delete Rule") {
                    onRequestDelete(row.rule)
                }
                if allowsReordering, row.position > 0 {
                    Button("Move Up") {
                        onMove(row.rule.id, .up)
                    }
                }
                if allowsReordering, row.position + 1 < row.totalCount {
                    Button("Move Down") {
                        onMove(row.rule.id, .down)
                    }
                }
            }
            .accessibilityIdentifier(
                "ios.library.replacement-rules.rule."
                    + row.rule.id.uuidString.lowercased()
            )
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                onRequestDelete(row.rule)
            }
        }
        .contextMenu {
            Button("Delete Rule", role: .destructive) {
                onRequestDelete(row.rule)
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            searchLabel
            replacementLabel
            HStack(spacing: 4) {
                Image(systemName: status.systemImage)
                    .foregroundStyle(statusColor)
                Text(status.title)
                    .foregroundStyle(.primary)
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            "Position \(row.position + 1) of \(row.totalCount)"
        )
    }

    @ViewBuilder
    private var searchLabel: some View {
        if row.rule.hasSearchText {
            Text(row.rule.search)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        } else {
            Label(
                "Empty Search",
                systemImage: "text.badge.xmark"
            )
            .font(.body.weight(.medium))
            .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var replacementLabel: some View {
        if row.rule.replacement.isEmpty {
            Text("Removes matching text")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if replacementContainsOnlyWhitespace {
            Text("Replacement contains only whitespace")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("Replace with: \(row.rule.replacement)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var status: IOSReplacementRuleRuntimeStatus {
        IOSReplacementRuleRuntimeStatus(rule: row.rule)
    }

    private var statusColor: Color {
        switch status {
        case .active: .green
        case .off: .secondary
        case .inactiveEmptySearch: .orange
        }
    }

    private var replacementContainsOnlyWhitespace: Bool {
        !row.rule.replacement.isEmpty
            && row.rule.replacement.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
    }

    private var toggleAccessibilityLabel: String {
        row.rule.hasSearchText
            ? "Enable rule for \(row.rule.search)"
            : "Enabled preference for rule with empty Search"
    }

    private var accessibilityLabel: String {
        let search = row.rule.hasSearchText
            ? row.rule.search
            : "Empty search"
        let replacement: String
        if row.rule.replacement.isEmpty {
            replacement = "removes matching text"
        } else if replacementContainsOnlyWhitespace {
            replacement = "replacement contains only whitespace"
        } else {
            replacement = "replace with \(row.rule.replacement)"
        }
        return "\(search), \(replacement), \(status.title)"
    }
}

extension IOSReplacementRuleRowModel: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSReplacementRuleListRow: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

#Preview("Replacement rule row") {
    let rule = TextReplacementRule(
        id: UUID(
            uuid: (0x20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        ),
        search: "colour",
        replacement: "color"
    )

    NavigationStack {
        List {
            IOSReplacementRuleListRow(
                row: IOSReplacementRuleRowModel(
                    rule: rule,
                    position: 0,
                    totalCount: 1
                ),
                operationInFlight: false,
                allowsReordering: false,
                onSetEnabled: { _, _ in },
                onRequestDelete: { _ in },
                onMove: { _, _ in }
            )
        }
        .navigationTitle("Replacements")
    }
}
