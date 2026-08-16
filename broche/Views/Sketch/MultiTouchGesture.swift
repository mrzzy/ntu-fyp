//
//  MultiTouchGesture.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-16.
//


import SwiftUI
import UIKit

struct MultiFingerTapGesture: UIGestureRecognizerRepresentable {
    let count: Int
    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let gesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleGesture)
        )
        gesture.numberOfTouchesRequired = count
        gesture.numberOfTapsRequired = 1
        gesture.delegate = context.coordinator
        return gesture
    }

    func updateUIGestureRecognizer(_ recognizer: UITapGestureRecognizer, context: Context) {}

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func handleGesture() {
            action()
        }

        func gestureRecognizer(
            _: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
