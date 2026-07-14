//
//  ZoomableScrollView.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-14.
//

import SwiftUI

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var scale: CGFloat
    @Binding var offset: CGPoint

    init(
        scale: Binding<CGFloat> = .constant(1.0), offset: Binding<CGPoint> = .constant(.zero),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        _scale = scale
        _offset = offset
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.delegate = context.coordinator

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)
        context.coordinator.hostingController = hostingController

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        DispatchQueue.main.async {
            scrollView.zoomScale = scale
            scrollView.contentOffset = offset
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content

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

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableScrollView
        var hostingController: UIHostingController<Content>?

        init(_ parent: ZoomableScrollView) {
            self.parent = parent
            super.init()
        }

        func viewForZooming(in _: UIScrollView) -> UIView? {
            return hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
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
    }
}

