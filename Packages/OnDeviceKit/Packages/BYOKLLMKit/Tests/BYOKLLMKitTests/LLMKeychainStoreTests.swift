import XCTest
@testable import BYOKLLMKit

final class LLMKeychainStoreTests: XCTestCase {

    private func makeStore() -> LLMKeychainStore {
        // Unique service per test so runs never collide or leak state.
        LLMKeychainStore(service: "kit-tests.\(UUID().uuidString)")
    }

    /// A bare SPM XCTest bundle has no host-app Keychain entitlement, so
    /// `SecItemAdd`/`SecItemDelete` can fail (e.g. under `xcodebuild test` in
    /// the iOS Simulator without a signed host app) even though the same code
    /// works fine inside a real app. Skip rather than fail spuriously when
    /// that's the environment we're running in.
    private func skipIfKeychainUnavailable(_ store: LLMKeychainStore) throws {
        let wrote = store.set("probe", for: .together)
        let readBack = store.get(for: .together)
        store.delete(for: .together)
        try XCTSkipUnless(wrote && readBack == "probe",
                          "Keychain unavailable in this test environment (no host-app entitlement)")
    }

    func testSetThenGetRoundTrips() throws {
        let store = makeStore()
        try skipIfKeychainUnavailable(store)
        XCTAssertTrue(store.set("sk-test-123", for: .openai))
        XCTAssertEqual(store.get(for: .openai), "sk-test-123")
        XCTAssertTrue(store.hasKey(for: .openai))
    }

    func testMissingKeyReturnsNil() {
        let store = makeStore()
        XCTAssertNil(store.get(for: .anthropic))
        XCTAssertFalse(store.hasKey(for: .anthropic))
    }

    func testSettingEmptyStringClearsKey() throws {
        let store = makeStore()
        try skipIfKeychainUnavailable(store)
        store.set("sk-test-123", for: .groq)
        XCTAssertTrue(store.set("", for: .groq))
        XCTAssertNil(store.get(for: .groq))
    }

    func testDeleteRemovesKey() throws {
        let store = makeStore()
        try skipIfKeychainUnavailable(store)
        store.set("sk-test-123", for: .deepseek)
        XCTAssertTrue(store.delete(for: .deepseek))
        XCTAssertNil(store.get(for: .deepseek))
    }

    func testKeysAreIsolatedPerProvider() throws {
        let store = makeStore()
        try skipIfKeychainUnavailable(store)
        store.set("openai-key", for: .openai)
        store.set("groq-key", for: .groq)
        XCTAssertEqual(store.get(for: .openai), "openai-key")
        XCTAssertEqual(store.get(for: .groq), "groq-key")
    }
}
