//
//  ContentView.swift
//  Test Project
//
//  Created by Jack Stanley on 3/8/25.
//
import SwiftUI
import MapKit

// coordinates for debugging
let whiteface = CLLocationCoordinate2D(latitude: 44.36170574685005, longitude: -73.87806880950926)
let shawnee = CLLocationCoordinate2D(latitude: 41.035850, longitude: -75.076705)

class Frame: Equatable {
    public var topLeft: CLLocationCoordinate2D
    public var topRight: CLLocationCoordinate2D
    public var bottomLeft: CLLocationCoordinate2D
    public var bottomRight: CLLocationCoordinate2D

    init(topLeft: CLLocationCoordinate2D, topRight: CLLocationCoordinate2D,
         bottomLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    static func defualt() -> Frame {
        return Frame(topLeft: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                     topRight: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                     bottomLeft: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                     bottomRight: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    }

    static func == (lhs: Frame, rhs: Frame) -> Bool {
        return lhs === rhs
    }
}


// Creates a frame from the given map view
func getFrame(from mapView: MKMapView) -> Frame {
    let topLeft = mapView.convert(CGPoint(x: 0, y: 0), toCoordinateFrom: mapView)
    let topRight = mapView.convert(CGPoint(x: mapView.bounds.width, y: 0), toCoordinateFrom: mapView)
    let bottomLeft = mapView.convert(CGPoint(x: 0, y: mapView.bounds.height), toCoordinateFrom: mapView)
    let bottomRight = mapView.convert(CGPoint(x: mapView.bounds.width, y: mapView.bounds.height), toCoordinateFrom: mapView)

    return Frame(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
}



func toCLLCoords(coords: [Coordinate]) -> [CLLocationCoordinate2D] {
    return coords.map { CLLocationCoordinate2D(latitude: $0.x, longitude: $0.y) }
}

// Had to use UIKit for animated frame updates
struct AnimatedMapView: UIViewRepresentable {
    @Binding var clickedCoordinate: Coordinate?
    @Binding var spline: Spline?
    @Binding var frame: Frame
    @Binding var annotationCoordinates: [CLLocationCoordinate2D]
    @Binding var shouldRecenter: Bool
    @Binding var center: CLLocationCoordinate2D
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        let span = (center.latitude == 0 && center.longitude == 0) ? 30 : 0.05
        let initialRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        mapView.setRegion(initialRegion, animated: false)
        mapView.mapType = .satellite  // Using imagery style
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations)
        
        // update center after a search
        if shouldRecenter {
            let span = (center.latitude == 0 && center.longitude == 0) ? 30 : 0.05
            let newRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            uiView.setRegion(newRegion, animated: true)
        }
        
        for (index, coord) in annotationCoordinates.enumerated() {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coord
            annotation.title = "\(index + 1)"
            uiView.addAnnotation(annotation)
        }
        
        if let clicked = clickedCoordinate {
            let clickedAnnotation = MKPointAnnotation()
            clickedAnnotation.coordinate = CLLocationCoordinate2D(latitude: clicked.x, longitude: clicked.y)
            clickedAnnotation.title = "Clicked"
            uiView.addAnnotation(clickedAnnotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AnimatedMapView
        var didSetInitialRegion = false
        
        init(_ parent: AnimatedMapView) {
            self.parent = parent
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            DispatchQueue.main.async {
                self.parent.frame = getFrame(from: mapView)
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            DispatchQueue.main.async {
                self.parent.clickedCoordinate = Coordinate(x: coordinate.latitude, y: coordinate.longitude)
                self.parent.shouldRecenter = false
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                DispatchQueue.main.async {
                    self.parent.shouldRecenter = false
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let identifier = "Annotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.frame = CGRect(x: 0, y: 0, width: 6, height: 6)
                annotationView?.layer.cornerRadius = 3
                annotationView?.backgroundColor = annotation.title == "Clicked" ? UIColor.green : UIColor.red
            } else {
                annotationView?.annotation = annotation
                annotationView?.backgroundColor = annotation.title == "Clicked" ? UIColor.green : UIColor.red
            }
            return annotationView
        }
    }
}

struct MapView: View {
    @Binding var clickedCoordinate: Coordinate?
    @Binding var spline: Spline?
    @Binding var imageData: UIImage?
    @State var frame = Frame.defualt()
    @State var annotationCoordinates: [CLLocationCoordinate2D] = []
    @State var hide: Bool = true
    @State var opacity: Double = 1
    @State private var searchText = ""
    @State var shouldRecenter = false
    @State var center: CLLocationCoordinate2D
    
    var body: some View {
        VStack {
            ZStack {
                AnimatedMapView(
                    clickedCoordinate: $clickedCoordinate,
                    spline: $spline,
                    frame: $frame,
                    annotationCoordinates: $annotationCoordinates,
                    shouldRecenter: $shouldRecenter,
                    center: $center
                )
                .searchable(text: $searchText, prompt: "Search for a location")
                .onSubmit(of: .search) {
                    performSearch(query: searchText)
                }
                .onChange(of: spline, initial: true) {
                    if let spline = spline {
                        print("MapView spline change with \(spline.realCoords.count) points")
                        self.annotationCoordinates = toCLLCoords(coords: spline.realCoords)
                    }
                }
                if let spl = self.spline {
                    if !hide && spl.m > 3 {
                        if let img = Binding($imageData) {
                            ShaderView(spline: Binding.constant(spl), frame: $frame, image: img).opacity(opacity)
                        }
                    }
                }
            }
            HStack {
                Button(action: {self.hide = !self.hide}) {
                    Image(systemName: hide ? "map.circle" : "map.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(.black)
                }
                Slider(value: $opacity, in: 0...1).padding().disabled(self.hide)
            }
        }
    }
    
    func performSearch(query: String) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query

        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            if let error = error {
                print("Search error: \(error.localizedDescription)")
                return
            }
            guard let response = response,
                  let firstItem = response.mapItems.first else {
                print("No results found")
                return
            }
            
            // Retrieve the coordinate of the first result.
            let coordinate = firstItem.placemark.coordinate
            
            DispatchQueue.main.async {
                print("Setting to true")
                shouldRecenter = true
                center = coordinate
            }
        }
    }

}


//#Preview {
//    MapView(clickedCoordinate: .constant(nil), spline: .constant(nil), frame: .constant(nil))
//}
