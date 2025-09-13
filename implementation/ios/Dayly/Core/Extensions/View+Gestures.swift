import SwiftUI

extension View {
    func onSwipeDown(
        threshold: CGFloat = 100,
        action: @escaping () -> Void
    ) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > threshold &&
                       abs(value.translation.width) < value.translation.height {
                        action()
                    }
                }
        )
    }
    
    func onSwipeUp(
        threshold: CGFloat = 100,
        action: @escaping () -> Void
    ) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height < -threshold &&
                       abs(value.translation.width) < abs(value.translation.height) {
                        action()
                    }
                }
        )
    }
    
    func onSwipe(
        direction: SwipeDirection,
        threshold: CGFloat = 50,
        action: @escaping () -> Void
    ) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    switch direction {
                    case .up:
                        if verticalAmount < -threshold && abs(horizontalAmount) < abs(verticalAmount) {
                            action()
                        }
                    case .down:
                        if verticalAmount > threshold && abs(horizontalAmount) < verticalAmount {
                            action()
                        }
                    case .left:
                        if horizontalAmount < -threshold && abs(verticalAmount) < abs(horizontalAmount) {
                            action()
                        }
                    case .right:
                        if horizontalAmount > threshold && abs(verticalAmount) < horizontalAmount {
                            action()
                        }
                    }
                }
        )
    }
}

enum SwipeDirection {
    case up, down, left, right
}

// MARK: - Tap to Dismiss Keyboard

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}

// MARK: - Long Press with Haptic

extension View {
    func onLongPressWithHaptic(
        minimumDuration: Double = 0.5,
        maximumDistance: CGFloat = 10,
        perform action: @escaping () -> Void
    ) -> some View {
        self.onLongPressGesture(
            minimumDuration: minimumDuration,
            maximumDistance: maximumDistance
        ) {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Perform action
            action()
        }
    }
}
