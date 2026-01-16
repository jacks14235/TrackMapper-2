import SwiftUI
import UIKit

enum MapMode {
    case create, view
}
let dotSize: CGFloat = 5

struct ZoomableImageViewRepr: UIViewRepresentable {
    @Binding var convertedPoint: Coordinate?
    @Binding var clickedPoint: Coordinate?
    @Binding var mapPoints: [Coordinate]
    @Binding var imageData: UIImage
    var mapMode: MapMode
    var onDelete: (Int) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        // Image view setup
        let imageView = UIImageView(image: imageData)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        // Tap gesture
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        imageView.addGestureRecognizer(tap)

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Constraints
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let imageView = uiView.subviews.first as? UIImageView {
            imageView.image = imageData
            
            // Add the points after the UIImageView is constructed
            DispatchQueue.main.async {
                imageView.subviews
                    .filter { $0.tag == 777 }
                    .forEach { $0.removeFromSuperview() }
                
                if let conv = convertedPoint {
                    let position = toImageCoordinates(coord: conv, imageView: imageView)
                    let dot = makeDot(center: position)
                    dot.backgroundColor = .green
                    dot.layer.cornerRadius = dotSize / 2
                    dot.isUserInteractionEnabled = false
                    dot.tag = 777
                    imageView.addSubview(dot)
                }
                if let click = clickedPoint {
                    let position = toImageCoordinates(coord: click, imageView: imageView)
                    let dot = makeDot(center: position)
                    dot.backgroundColor = .yellow
                    dot.layer.cornerRadius = dotSize / 2
                    dot.isUserInteractionEnabled = false
                    dot.tag = 777
                    imageView.addSubview(dot)
                }
                if mapMode == .create {
                    for coord in mapPoints {
                        let position = toImageCoordinates(coord: coord, imageView: imageView)
                        let dot = makeDot(center: position)
                        dot.backgroundColor = .red
                        dot.layer.cornerRadius = dotSize / 2
                        dot.isUserInteractionEnabled = false
                        dot.tag = 777
                        imageView.addSubview(dot)
                    }
                } else {
                    let path = UIBezierPath()
                    for (index, coord) in mapPoints.enumerated() {
                        let position = toImageCoordinates(coord: coord, imageView: imageView)
                        if index == 0 {
                            path.move(to: position)
                        } else {
                            path.addLine(to: position)
                        }
                    }
                    let pathLayer = CAShapeLayer()
                    pathLayer.name = "gpxPath"
                    pathLayer.path = path.cgPath
                    pathLayer.strokeColor = UIColor.red.cgColor
                    pathLayer.lineWidth = 2.0
                    pathLayer.fillColor = UIColor.clear.cgColor
                    imageView.layer.sublayers?.removeAll(where: { $0.name == "gpxPath" })
                    imageView.layer.addSublayer(pathLayer)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, image: imageData)
    }
    
    func makeDot(center: CGPoint) -> UIView {
        return UIView(frame: CGRect(
            x: center.x,
            y: center.y,
            width: dotSize,
            height: dotSize)
        )
    }
    
    func toImageCoordinates(coord: Coordinate, imageView: UIImageView) -> CGPoint {
        let imageSize = imageData.size
        
        let imageViewSize = imageView.bounds.size
        let scaleWidth = imageViewSize.width / imageSize.width
        let scaleHeight = imageViewSize.height / imageSize.height
        let scale = min(scaleWidth, scaleHeight)
        
        let imageDisplaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let imageOrigin = CGPoint(
            x: (imageViewSize.width - imageDisplaySize.width) / 2,
            y: (imageViewSize.height - imageDisplaySize.height) / 2
        )

        let relativePoint = CGPoint(
            x: coord.x * imageSize.width,
            y: coord.y * imageSize.height
        )
        return CGPoint(
            x: imageOrigin.x + relativePoint.x * scale - dotSize / 2,
            y: imageOrigin.y + relativePoint.y * scale - dotSize / 2
        )
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableImageViewRepr
        var imageView: UIImageView?
        let image: UIImage

        init(parent: ZoomableImageViewRepr, image: UIImage) {
            self.parent = parent
            self.image = image
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let imageView = imageView else { return }

            let locationInImageView = gesture.location(in: imageView)
            guard let imageSize = imageView.image?.size else { return }

            // Convert tap point into image coordinates
            let imageViewSize = imageView.bounds.size
            let scaleWidth = imageViewSize.width / imageSize.width
            let scaleHeight = imageViewSize.height / imageSize.height
            let scale = min(scaleWidth, scaleHeight)

            let imageDisplaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

            let imageOrigin = CGPoint(
                x: (imageViewSize.width - imageDisplaySize.width) / 2,
                y: (imageViewSize.height - imageDisplaySize.height) / 2
            )

            let relativePoint = CGPoint(
                x: (locationInImageView.x - imageOrigin.x) / scale / imageSize.width,
                y: (locationInImageView.y - imageOrigin.y) / scale / imageSize.height
            )

            DispatchQueue.main.async {
                self.parent.clickedPoint = Coordinate(x: relativePoint.x, y: relativePoint.y)
            }
        }
        
    }
}

struct MapViewState: Equatable {
  let mapPoint: Coordinate?
  let mapPoints: [Coordinate]
  let spline:   Spline?

  static func == (l: MapViewState, r: MapViewState) -> Bool {
    return l.mapPoint == r.mapPoint
        && l.mapPoints == r.mapPoints
        && l.spline   == r.spline
  }
}

struct ZoomableImageView: View {
    @Binding var spline: Spline?
    // world coordinates of point clicked on map
    @Binding var mapPoint: Coordinate?
    @Binding var clickedPoint: Coordinate?
    // wold coorinates of map points or of gpx file
    @Binding var mapPoints: [Coordinate]
    @Binding var imageData: UIImage?
    @State private var convertedMapPoint: Coordinate?
    @State private var convertedMapPoints: [Coordinate] = []
    var mapMode: MapMode
    var onDelete: (Int) -> Void
    
    var body: some View {
        Group {
            if let imageData = imageData {
                // Create a non-optional binding for imageData
                let nonOptionalImageData = Binding<UIImage>(
                    get: { imageData },
                    set: { newValue in self.imageData = newValue }
                )
                ZoomableImageViewRepr(
                    convertedPoint: $convertedMapPoint,
                    clickedPoint: $clickedPoint,
                    mapPoints: $convertedMapPoints,
                    imageData: nonOptionalImageData,
                    mapMode: mapMode,
                    onDelete: onDelete
                )
            } else {
                Text("No image loaded")
            }
        }
        .onChange(of: mapPoint, initial: true) {
            if let spl = spline, let point = mapPoint {
                convertedMapPoint = spl.warp([point])[0]
            } else {
                convertedMapPoint = nil
            }
        }.onChange(of: MapViewState(mapPoint: mapPoint, mapPoints: mapPoints, spline: spline), initial: true) {
            if mapMode == .create {
                convertedMapPoints = mapPoints
            } else {
                if let spl = spline {
                    convertedMapPoints = spl.warp(mapPoints)
                } else {
                    convertedMapPoints = []
                }
            }
        }
    }
}
