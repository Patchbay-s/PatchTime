//
//  AppConstants.swift
//  PatchTime

import Foundation

enum AppConstants {
    static let appStoreID: String? = "6747032439"

    static var appStoreURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }
}

/// Nom, version et build lus depuis le Bundle.
enum AppInfo {
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "PatchTime"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
