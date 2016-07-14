//
//  ViewController.swift
//  location-spoofer
//
//  Created by Szymon Maslanka on 13/07/16.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

//import AppKit
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
  
  private let manager = GPXManager()
  
  private var startAnnotation: Annotation?
  private var currentAnnotation: Annotation?
  private var endAnnotation: Annotation?
  private var routePolyline: MKPolyline?
  
  private var locations: [CLLocationCoordinate2D]?
  
  private var state: State = .idle {
    didSet {
      handleStateChange()
    }
  }
  
  private var shouldStickToRoads: Bool {
    return routeCheckMark.state == NSOnState
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  private func setup(){
    state = .idle
    manager.delegate = self
    
    setupMapView()
    
    // needed for displaying transparency over map
    visualEffectView.wantsLayer = true
  }
  
  private func setupMapView(){
    mapView.delegate = self
    mapView.showsCompass = false
    mapView.showsUserLocation = true
    mapView.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(mouseClick(_:))))
    
    let region = MKCoordinateRegionMakeWithDistance(knownLocations["smt"]!.coordinate, 500, 500)
    let adjRegion = mapView.regionThatFits(region)
    mapView.setRegion(adjRegion, animated: true)
  }
  
  //MARK: clicks
  @IBAction func startButtonClicked(sender: NSButton) {
    state = sender.state == NSOnState ? .selectingStart : endAnnotation != nil ? .ready : .idle
  }
  
  @IBAction func endButtonClicked(sender: NSButton) {
    state = sender.state == NSOnState ? .selectingEnd : startAnnotation != nil ? .ready : .idle
  }
  
  @IBAction func runButtonClicked(sender: NSButton) {
    state = state == .ready ? .running : .ready
    switch state {
    case .ready:
      state = .idle
      manager.stop()
    case .running:
      guard let locations = locations else {
        print("can't start. no locations")
        state = .ready
        return
      }
      manager.run(locations: locations)
    default:
      break
    }
  }
  
  @IBAction func pauseButtonClicked(sender: NSButton) {
    state = sender.state == NSOnState ? .paused : .running
    switch state {
    case .paused:
      manager.pause()
    case .running:
      manager.resume()
    default:
      break
    }
  }
  
  @IBAction func routeCheckmarkClicked(sender: NSButton) {
    drawRoute()
  }
  
  func mouseClick(_ recognizer: NSClickGestureRecognizer){
    let point = recognizer.location(in: mapView)
    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
    switch state {
    case .idle:
      break
    case .selectingStart:
      startLocationLabel.stringValue = "lat: \(coordinate.latitude)\nlng: \(coordinate.longitude)"
      if startAnnotation == nil {
        startAnnotation = Annotation(title: "Starting location", coordinate: CLLocationCoordinate2D())
        mapView.addAnnotation(startAnnotation!)
      }
      startAnnotation?.coordinate = coordinate
      startButton.state = NSOffState
      startButtonClicked(sender: startButton)
      
      mapView.removeOverlays(mapView.overlays)
      drawRoute()
    case .selectingEnd:
      endLocationLabel.stringValue = "lat: \(coordinate.latitude)\nlng: \(coordinate.longitude)"
      if endAnnotation == nil {
        endAnnotation = Annotation(title: "End location", coordinate: CLLocationCoordinate2D())
        mapView.addAnnotation(endAnnotation!)
      }
      endButton.state = NSOffState
      endAnnotation?.coordinate = coordinate
      endButtonClicked(sender: endButton)
      
      mapView.removeOverlays(mapView.overlays)
      drawRoute()
      proceed()
    case .ready:
      break
    case .paused, .running:
      break
    }
  }
  
  private func proceed(){
    
    //    if runButton.state == NSOffState {
    //      manager.update(startAnnotation!.location)
    //    } else {
    //      if shouldUseRoute {
    //        manager.start(routeLocations)
    //      } else {
    //        manager.start(fromLocation: startAnnotation!.location, toLocation: endAnnotation!.location)
    //      }
    //    }
    //    if isRunning {
    //      if shouldUseRoute {
    //        markRoute(currentAnnotation.coordinate, end: endAnnotation.coordinate, done: { (locations) in
    //          DispatchQueue.main.async(execute: {
    //            self.manager.start(locations)
    //          })
    //        })
    //      } else {
    //        markLine(currentAnnotation.coordinate, end: endAnnotation.coordinate)
    //        manager.update(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    //      }
    //    }
  }
  
  //MARK: routes
  private func drawRoute(){
    if shouldStickToRoads {
      fetchRoute {
        self.locations = self.parseRoute(route: $0)
        self.drawRoute(locations: self.locations) }
    } else {
      locations = parseLocations(start: startAnnotation?.coordinate, end: endAnnotation?.coordinate)
      drawRoute(locations: self.locations)
    }
  }
  
  private func fetchRoute(completion: (route: MKRoute?) -> Void) {
    print("fetching route")
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
    directionRequest.transportType = .walking
    
    let directions = MKDirections(request: directionRequest)
    directions.calculate(completionHandler: { (response, error) in
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
  
  private func parseRoute(route: MKRoute?) -> [CLLocationCoordinate2D]? {
    print("parsing route")
    guard let route = route else {
      print("can't parse nil route 🤔")
      return nil
    }
    
    let coordsPointer = UnsafeMutablePointer<CLLocationCoordinate2D>(allocatingCapacity: route.polyline.pointCount)
    route.polyline.getCoordinates(coordsPointer, range: NSMakeRange(0, route.polyline.pointCount))
    
    var locations = [CLLocationCoordinate2D]()
    for i in 0..<route.polyline.pointCount {
      locations.append(CLLocationCoordinate2D(latitude: coordsPointer[i].latitude,
                                              longitude: coordsPointer[i].longitude))
    }
    coordsPointer.deallocateCapacity(route.polyline.pointCount)
    return locations
  }
  
  private func parseLocations(start: CLLocationCoordinate2D?, end: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D]? {
    print("paring locations")
    guard let start = start, let end = end else {
      print("can't parse nil locations 🤔")
      return nil
    }
    return [start, end]
  }
  
  private func drawRoute(locations: [CLLocationCoordinate2D]?) {
    print("drawing route")
    guard var locations = locations else {
      return print("can't draw nil route 🤔")
    }
    
    if let routePolyline = routePolyline {
      mapView.remove(routePolyline)
    }
    
    routePolyline = MKPolyline(coordinates: &locations, count: locations.count)
    mapView.add((routePolyline!), level: MKOverlayLevel.aboveRoads)
    
  }
  
  //MARK: handling state changes
  private func handleStateChange(){
    print(state.rawValue)
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
    startButton.isEnabled = true
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    pauseButton.isEnabled = false
    pauseButton.state = NSOffState
    runButton.isEnabled = false
    runButton.state = NSOffState
  }
  
  private func selectingStartState(){
    startButton.isEnabled = true
    startButton.state = NSOnState
    endButton.isEnabled = false
    endButton.state = NSOffState
    pauseButton.isEnabled = false
    pauseButton.state = NSOffState
    runButton.isEnabled = false
    runButton.state = NSOffState
  }
  
  private func selectingEndState(){
    startButton.isEnabled = false
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOnState
    pauseButton.isEnabled = false
    pauseButton.state = NSOffState
    runButton.isEnabled = false
    runButton.state = NSOffState
  }
  
  private func readyState(){
    startButton.isEnabled = true
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    pauseButton.isEnabled = false
    pauseButton.state = NSOffState
    runButton.isEnabled = true
    runButton.state = NSOffState
  }
  
  private func runningState(){
    startButton.isEnabled = false
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    pauseButton.isEnabled = true
    pauseButton.state = NSOffState
    runButton.isEnabled = true
    runButton.state = NSOnState
  }
  
  private func pausedState(){
    startButton.isEnabled = false
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    pauseButton.isEnabled = true
    pauseButton.state = NSOnState
    runButton.isEnabled = true
    runButton.state = NSOnState
  }
  
  private func clearMap(){
    if let route = routePolyline {
      mapView.remove(route)
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
}

//MARK: MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let renderer = MKPolylineRenderer(overlay: overlay)
    renderer.strokeColor = NSColor.purple()
    renderer.lineWidth = 4.0
    return renderer
  }
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    let pinView = MKPinAnnotationView()
    if annotation.isEqual(startAnnotation) {
      pinView.pinTintColor = .green()
    } else if annotation.isEqual(currentAnnotation) {
      pinView.pinTintColor = .purple()
    } else if annotation.isEqual(endAnnotation) {
      pinView.pinTintColor = .red()
    }
    pinView.centerOffset = CGPoint(x: 8, y: -16)
    return pinView
  }
}

//MARK: GPXManagerDelegate
extension ViewController: GPXManagerDelegate {
  func gpxManager(manager: GPXManager, didUpdateCurrentLocation location: CLLocationCoordinate2D?) {
    
    guard let location = location else {
      print("can't mark current location. location is nil")
      return
    }
    
    if currentAnnotation == nil {
      currentAnnotation = Annotation(title: "Current location", coordinate: CLLocationCoordinate2D())
      mapView.addAnnotation(self.currentAnnotation!)
    }
    currentAnnotation?.coordinate = location
    
  }
  
  func gpxManager(manager: GPXManager, didCompleteRouteAtLocation location: CLLocationCoordinate2D?) {
    state = .idle
    clearMap()
  }
}

//MARK: help class for annotation
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

