import SwiftUI

/// A circular shutter button used to trigger photo capture.
///
/// Renders an outer filled white circle with an inner stroked white circle
/// overlaid in a ZStack. Opacity is reduced and interaction is disabled while
/// `isDisabled` is true, preventing duplicate captures (Requirement 7.3).
struct ShutterButton: View {

    /// The action to invoke when the user taps the button.
    let action: () -> Void

    /// When `true` the button is visually dimmed and non-interactive.
    let isDisabled: Bool

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer solid white circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)

                // Inner stroked ring
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 3)
                    .frame(width: 60, height: 60)
            }
        }
        .opacity(isDisabled ? 0.5 : 1.0)
        .disabled(isDisabled)
    }
}
