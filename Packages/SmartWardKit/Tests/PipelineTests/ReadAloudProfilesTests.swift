import Foundation
import XCTest
@testable import Pipeline

final class ReadAloudProfilesTests: XCTestCase {
    func testAddReplaceAndRemoveKeepTheActiveProfileValid() {
        var profiles = ReadAloudProfiles()
        let commute = ReadAloudProfile(name: "Commute", voiceID: "v1", rate: 0.6, summaryOnly: true)
        XCTAssertTrue(profiles.upsert(commute))
        profiles.activeID = commute.id
        XCTAssertEqual(profiles.active?.name, "Commute")

        var renamed = commute
        renamed.name = "  Short  "
        XCTAssertTrue(profiles.upsert(renamed))
        XCTAssertEqual(profiles.profiles.count, 1, "same id replaces")
        XCTAssertEqual(profiles.active?.name, "Short")

        profiles.remove(commute.id)
        XCTAssertTrue(profiles.profiles.isEmpty)
        XCTAssertNil(profiles.activeID, "removing the active profile clears it")
    }

    func testNamesAndRatesAreCleaned() {
        var profiles = ReadAloudProfiles()
        profiles.upsert(ReadAloudProfile(name: "   ", rate: 9))
        profiles.upsert(ReadAloudProfile(name: String(repeating: "x", count: 100), rate: .nan))
        profiles.upsert(ReadAloudProfile(name: "Slow", rate: 0.01))
        XCTAssertEqual(profiles.profiles[0].name, "Profile")
        XCTAssertEqual(profiles.profiles[0].rate, 0.7)
        XCTAssertEqual(profiles.profiles[1].name.count, ReadAloudProfiles.maxNameLength)
        XCTAssertEqual(profiles.profiles[1].rate, 0.5, "not a number falls back to the default")
        XCTAssertEqual(profiles.profiles[2].rate, 0.3)
    }

    func testThereIsALimitAndNewNamesDontClash() {
        var profiles = ReadAloudProfiles()
        for index in 0..<ReadAloudProfiles.maxProfiles {
            XCTAssertTrue(profiles.upsert(ReadAloudProfile(name: "P\(index)")))
        }
        XCTAssertFalse(profiles.upsert(ReadAloudProfile(name: "One too many")))
        XCTAssertEqual(profiles.profiles.count, ReadAloudProfiles.maxProfiles)

        var small = ReadAloudProfiles(profiles: [ReadAloudProfile(name: "Profile 2")])
        XCTAssertEqual(small.newName(), "Profile 3")
        small.upsert(ReadAloudProfile(name: small.newName()))
        XCTAssertEqual(Set(small.profiles.map(\.name)).count, 2)
    }

    func testRoundTripThroughJSONAndTolerantOfGarbage() {
        let night = ReadAloudProfile(name: "Night", voiceID: "com.apple.voice.premium.en-GB.Malcolm", rate: 0.4)
        let profiles = ReadAloudProfiles(profiles: [night], activeID: night.id)
        XCTAssertEqual(ReadAloudProfiles.decode(profiles.encoded()), profiles)
        XCTAssertEqual(ReadAloudProfiles.decode(""), ReadAloudProfiles())
        XCTAssertEqual(ReadAloudProfiles.decode("{not json"), ReadAloudProfiles())

        // An active id that isn't in the list (a deleted profile) is dropped.
        let stale = ReadAloudProfiles(profiles: [night], activeID: UUID())
        XCTAssertNil(stale.activeID)
    }
}
