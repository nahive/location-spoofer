//
//  ViewController.swift
//  location-spoofer
//
//  Created by Szymon Maslanka on 13/07/16.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import AppKit
import MapKit

let knownLocations = ["smt" : CLLocation(latitude:  51.102411, longitude: 17.032319)]

class ViewController: NSViewController {
  
  enum State: String {
    case idle, selectingStart, selectingEnd, ready, running, paused
  }
  
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var visualEffectView: NSVisualEffectView!
  @IBOutlet weak var statusLabel: NSTextField!
  @IBOutlet weak var startButton: NSButton!
  @IBOutlet weak var startLocationLabel: NSTextField!
  @IBOutlet weak var endButton: NSButton!
  @IBOutlet weak var endLocationLabel: NSTextField!
  @IBOutlet weak var runButton: NSButton!
  @IBOutlet weak var pauseButton: NSButton!
  @IBOutlet weak var routeCheckMark: NSButton!
  
  let manager = GPXManager()
  
  var startAnnotation: Annotation?
  var currentAnnotation: Annotation?
  var endAnnotation: Annotation?
  var routePolyline: MKPolyline?
  
  var state: State = .idle {
    didSet {
      handleStateChange()
    }
  }
  
  var shouldUseRoute = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  private func setup(){
    state = .idle
    visualEffectView.wantsLayer = true
    manager.delegate = self
    manager.create()
    setupMapView()
    setupAnnotations()
  }
  
  private func setupMapView(){
    mapView.delegate = self
    mapView.showsCompass = false
    mapView.showsUserLocation = true
    
    let gesture = NSClickGestureRecognizer(target: self, action: #selector(mouseClick(_:)))
    mapView.addGestureRecognizer(gesture)
    
    let region = MKCoordinateRegionMakeWithDistance(knownLocations["smt"]!.coordinate, 500, 500)
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
    if sender.state == NSOnState {
      state = .selectingStart
    } else {
      if let _ = startAnnotation {
        state = .ready
      } else {
        state = .idle
      }
    }
  }
  
  @IBAction func endButtonClicked(sender: NSButton) {
    if sender.state == NSOnState {
      state = .selectingEnd
    } else {
      if let _ = endAnnotation {
        state = .ready
      } else {
        state = .idle
      }
    }
  }
  
  @IBAction func runButtonClicked(sender: NSButton) {
    if state == .ready {
      state = .running
    }
  }
  
  @IBAction func pauseButtonClicked(sender: NSButton) {
    state = sender.state == NSOnState ? .paused : .running
  }
  
  @IBAction func routeCheckmarkClicked(sender: NSButton) {
    shouldUseRoute = sender.state == NSOnState
    if shouldUseRoute {
      fetchRoute({ (route) in
        if let route = route {
          self.drawRoute(self.parseRoute(route))
        }
      })
    } else {
      drawRoute(<#T##locations: [CLLocationCoordinate2D]##[CLLocationCoordinate2D]#>)
    }
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
  
  private func fetchRoute(completion: (route: MKRoute?) -> Void) {
    guard let startCoordinate = startAnnotation?.coordinate,
      let endCoordinate = endAnnotation?.coordinate else {
        print("something bad happened, one of annotations is nil")
        completion(route: nil)
        return
    }
    
    let directionRequest = MKDirectionsRequest()
    let start = MKPlacemark(coordinate: startCoordinate, addressDictionary: nil)
    let end = MKPlacemark(coordinate: endCoordinate, addressDictionary: nil)
    directionRequest.source = MKMapItem(placemark: start)
    directionRequest.destination = MKMapItem(placemark: end)
    directionRequest.transportType = .Walking
    
    let directions = MKDirections(request: directionRequest)
    
    directions.calculateDirectionsWithCompletionHandler({ (response, error) in
      guard let response = response else {
        if let error = error {
          print(error.localizedDescription)
          completion(route: nil)
        }
        return
      }
      
      if let route = response.routes.first {
        completion(route: route)
      }
    })
  }
  
  private func parseRoute(route: MKRoute) -> [CLLocationCoordinate2D] {
    var coordsPointer = UnsafeMutablePointer<CLLocationCoordinate2D>.alloc(route.polyline.pointCount)
    route.polyline.getCoordinates(coordsPointer, range: NSMakeRange(0, route.polyline.pointCount))
    
    var locations = [CLLocationCoordinate2D]()
    for i in 0..<route.polyline.pointCount {
      locations.append(CLLocationCoordinate2D(latitude: coordsPointer[i].latitude,
        longitude: coordsPointer[i].longitude))
    }
    coordsPointer.dealloc(route.polyline.pointCount)
    return locations
  }
  
  private func drawRoute(locations: [CLLocationCoordinate2D]) {
    var locations = locations
    routePolyline = MKPolyline(coordinates: &locations, count: locations.count)
    dispatch_async(dispatch_get_main_queue()) {
      self.mapView.addOverlay((self.routePolyline!), level: MKOverlayLevel.AboveRoads)
    }
  }
  
  private func handleStateChange(){
    statusLabel.stringValue = state.rawValue
    switch state {
    case .idle:
      idleState()
    case .selectingStart:
      selectingStartState()
    case .selectingEnd:
      selectingEndState()
    case .ready:
      readyState()
    case .running:
      runningState()
    case .paused:
      pausedState()
    }
  }
  
  private func idleState(){
    startButton.enabled = true
    startButton.state = NSOnState
    endButton.enabled = true
    endButton.state = NSOnState
    pauseButton.enabled = false
    pauseButton.state = NSOnState
    runButton.enabled = false
    runButton.state = NSOnState
    
    if let route = routePolyline {
      mapView.removeOverlay(route)
    }
    
    if let start = startAnnotation {
      mapView.removeAnnotation(start)
    }
    
    if let current = currentAnnotation {
      mapView.removeAnnotation(current)
    }
    
    if let end = endAnnotation {
      mapView.removeAnnotation(end)
    }
  }
  
  private func selectingStartState(){
    startButton.enabled = true
    startButton.state = NSOffState
    endButton.enabled = false
    endButton.state = NSOnState
    pauseButton.enabled = false
    pauseButton.state = NSOnState
    runButton.enabled = false
    runButton.state = NSOnState
  }
  
  private func selectingEndState(){
    startButton.enabled = false
    startButton.state = NSOnState
    endButton.enabled = true
    endButton.state = NSOffState
    pauseButton.enabled = false
    pauseButton.state = NSOnState
    runButton.enabled = false
    runButton.state = NSOnState
  }
  
  private func readyState(){
    startButton.enabled = true
    startButton.state = NSOnState
    endButton.enabled = true
    endButton.state = NSOnState
    pauseButton.enabled = false
    pauseButton.state = NSOnState
    runButton.enabled = true
    runButton.state = NSOnState
  }
  
  private func runningState(){
    startButton.enabled = false
    startButton.state = NSOnState
    endButton.enabled = true
    endButton.state = NSOnState
    pauseButton.enabled = true
    pauseButton.state = NSOnState
    runButton.enabled = true
    runButton.state = NSOffState
    
    if runButton.state == NSOffState {
      manager.update(startAnnotation!.location)
    } else {
      if shouldUseRoute {
        manager.start(routeLocations)
      } else {
        manager.start(fromLocation: startAnnotation!.location, toLocation: endAnnotation!.location)
      }
    }
  }
  
  private func pausedState(){
    startButton.enabled = false
    startButton.state = NSOnState
    endButton.enabled = true
    endButton.state = NSOnState
    pauseButton.enabled = true
    pauseButton.state = NSOffState
    runButton.enabled = true
    runButton.state = NSOffState
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

