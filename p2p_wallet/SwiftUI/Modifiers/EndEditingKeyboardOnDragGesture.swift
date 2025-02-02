import SwiftUI
import UIKit

struct EndEditingKeyboardOnDragGesture: ViewModifier {
    func body(content: Content) -> some View {
        content.highPriorityGesture (
            DragGesture().onChanged { _ in
                UIApplication.shared.endEditing()
            }
        )
    }
}

extension View {
    func scrollDismissesKeyboard() -> some View {
        if #available(iOS 16.0, *) {
            return scrollDismissesKeyboard(.immediately)
        } else {
            return modifier(EndEditingKeyboardOnDragGesture())
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

