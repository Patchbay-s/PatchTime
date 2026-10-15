//
//  PatchTimeTests.swift
//  PatchTimeTests
//
//  Created by Admin on 30/04/2025.
//

import Testing
import Foundation
@testable import PatchTime

struct PatchTimeTests {

    @Test func overtimeDurationForSupAndRecup() async throws {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 2.5 * 3600)
        let duration = overtimeDuration(from: start, to: end)
        #expect(duration == 9000)
        #expect(formattedDuration(from: duration) == "2h30")
    }

    @Test func allowedMinuteRounding() async throws {
        #expect(roundedMinute(0) == 0)
        #expect(roundedMinute(8) == 15)
        #expect(roundedMinute(29) == 30)
        #expect(roundedMinute(44) == 45)
        #expect(roundedMinute(59) == 45)
    }
}
