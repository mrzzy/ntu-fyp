//
//  ZoomableScrollView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-14.
//

import SwiftUI
import UIKit

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    @Binding var scale: Double
    @Binding var offset: CGPoint
    @Binding var rotation: Angle
    @ViewBuilder let content: (_ rotation: Angle) -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.delegate = context.coordinator

        context.coordinator.setupRotationGesture(scrollView)

        let hostingController = UIHostingController(rootView: content(rotation))
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)
        context.coordinator.hostingController = hostingController

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            hostingController.view.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            hostingController.view.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            hostingController.view.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            hostingController.view.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),
        ])

        scrollView.zoomScale = scale
        scrollView.contentOffset = offset

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content(rotation)

        if uiView.zoomScale != scale {
            uiView.zoomScale = scale
        }
        if uiView.contentOffset != offset {
            uiView.contentOffset = offset
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ZoomableScrollView
        var hostingController: UIHostingController<Content>?
        var rotationGesture: UIRotationGestureRecognizer?

        init(_ parent: ZoomableScrollView) {
            self.parent = parent
            super.init()
        }

        func viewForZooming(in _: UIScrollView) -> UIView? {
            return hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
            parent.scale = scrollView.zoomScale
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.offset = scrollView.contentOffset
        }

        private func zoomRectForScale(scale: CGFloat, center: CGPoint, in scrollView: UIScrollView)
            -> CGRect
        {
            let width = scrollView.frame.size.width / scale
            let height = scrollView.frame.size.height / scale
            let x = center.x - (width / 2.0)
            let y = center.y - (height / 2.0)
            return CGRect(x: x, y: y, width: width, height: height)
        }

        /// rotation gesture
        /// rotation is not performed by ZoomableScrollView, but instead rotation angle is passed upstream
        /// via rotation binding
        func setupRotationGesture(_ scrollView: UIScrollView) {
            rotationGesture = UIRotationGestureRecognizer(
                target: self, action: #selector(handleRotation(_:))
            )
            rotationGesture?.delegate = self
            scrollView.addGestureRecognizer(rotationGesture!)
        }

        func gestureRecognizer(
            _: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            return true
        }

        @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            if gesture.state == .changed {
                let currentRotation = parent.rotation.radians
                parent.rotation = .radians(currentRotation + gesture.rotation)
                gesture.rotation = 0
            }
        }
    }
}
