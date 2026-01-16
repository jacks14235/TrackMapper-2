//
//  ImageView.swift
//  Test Project
//
//  Created by Jack Stanley on 3/5/25.
//
import SwiftUI

struct ImageView: View {
    @Binding var convertedPoint: Coordinate?
    @Binding var clickedPoint: Coordinate?
    @Binding var mapPoints: [Coordinate]
    @Binding var imageData: UIImage?
    @State var imageWidth: CGFloat = 0
    @State var imageHeight: CGFloat = 0
    @State private var deleteModalLocation: CGPoint? = nil
    @State private var deleteIndex: Int = 0
    @State private var longPressLocation: CGPoint? = nil
    var GPSPath: [Coordinate] = []
    var onDelete: (Int) -> Void

    var body: some View {

        ZStack(alignment: .top) {
            if let image = imageData {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageWidth, height: imageHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if deleteModalLocation != nil {
                                deleteModalLocation = nil
                            } else {
                                clickedPoint = getNormalizedCoordinates(location)
                            }
                        }
                        .gesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .onEnded { _ in
                                    if let loc = longPressLocation {
                                        let normX = loc.x / geo.size.width
                                        let normY = loc.y / geo.size.height
                                        let normalizedLocation = CGPoint(x: normX, y: normY)
                                        print("Long press completed at \(normalizedLocation)")
                                        trySetDeleteModal(location: normalizedLocation)
                                    } else {
                                        print("Long press happened but no location")
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    longPressLocation = value.location
                                }
                        )
                }
            } else {
                Text("No image loaded")
            }

            Group {
                ForEach(mapPoints, id: \.self) { point in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 5, height: 5)
                        .position(
                            x: point.x * imageWidth,
                            y: point.y * imageHeight
                        )
                }
                if let point = clickedPoint {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 5, height: 5)
                        .position(
                            x: point.x * imageWidth,
                            y: point.y * imageHeight
                        )
                }
                if let point = convertedPoint {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                        .position(
                            x: point.x * imageWidth,
                            y: point.y * imageHeight
                        )
                }
                if let loc = deleteModalLocation {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 30, height: 30)

                        Image(systemName: "trash.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                            .padding(6)
                    }
                    .position(
                        x: loc.x * imageWidth,
                        y: loc.y * imageHeight - 17.5
                    )
                    .onTapGesture() {
                        print("Deleting \(deleteIndex)")
                        deleteModalLocation = nil
                        onDelete(deleteIndex)
                    }
                }
            }
        }
        .frame(width: imageWidth, height: imageHeight)
        .onChange(of: imageData, initial: true) {
            if let image = imageData {
                imageWidth = UIScreen.main.bounds.width
                imageHeight = image.size.height / image.size.width * UIScreen.main.bounds.width
            }
        }
    }
    
    func trySetDeleteModal(location: CGPoint) {
        var shortestDist = Double.infinity
        var argmin = 0
        let locationCoord = Coordinate(x: location.x, y: location.y)

        for (i, coord) in mapPoints.enumerated() {
            let dx = locationCoord.x - coord.x
            let dy = locationCoord.y - coord.y
            let dist = dx * dx + dy * dy
            
            if dist < shortestDist {
                shortestDist = dist
                argmin = i
            }
        }
        shortestDist = sqrt(shortestDist)
        if shortestDist < 1 { // turned off for now
            deleteModalLocation = CGPoint(x: mapPoints[argmin].x, y: mapPoints[argmin].y)
            deleteIndex = argmin
        }
    }

    func getNormalizedCoordinates(_ location: CGPoint) -> Coordinate {
        print("\nTapped at: \(location), Image Size: \(imageWidth)x\(imageHeight)")
        return Coordinate(x: location.x / imageWidth, y: location.y / imageHeight)
    }
}
