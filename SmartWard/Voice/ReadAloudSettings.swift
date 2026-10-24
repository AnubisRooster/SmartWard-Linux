import AVFoundation
import SwiftUI
import Pipeline

/// Settings → Read aloud: choose which reading profile (a voice, a speed and
/// how much to read) the speaker button uses, and hear it. The voices are the
/// system's only (D5): article text is never sent to a cloud voice.
struct ReadAloudSettingsSection: View {
    @AppStorage(VoiceSettings.profilesKey) private var profilesJSON = ""

    private var profiles: ReadAloudProfiles { ReadAloudProfiles.decode(profilesJSON) }

    private var activeID: Binding<UUID?> {
        Binding(
            get: { profiles.activeID },
            set: { newValue in
                var updated = profiles
                updated.activeID = newValue
                profilesJSON = updated.encoded()
            })
    }

    var body: some View {
        Section {
            Picker("Profile", selection: activeID) {
                Text("None").tag(UUID?.none)
                ForEach(profiles.profiles) { profile in
                    Text(profile.name).tag(UUID?.some(profile.id))
                }
            }
            NavigationLink("Edit profiles") { ReadAloudProfilesView() }
            Button("Listen") { ReadAloudSample.play(VoiceSettings.reading.voiceID, VoiceSettings.reading.rate) }
        } header: {
            Text("Read aloud")
        } footer: {
            Text("A profile is a voice, a speaking rate and whether to read the whole article or only its summary. With none selected, the voice and rate under Voice conversation are used. For a more natural voice, download a Premium or Enhanced one in the iOS Settings app under Accessibility → Spoken Content → Voices.")
        }
    }
}

enum ReadAloudSample {
    static let sentence = "This is how I will read your articles."

    @MainActor
    static func play(_ voiceID: String, _ rate: Float) {
        VoiceSpeaker.shared.say(sentence, voiceID: voiceID, rate: rate)
    }
}

/// The saved profiles: tap one to edit it, swipe to delete, plus to add.
struct ReadAloudProfilesView: View {
    @AppStorage(VoiceSettings.profilesKey) private var profilesJSON = ""

    var body: some View {
        let profiles = ReadAloudProfiles.decode(profilesJSON)
        List {
            ForEach(profiles.profiles) { profile in
                NavigationLink {
                    ReadAloudProfileEditor(profileID: profile.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(profile.name)
                            if profiles.activeID == profile.id {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                                    .accessibilityLabel("In use")
                            }
                        }
                        Text(profile.summaryOnly ? "Summary only" : "Whole article")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                var updated = profiles
                for index in offsets where index < profiles.profiles.count {
                    updated.remove(profiles.profiles[index].id)
                }
                profilesJSON = updated.encoded()
            }
        }
        .overlay {
            if profiles.profiles.isEmpty {
                ContentUnavailableView("No profiles", systemImage: "speaker.wave.2",
                                       description: Text("Tap + to make one, for example a quick summary-only voice for the commute."))
            }
        }
        .navigationTitle("Reading profiles")
        .toolbar {
            Button("Add profile", systemImage: "plus") {
                var updated = profiles
                let config = VoiceSettings.current
                updated.upsert(ReadAloudProfile(name: updated.newName(), voiceID: config.voiceID,
                                                rate: Double(config.ttsRate)))
                profilesJSON = updated.encoded()
            }
            .disabled(profiles.profiles.count >= ReadAloudProfiles.maxProfiles)
        }
    }
}

struct ReadAloudProfileEditor: View {
    let profileID: UUID

    @AppStorage(VoiceSettings.profilesKey) private var profilesJSON = ""
    /// Committed on return or when you leave: saving every keystroke would trim the spaces you type.
    @State private var name = ""
    /// Loaded once: enumerating installed voices on every slider tick stutters.
    @State private var voices: [AVSpeechSynthesisVoice] = []

    private var store: ReadAloudProfiles { ReadAloudProfiles.decode(profilesJSON) }
    private var profile: ReadAloudProfile? { store.profiles.first { $0.id == profileID } }
    private var isActive: Bool { store.activeID == profileID }

    private func binding<Value>(_ keyPath: WritableKeyPath<ReadAloudProfile, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { profile?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                var updated = store
                guard var edited = updated.profiles.first(where: { $0.id == profileID }) else { return }
                edited[keyPath: keyPath] = newValue
                updated.upsert(edited)
                profilesJSON = updated.encoded()
            })
    }

    private func commitName() {
        guard var edited = profile, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var updated = store
        edited.name = name
        updated.upsert(edited)
        profilesJSON = updated.encoded()
        name = updated.profiles.first { $0.id == profileID }?.name ?? name
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .onSubmit(commitName)
            }
            Section {
                Picker("Voice", selection: binding(\.voiceID, fallback: "")) {
                    Text("Automatic").tag("")
                    ForEach(voices, id: \.identifier) { voice in
                        Text(VoiceSettings.label(for: voice)).tag(voice.identifier)
                    }
                }
                HStack {
                    Text("Speaking rate")
                    Slider(value: binding(\.rate, fallback: 0.5), in: ReadAloudProfiles.rateRange)
                }
                Toggle("Read the summary only", isOn: binding(\.summaryOnly, fallback: false))
            } footer: {
                Text("With the summary only, the speaker button reads the title and the five-question summary; the menu beside it still offers both.")
            }
            Section {
                Button("Listen") {
                    if let profile { ReadAloudSample.play(profile.voiceID, Float(profile.rate)) }
                }
                Button(isActive ? "Stop using this profile" : "Use this profile") {
                    var updated = store
                    updated.activeID = isActive ? nil : profileID
                    profilesJSON = updated.encoded()
                }
            }
        }
        .navigationTitle(name.isEmpty ? "Profile" : name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if voices.isEmpty { voices = VoiceSettings.englishVoices() }
            if name.isEmpty { name = profile?.name ?? "" }
        }
        .onDisappear(perform: commitName)
    }
}
