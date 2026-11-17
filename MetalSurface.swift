import SwiftUI
import UIKit
import MetalKit

struct MetalSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.clearColor = MTLClearColor(red: 0.13, green: 0.025, blue: 0.20, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {}

    func makeCoordinator() -> Renderer { Renderer() }

    final class Renderer: NSObject, MTKViewDelegate {
        private var queue: MTLCommandQueue?
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            queue = view.device?.makeCommandQueue()
        }
        func draw(in view: MTKView) {
            guard let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let command = (queue ?? view.device?.makeCommandQueue())?.makeCommandBuffer(),
                  let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.endEncoding()
            command.present(drawable)
            command.commit()
        }
    }
}
