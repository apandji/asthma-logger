import AVFoundation
import Foundation

/// Two sounds, both short and quiet, played at the moments that matter: a tick when a moment is logged and a
/// breath when felt air has learned. Synthesised (AsthmaLog/Resources/Sounds), so the whole set is one voice.
/// Silent with the ringer off (the ambient category) and with Settings › Logging › Sounds off.
enum Sounds {
    enum Name: String { case log, learned }

    private static var players: [Name: AVAudioPlayer] = [:]

    static func play(_ name: Name) {
        guard UserDefaults.standard.object(forKey: Prefs.sounds) == nil || UserDefaults.standard.bool(forKey: Prefs.sounds) else { return }
        // Mixes with whatever's playing and respects the silent switch. Not set while recording (that session
        // is play-and-record); a tick mid-recording isn't wanted anyway.
        if VoiceNotes.shared.recordingID != nil { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let player: AVAudioPlayer
        if let p = players[name] {
            player = p
        } else {
            guard let url = Bundle.main.url(forResource: name.rawValue, withExtension: "wav"),
                  let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.prepareToPlay()
            players[name] = p
            player = p
        }
        player.volume = name == .log ? 0.6 : 0.5
        player.currentTime = 0
        player.play()
    }
}
