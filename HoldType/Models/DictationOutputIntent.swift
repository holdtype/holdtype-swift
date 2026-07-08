//
//  DictationOutputIntent.swift
//  HoldType
//
//  Created by Codex on 7/5/26.
//

enum DictationOutputIntent: Equatable {
    case standard
    case translate

    func merged(with intent: DictationOutputIntent) -> DictationOutputIntent {
        self == .translate || intent == .translate ? .translate : .standard
    }
}
