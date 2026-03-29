import AudioToolbox
import UIKit

@MainActor
final class IOSAppAttentionService {
    func playDoorbellSound() {
        AudioServicesPlaySystemSound(1005)
    }

    func bringApplicationToFront() {
    }
}
