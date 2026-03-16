import AppKit
import SwiftUI

struct MainWindowLifecycleView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            context.coordinator.attach(to: window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }

            context.coordinator.attach(to: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private weak var observedWindow: NSWindow?

        func attach(to window: NSWindow) {
            guard observedWindow !== window else {
                return
            }

            observedWindow?.delegate = nil
            observedWindow = window
            window.delegate = self
        }

        func windowWillClose(_ notification: Notification) {
            NSApp.terminate(nil)
        }
    }
}