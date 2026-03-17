import AppKit

@MainActor
final class AppAttentionService {
    private var activeSound: NSSound?
    private var ringTask: Task<Void, Never>?

    func playDoorbellSound() {
        ringTask?.cancel()

        let soundName = NSSound(named: NSSound.Name("Glass")) != nil ? NSSound.Name("Glass") : NSSound.Name("Hero")

        ringTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for _ in 0..<5 {
                if Task.isCancelled {
                    return
                }

                if let sound = NSSound(named: soundName)?.copy() as? NSSound {
                    activeSound = sound
                    sound.play()

                    let duration = sound.duration > 0 ? sound.duration : 0.8
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                } else {
                    NSSound.beep()
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
            }

            activeSound = nil
        }
    }

    func bringApplicationToFront() {
        NSApp.activate(ignoringOtherApps: true)

        let visibleWindows = NSApp.windows.filter { $0.isVisible && !$0.isMiniaturized }
        if let targetWindow = visibleWindows.first {
            targetWindow.orderFrontRegardless()
            targetWindow.makeKeyAndOrderFront(nil)
        }
    }
}