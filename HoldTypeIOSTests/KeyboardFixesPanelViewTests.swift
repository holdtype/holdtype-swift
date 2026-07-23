import Testing
import UIKit

@Suite(.serialized)
@MainActor
struct KeyboardFixesPanelViewTests {
    @Test func panelRendersAllEnabledMetadataActions() throws {
        let panel = KeyboardFixesPanelView(
            frame: CGRect(x: 0, y: 0, width: 393, height: 128)
        )
        let presentation = try makePresentation()
        panel.render(presentation)
        panel.layoutIfNeeded()

        let collection = try #require(
            descendant(
                UICollectionView.self,
                identifier: "keyboard.brand-stage.fixes.actions",
                in: panel
            )
        )
        #expect(
            collection.dataSource?.collectionView(
                collection,
                numberOfItemsInSection: 0
            ) == presentation.enabledActions.count
        )
        #expect(
            descendant(
                UILabel.self,
                identifier: "keyboard.brand-stage.fixes.status",
                in: panel
            )?.isHidden == true
        )
    }

    @Test func panelRoutesOneEnabledTileSelection() throws {
        let panel = KeyboardFixesPanelView(
            frame: CGRect(x: 0, y: 0, width: 393, height: 128)
        )
        let presentation = try makePresentation()
        var requested: [String] = []
        panel.onActionRequested = { requested.append($0) }
        panel.render(presentation)
        let collection = try #require(
            descendant(
                UICollectionView.self,
                identifier: "keyboard.brand-stage.fixes.actions",
                in: panel
            )
        )

        collection.delegate?.collectionView?(
            collection,
            didSelectItemAt: IndexPath(item: 0, section: 0)
        )

        #expect(
            requested
                == [KeyboardFixBridgeConfiguration.translateIdentifier]
        )
    }

    @Test func brandStageCenterControlSwapsMutuallyExclusiveWorkspaces()
        throws {
        let view = BrandStageKeyboardView(
            frame: CGRect(x: 0, y: 0, width: 393, height: 302)
        )
        var visibility: [Bool] = []
        view.onFixesVisibilityChanged = { visibility.append($0) }
        view.render(
            BrandStageKeyboardPresentation(
                status: .ready,
                voiceStage: .ready,
                listeningCountdownSeconds: nil,
                automaticVoiceAction: .standard,
                fixes: try makePresentation(),
                latestIsEnabled: false,
                returnKey: .returnSymbol,
                returnIsEnabled: true,
                showsInputModeSwitchKey: true
            )
        )
        let host = UIView(
            frame: CGRect(x: 0, y: 0, width: 393, height: 302)
        )
        host.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            view.topAnchor.constraint(equalTo: host.topAnchor),
            view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        host.layoutIfNeeded()

        let fixes = try #require(
            descendant(
                UIButton.self,
                identifier: "keyboard.brand-stage.fixes-toggle",
                in: view
            )
        )
        #expect(fixes.bounds.width >= 43.9)
        #expect(fixes.bounds.height >= 43.9)
        fixes.sendActions(for: .touchUpInside)
        host.layoutIfNeeded()

        let stage = try #require(
            descendant(
                UIView.self,
                identifier: "keyboard.brand-stage.stage",
                in: view
            )
        )
        #expect(stage.accessibilityValue == "Fixes")
        #expect(fixes.accessibilityLabel == "Close Fixes")
        #expect(visibility == [true])

        let quickInsert = try #require(
            descendant(
                UIButton.self,
                identifier: "keyboard.brand-stage.quick-insert-toggle",
                in: view
            )
        )
        quickInsert.sendActions(for: .touchUpInside)
        host.layoutIfNeeded()
        #expect(stage.accessibilityValue == "Quick Insert")
        #expect(fixes.accessibilityLabel == "Open Fixes")
        #expect(visibility == [true, false])
    }

    private func makePresentation() throws
        -> KeyboardFixExtensionPresentation {
        KeyboardFixExtensionPresentation(
            actions: try makeKeyboardFixMetadataActions(customCount: 2),
            status: .ready
        )
    }

    private func descendant<View: UIView>(
        _ type: View.Type,
        identifier: String,
        in root: UIView
    ) -> View? {
        if let root = root as? View,
           root.accessibilityIdentifier == identifier {
            return root
        }
        for subview in root.subviews {
            if let match = descendant(
                type,
                identifier: identifier,
                in: subview
            ) {
                return match
            }
        }
        return nil
    }
}
