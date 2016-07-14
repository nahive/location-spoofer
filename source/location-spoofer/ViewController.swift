//
//  ViewController.swift
//  location-spoofer
//
//  Created by Szymon Maslanka on 13/07/16.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import AppKit
import MapKit

let knownLocations = ["home" : CLLocation(latitude: 51.090313, longitude: 17.044528),
                      "smt" : CLLocation(latitude:  51.102411, longitude: 17.032319)]

class ViewController: NSViewController {
    
    enum State {
        case idle, starting, ending
    }
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var startLocationLabel: NSTextField!
    @IBOutlet weak var endButton: NSButton!
    @IBOutlet weak var endLocationLabel: NSTextField!
    @IBOutlet weak var runButton: NSButton!
    @IBOutlet weak var pauseButton: NSButton!
    @IBOutlet weak var routeCheckMark: NSButton!
    
    let manager = GPXManager()
    
    var startGesture: NSPressGestureRecognizer?
    var endGesture: NSPressGestureRecognizer?
    var startAnnotation: Annotation!
    var currentAnnotation: Annotation!
    var endAnnotation: Annotation!
    
    var state: State = .idle
    var isRunning = false
    var shouldUseRoute = true
    var routeLocations = [CLLocation]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self
        manager.create()
        pauseButton.enabled = false
        setupMapView()
        setupAnnotations()
    }
    
    private func setupMapView(){
        mapView.delegate = self
        mapView.showsCompass = false
        mapView.showsUserLocation = true
        
        let gesture = NSClickGestureRecognizer(target: self, action: #selector(mouseClick(_:)))
        gesture.numberOfClicksRequired = 2
        mapView.addGestureRecognizer(gesture)
        
        let region = MKCoordinateRegionMakeWithDistance(knownLocations["home"]!.coordinate, 500, 500)
        let adjRegion = mapView.regionThatFits(region)
        mapView.setRegion(adjRegion, animated: true)
    }
    
    private func setupAnnotations(){
        startAnnotation = Annotation(title: "Starting location", coordinate: CLLocationCoordinate2D())
        currentAnnotation = Annotation(title: "Current location", coordinate: CLLocationCoordinate2D())
        endAnnotation = Annotation(title: "End location",
                                       coordinate: CLLocationCoordinate2D())
    }
    
    @IBAction func startButtonClicked(sender: NSButton) {
        if sender.state == NSOffState {
            endButton.enabled = true
            state = .idle
        } else {
            endButton.enabled = false
            state = .starting
        }
    }
    
    @IBAction func endButtonClicked(sender: NSButton) {
        if sender.state == NSOffState {
            startButton.enabled = true
            state = .idle
        } else {
            startButton.enabled = false
            state = .ending
        }
    }
    
    @IBAction func runButtonClicked(sender: NSButton) {
        
        if startAnnotation.coordinate.latitude != 0.0 &&
            endAnnotation.coordinate.latitude != 0.0 {
            isRunning = true
            startButton.enabled = false
            pauseButton.enabled = true
            if sender.state == NSOffState {
                manager.update(startAnnotation.location)
            } else {
                if shouldUseRoute {
                    manager.start(routeLocations)
                } else {
                    manager.start(fromLocation: startAnnotation.location, toLocation: endAnnotation.location)
                }
            }
        }
    }
    
    @IBAction func pauseButtonClicked(sender: NSButton) {
        if sender.state == NSOffState {
            manager.resume()
        } else {
            manager.pause()
        }
    }
    
    @IBAction func routeCheckmarkClicked(sender: NSButton) {
        shouldUseRoute = sender.state == NSOnState
    }
    
    func mouseClick(recognizer: NSClickGestureRecognizer){
        let point = recognizer.locationInView(mapView)
        let coordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
        switch state {
        case .idle:
            break
        case .starting:
            startLocationLabel.stringValue = "lat: \(coordinate.latitude)\nlng: \(coordinate.longitude)"
            if !(mapView.annotations.contains{ $0.isEqual(startAnnotation) }) {
                mapView.addAnnotation(startAnnotation)
            }
            startAnnotation.coordinate = coordinate
            startButton.state = NSOffState
            startButtonClicked(startButton)
            
            mapView.removeOverlays(mapView.overlays)
            if shouldUseRoute {
                markRoute(startAnnotation.coordinate, end: endAnnotation.coordinate, done: { (locations) in })
            } else {
                markLine(startAnnotation.coordinate, end: endAnnotation.coordinate)
            }
        case .ending:
            endLocationLabel.stringValue = "lat: \(coordinate.latitude)\nlng: \(coordinate.longitude)"
            if !(mapView.annotations.contains{ $0.isEqual(endAnnotation) }) {
                mapView.addAnnotation(endAnnotation)
            }
            endAnnotation.coordinate = coordinate
            endButton.state = NSOffState
            endButtonClicked(endButton)
            
            mapView.removeOverlays(mapView.overlays)
            if shouldUseRoute {
                markRoute(startAnnotation.coordinate, end: endAnnotation.coordinate, done: { (locations) in })
            } else {
                markLine(startAnnotation.coordinate, end: endAnnotation.coordinate)
            }
            
            if isRunning {
                if shouldUseRoute {
                    markRoute(currentAnnotation.coordinate, end: endAnnotation.coordinate, done: { (locations) in
                        dispatch_async(dispatch_get_main_queue(), { 
                            self.manager.start(locations)
                        })
                    })
                } else {
                    markLine(currentAnnotation.coordinate, end: endAnnotation.coordinate)
                    manager.update(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            }
        }
    }
    
    func markLine(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D){
        var coordinates = [start, end]
        let polyline = MKPolyline(coordinates: &coordinates, count: 2)
        dispatch_async(dispatch_get_main_queue()) { 
            self.mapView.addOverlay((polyline), level: MKOverlayLevel.AboveRoads)
        }
    }
    
    func markRoute(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, done: (locations: [CLLocation])->Void ){
        let directionRequest = MKDirectionsRequest()
        let start = MKPlacemark(coordinate: start, addressDictionary: nil)
        let end = MKPlacemark(coordinate: end, addressDictionary: nil)
        directionRequest.source = MKMapItem(placemark: start)
        directionRequest.destination = MKMapItem(placemark: end)
        directionRequest.transportType = .Walking
        
        let directions = MKDirections(request: directionRequest)
        
        directions.calculateDirectionsWithCompletionHandler({ (response, error) in
            guard let response = response else {
                if let error = error {
                    print(error.localizedDescription)
                }
                return
            }
            
            if let route = response.routes.first {
                dispatch_async(dispatch_get_main_queue()) {
                    self.mapView.addOverlay((route.polyline), level: MKOverlayLevel.AboveRoads)
                }
                var coordsPointer = UnsafeMutablePointer<CLLocationCoordinate2D>.alloc(route.polyline.pointCount)
                route.polyline.getCoordinates(coordsPointer, range: NSMakeRange(0, route.polyline.pointCount))
                
                self.routeLocations.removeAll()
                for i in 0..<route.polyline.pointCount {
                    self.routeLocations.append(CLLocation(latitude: coordsPointer[i].latitude, longitude: coordsPointer[i].longitude))
                    done(locations: self.routeLocations)
                }
                
                coordsPointer.dealloc(route.polyline.pointCount)
            }
        })
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = NSColor.purpleColor()
        renderer.lineWidth = 4.0
        return renderer
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let pinView = MKPinAnnotationView()
        if annotation.isEqual(startAnnotation) {
            pinView.pinTintColor = .greenColor()
        } else if annotation.isEqual(currentAnnotation) {
            pinView.pinTintColor = .purpleColor()
        } else if annotation.isEqual(endAnnotation) {
            pinView.pinTintColor = .redColor()
        }
        pinView.centerOffset = CGPoint(x: 8, y: -16)
        return pinView
    }
}

extension ViewController: GPXManagerDelegate {
    func gpxManager(manager: GPXManager, didUpdateCurrentLocation location: CLLocation) {
        dispatch_async(dispatch_get_main_queue()) { 
            if !(self.mapView.annotations.contains{ $0.isEqual(self.currentAnnotation) }) {
                self.mapView.addAnnotation(self.currentAnnotation)
            }
            self.currentAnnotation.coordinate = location.coordinate
            self.currentAnnotation.coordinate = location.coordinate
        }
    }
    
    func gpxManager(manager: GPXManager, didCompleteRouteAtLocation location: CLLocation) {
        isRunning = false
        startButton.enabled = true
        endButton.enabled = true
        runButton.state = NSOnState
        pauseButton.state = NSOnState
        pauseButton.enabled = false
        dispatch_async(dispatch_get_main_queue()) { 
            self.mapView.removeAnnotations([self.currentAnnotation,self.startAnnotation,self.endAnnotation])
            self.mapView.removeOverlays(self.mapView.overlays)
        }
    }
}

class Annotation: NSObject, MKAnnotation {
    var title: String?
    dynamic var coordinate: CLLocationCoordinate2D
    
    var location: CLLocation {
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    init(title: String, coordinate: CLLocationCoordinate2D){
        self.title = title
        self.coordinate = coordinate
    }
}

