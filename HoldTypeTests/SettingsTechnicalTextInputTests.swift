//
//  SettingsTechnicalTextInputTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/6/26.
//

import Testing
@testable import HoldType

struct SettingsTechnicalTextInputTests {

    @Test func textAreaReservesAtLeastOneLineOfVerticalSpace() {
        #expect(Int(SettingsTechnicalTextAreaInput.height(forLineCount: 0)) == 34)
        #expect(Int(SettingsTechnicalTextAreaInput.height(forLineCount: 3)) == 74)
    }
}
