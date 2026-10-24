import XCTest
import SwiftData
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
@testable import KnowledgeStore

final class BackupTests: XCTestCase {
    /// Fast key derivation for tests; the app uses `defaultIterations`.
    private let iterations: UInt32 = 1_000
    private let passphrase = "correct horse battery"

    /// Phase 5 exit: wipe → restore reproduces the exact state.
    @MainActor
    func testWipeThenRestoreReproducesTheExactLibrary() throws {
        let fixture = try LibraryFixture()
        let context = fixture.context
        let before = try LibraryArchive.snapshot(context: context, includePrivate: true, includeEmbeddings: true,
                                                 now: fixture.now)
        let backup = try EncryptedBackup.seal(before, passphrase: passphrase, iterations: iterations)
        XCTAssertFalse(String(decoding: backup, as: UTF8.self).contains("Nightjar"), "the file is encrypted")

        try LibraryArchive.erase(context)
        XCTAssertTrue(try LibraryArchive.isEmpty(context))

        let opened = try EncryptedBackup.open(backup, passphrase: passphrase)
        XCTAssertEqual(opened, before)
        try opened.restore(into: context)
        try context.save()

        let after = try LibraryArchive.snapshot(context: context, includePrivate: true, includeEmbeddings: true,
                                                now: fixture.now)
        XCTAssertEqual(after, before, "every row, field and relationship comes back")

        // The live relationships work, not just the ids.
        let project = try XCTUnwrap(context.fetch(FetchDescriptor<Project>()).first)
        XCTAssertEqual(project.brief?.markdown, "# Plan\nServe with vLLM.")
        XCTAssertEqual(project.brief?.revisions?.first?.status, .accepted)
        XCTAssertEqual(Set((project.pinnedNodes ?? []).map(\.canonicalLabel)), ["vLLM", "Project Nightjar"])
        XCTAssertEqual(project.conversations?.first?.messages?.first?.content, "Should we use vLLM?")
        XCTAssertEqual((project.items ?? []).count, 2)
        let article = try XCTUnwrap(context.fetch(FetchDescriptor<Article>()).first { $0.title == "vLLM notes" })
        XCTAssertEqual(article.source?.url, "https://blog.example/feed")
        let chunk = try XCTUnwrap(article.chunks?.first)
        XCTAssertEqual(chunk.vector, Data([1, 2, 3, 4]))
        XCTAssertEqual(chunk.mentions?.first?.node?.canonicalLabel, "vLLM")
        XCTAssertEqual(chunk.mentions?.first?.node?.aliases?.first?.alias, "vllm")
    }

    /// What Settings → Backup & restore does: erase and restore in one save.
    @MainActor
    func testReplacingTheLibraryRestoresInOneSave() throws {
        let fixture = try LibraryFixture()
        let context = fixture.context
        let before = try LibraryArchive.snapshot(context: context, includePrivate: true, includeEmbeddings: true,
                                                 now: fixture.now)
        let articles = try context.fetchCount(FetchDescriptor<Article>())

        try before.replaceLibrary(in: context)

        let after = try LibraryArchive.snapshot(context: context, includePrivate: true, includeEmbeddings: true,
                                                now: fixture.now)
        XCTAssertEqual(after, before, "the old rows are gone and the archive's are back, not both")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Article>()), articles)
        XCTAssertFalse(context.hasChanges, "saved in one go")
    }

    @MainActor
    func testRestoreNeedsAnEmptyLibrary() throws {
        let fixture = try LibraryFixture()
        let archive = try LibraryArchive.snapshot(context: fixture.context, includePrivate: true,
                                                  includeEmbeddings: true, now: fixture.now)
        XCTAssertThrowsError(try archive.restore(into: fixture.context)) {
            XCTAssertEqual($0 as? LibraryArchive.RestoreError, .libraryNotEmpty)
        }
    }

    @MainActor
    func testWrongPassphraseTamperingAndOtherFilesAreRefused() throws {
        let fixture = try LibraryFixture()
        let archive = try LibraryArchive.snapshot(context: fixture.context, includePrivate: true,
                                                  includeEmbeddings: true, now: fixture.now)
        let backup = try EncryptedBackup.seal(archive, passphrase: passphrase, iterations: iterations)

        func refusal(_ data: Data, _ passphrase: String) -> EncryptedBackup.BackupError? {
            do {
                _ = try EncryptedBackup.open(data, passphrase: passphrase)
                return nil
            } catch {
                return error as? EncryptedBackup.BackupError
            }
        }
        XCTAssertEqual(refusal(backup, "wrong horse battery"), .wrongPassphraseOrDamaged)
        XCTAssertEqual(refusal(backup, ""), .wrongPassphraseOrDamaged)

        var salted = backup
        salted[10] ^= 0xFF
        XCTAssertEqual(refusal(salted, passphrase), .wrongPassphraseOrDamaged, "the header is authenticated")
        var flipped = backup
        flipped[flipped.count - 1] ^= 0x01
        XCTAssertEqual(refusal(flipped, passphrase), .wrongPassphraseOrDamaged)
        XCTAssertEqual(refusal(backup.prefix(40), passphrase), .wrongPassphraseOrDamaged, "truncated")

        var newer = backup
        newer[4] = EncryptedBackup.formatVersion + 1
        XCTAssertEqual(refusal(newer, passphrase), .newerVersion(Int(EncryptedBackup.formatVersion) + 1))
        XCTAssertEqual(refusal(Data("PK\u{3}\u{4} not a backup at all".utf8), passphrase), .notABackup)
        var slow = backup
        for index in 5..<9 { slow[index] = 0xFF }
        XCTAssertEqual(refusal(slow, passphrase), .notABackup, "a file can't demand billions of iterations")

        XCTAssertThrowsError(try EncryptedBackup.seal(archive, passphrase: "short", iterations: iterations)) {
            XCTAssertEqual($0 as? EncryptedBackup.BackupError, .passphraseTooShort(minimum: 8))
        }
        let again = try EncryptedBackup.seal(archive, passphrase: passphrase, iterations: iterations)
        XCTAssertNotEqual(again, backup, "a fresh salt and nonce every time")
        XCTAssertEqual(try EncryptedBackup.open(again, passphrase: passphrase), archive)
    }

    func testTheSamePassphraseTypedDifferentlyGivesTheSameKey() throws {
        let salt = Data(repeating: 7, count: 16)
        let composed = try EncryptedBackup.deriveKey(passphrase: "café au lait", salt: salt, iterations: 1_000)
        let decomposed = try EncryptedBackup.deriveKey(passphrase: "cafe\u{301} au lait", salt: salt, iterations: 1_000)
        XCTAssertEqual(composed.withUnsafeBytes { Data($0) }, decomposed.withUnsafeBytes { Data($0) })
    }
}
