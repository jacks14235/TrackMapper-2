//
//  BuildShader.swift
//  Test Project
//
//  Created by Jack Stanley on 3/10/25.
//

import SwiftUI
import MetalKit
import UIKit

// with skeleton code from ChatGPT
struct MetalView: UIViewRepresentable {
    @Binding var info: [Float]
    @Binding var spline: Spline
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    let inTexture: MTLTexture
    let outTexture: MTLTexture
    let infoBuffer: MTLBuffer
    let points: [Float]
    
    init(inTexture: MTLTexture, outTexture: MTLTexture, info: Binding<[Float]>, points: [Float], spline: Binding<Spline>) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        self.inTexture = inTexture
        self.outTexture = outTexture
        self._info = info
        self.infoBuffer = device.makeBuffer(length: info.wrappedValue.count * MemoryLayout<Float>.size, options: .storageModeShared)!
        self.infoBuffer.contents().copyMemory(from: info.wrappedValue, byteCount: info.wrappedValue.count * MemoryLayout<Float>.size)
        self.points = points
        self._spline = spline
        self.commandQueue = device.makeCommandQueue()!
        
        // Load the default library and create the compute function.
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "warp") else {
            fatalError("Unable to load shader function")
        }
        do {
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            fatalError("Error creating pipeline state: \(error)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Create and configure the MTKView.
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.isOpaque = false
        mtkView.backgroundColor = UIColor.clear
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) { }
    
    // Coordinator acts as the MTKView delegate and performs the rendering/compute work.
    class Coordinator: NSObject, MTKViewDelegate {
        let parent: MetalView
        
        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let commandBuffer = parent.commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }

            // Set up float arrays
            let infoPointer = parent.infoBuffer.contents().assumingMemoryBound(to: Float.self)
            memcpy(infoPointer, parent.info, parent.info.count * MemoryLayout<Float>.size)
            let points = parent.device.makeBuffer(bytes: parent.points,length: parent.points.count * MemoryLayout<Float>.size, options: [])
            let D = parent.device.makeBuffer(bytes: parent.spline.D.data, length: parent.spline.D.data.count * MemoryLayout<Float>.size, options: [])
            let c = parent.device.makeBuffer(bytes: parent.spline.c.data,length: parent.spline.c.data.count * MemoryLayout<Float>.size, options: [])

            // Set pipeline and bind resources
            computeEncoder.setComputePipelineState(parent.pipelineState)
            computeEncoder.setTexture(parent.inTexture, index: 0)  // Input texture
            computeEncoder.setTexture(drawable.texture, index: 1) // Output texture (written to)
            computeEncoder.setBuffer(parent.infoBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(points, offset: 0, index: 1)
            computeEncoder.setBuffer(D, offset: 0, index: 2)
            computeEncoder.setBuffer(c, offset: 0, index: 3)

            // Dispatch threads
            let gridWidth = drawable.texture.width
            let gridHeight = drawable.texture.height
            let threadGroupWidth = parent.pipelineState.threadExecutionWidth
            let rawThreadGroupHeight = parent.pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
            let threadGroupHeight = rawThreadGroupHeight > 0 ? rawThreadGroupHeight : 1
            let threadsPerThreadgroup = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

            let threadgroupCount = MTLSize(
                width: (gridWidth + threadGroupWidth - 1) / threadGroupWidth,
                height: (gridHeight + threadGroupHeight - 1) / threadGroupHeight,
                depth: 1
            )
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)

            computeEncoder.endEncoding()
            
//            commandBuffer.addCompletedHandler { completedCommandBuffer in
//                // gpuStartTime and gpuEndTime are measured in seconds.
//                let gpuTime = completedCommandBuffer.gpuEndTime - completedCommandBuffer.gpuStartTime
//                print("GPU execution time: \(gpuTime * 1000) ms")
//            }

            // Present the processed output texture
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
//            commandBuffer.waitUntilCompleted()
//            saveImage(texture: parent.outTexture)
        }


    }
}

func textureToImage(texture: MTLTexture) -> UIImage? {
    let ciImage = CIImage(mtlTexture: texture, options: nil)
    guard let ciImage = ciImage else { return nil }
    
    let context = CIContext()
    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
        return UIImage(cgImage: cgImage)
    }
    
    return nil
}

func saveImage(texture: MTLTexture, fileName: String = "output.png") {
    guard let image = textureToImage(texture: texture) else {
        print("Failed to convert texture to image")
        return
    }

    if let data = image.pngData() {  // Use .jpegData(compressionQuality: 1.0) for JPG
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("Saved image at \(fileURL)")
        } catch {
            print("Failed to save image: \(error)")
        }
    }
}

struct ShaderView: View {
    @Binding var spline: Spline
    @Binding var frame: Frame
    @State var info: [Float] = [Float](repeating: 0, count: 11)
    @State var inTexture: MTLTexture
    let outTexture: MTLTexture
    let floatArray: [Float]
    let dimensions: CGPoint
    
    init(spline: Binding<Spline>, frame: Binding<Frame>, image: Binding<UIImage>) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported")
        }
        self._spline = spline
        self._frame = frame
        // Create a simple texture descriptor.
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
             width: 128,
             height: 128,
             mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create texture")
        }
        self.outTexture = texture
        
        let (image1, dimensions1) = tryLoadImage(from: image.wrappedValue, device: device)
        self.inTexture = image1
        self.dimensions = dimensions1
        
        self.floatArray = [1.0, 0.0, 1.0, 1.0]
    }
    
    var body: some View {
        let pointsScaled = self.spline.scaledReal(self.spline.realCoords).data
        ZStack {
            MetalView(inTexture: inTexture, outTexture: outTexture, info: $info, points: pointsScaled, spline: self.$spline)
        }
        .allowsHitTesting(false)
        .onChange(of: frame, initial: true) {
            let topLeft = Coordinate.from(frame.topLeft)
            let topRight = Coordinate.from(frame.topRight)
            let bottomLeft = Coordinate.from(frame.bottomLeft)
            let list = [topLeft, topRight, bottomLeft]
            let scaledCoords = self.spline.scaledReal(list)
            self.info[0] = scaledCoords.data[0] // topright x
            self.info[1] = scaledCoords.data[3] // topright y
            self.info[2] = scaledCoords.data[1] - scaledCoords.data[0] // right vector x
            self.info[3] = scaledCoords.data[4] - scaledCoords.data[3] // right vector y
            self.info[4] = scaledCoords.data[2] - scaledCoords.data[0] // down vector x
            self.info[5] = scaledCoords.data[5] - scaledCoords.data[3] // down vector y
            self.info[6] = Float(self.spline.m)
            self.info[7] = Float(self.spline.mapTrans.x)
            self.info[8] = Float(self.spline.mapTrans.y)
            self.info[9] = Float(self.spline.mapScale.x)
            self.info[10] = Float(self.spline.mapScale.y)
//            print(self.info)
        }
    }
    
}

func tryLoadImage(from image: UIImage, device: MTLDevice) -> (MTLTexture, CGPoint) {
    // Try to get the CGImage from the UIImage
    guard let cgImage = image.cgImage else {
        print("Failed to get CGImage from UIImage; using fallback texture")
        return fallbackTexture(device: device)
    }
    
    // Create a texture loader from the Metal device.
    let textureLoader = MTKTextureLoader(device: device)
    
    do {
        // Try to load a texture from the CGImage.
        let texture = try textureLoader.newTexture(cgImage: cgImage, options: nil)
        return (texture, CGPoint(x: texture.width, y: texture.height))
    } catch {
        print("Error loading texture from image: \(error); using fallback texture")
        return fallbackTexture(device: device)
    }
}

/// Helper function that creates a small, transparent fallback texture.
private func fallbackTexture(device: MTLDevice) -> (MTLTexture, CGPoint) {
    // Define a 2x2 texture descriptor with an RGBA8 pixel format.
    let fallbackDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                      width: 2,
                                                                      height: 2,
                                                                      mipmapped: false)
    fallbackDescriptor.usage = [.shaderRead]
    
    // Create the texture
    guard let fallbackTexture = device.makeTexture(descriptor: fallbackDescriptor) else {
        fatalError("Failed to create fallback texture")
    }
    
    // Prepare transparent pixel data (2x2 RGBA = 4 pixels * 4 bytes per pixel)
    let transparentPixels = [UInt8](repeating: 0, count: 2 * 2 * 4)
    transparentPixels.withUnsafeBytes { ptr in
        fallbackTexture.replace(region: MTLRegionMake2D(0, 0, 2, 2),
                                mipmapLevel: 0,
                                withBytes: ptr.baseAddress!,
                                bytesPerRow: 2 * 4)
    }
    
    return (fallbackTexture, CGPoint(x: 2, y: 2))
}


//#Preview {
//    ShaderView()
//}
