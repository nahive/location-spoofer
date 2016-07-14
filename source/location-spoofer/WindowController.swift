//
//  WindowController.swift
//  location-spoofer
//
//  Created by Szymon Maślanka on 14/07/2016.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import Cocoa
import MapKit

class WindowController: NSWindowController {
  
  private enum State: String {
    case idle = "idle"
    case selectingStart = "selecting start"
    case selectingEnd = "selecting end"
    case ready = "ready"
    case running = "running"
    case paused = "paused"
  }
  
  private var state: State = .idle {
    didSet {
      handleStateChange()
    }
  }
  
  @IBOutlet weak var toolbar: NSToolbar!
  @IBOutlet weak var statusLabel: NSTextField!
  @IBOutlet weak var startButton: NSButton!
  @IBOutlet weak var endButton: NSButton!
  @IBOutlet weak var runPauseStopSegmentedControl: NSSegmentedControl!
  @IBOutlet weak var settingsButton: NSButton!
  
  private struct RPSSegments {
    static let none = -1
    static let run = 0
    static let pause = 1
    static let stop = 2
  }
  
  private let manager = GPXManager()
  private var locations: [CLLocationCoordinate2D]?
  
  private var mapController: MapViewController!
  private var settingsController: SettingsViewController!
  
  private var startLocation: CLLocationCoordinate2D? {
    return mapController.startAnnotation?.coordinate
  }
  private var currentLocation: CLLocationCoordinate2D? {
    return mapController.currentAnnotation?.coordinate
  }
  private var endLocation: CLLocationCoordinate2D? {
    return mapController.endAnnotation?.coordinate
  }
  
  private var shouldStickToRoads = true
  
  override func windowDidLoad() {
    super.windowDidLoad()
    setup()
  }
  
  private func setup(){
    mapController = window!.contentViewController as! MapViewController
    mapController.delegate = self
    
    settingsController = SettingsViewController(nibName: "SettingsViewController", bundle: Bundle.main())
    
    window!.titleVisibility = .hidden
    window!.styleMask = [window!.styleMask, NSFullSizeContentViewWindowMask]
    window!.toolbar?.showsBaselineSeparator = true
    
    state = .idle
    manager.delegate = self
  }
  
  //MARK: clicks
  @IBAction func startButtonClicked(sender: NSButton) {
    state = sender.state == NSOnState ? .selectingStart : endLocation != nil ? .ready : .idle
  }
  
  @IBAction func endButtonClicked(sender: NSButton) {
    state = sender.state == NSOnState ? .selectingEnd : startLocation != nil ? .ready : .idle
  }
  
  @IBAction func runPauseStopSegmentedControllerClick(_ sender: NSSegmentedControl) {
    switch sender.selectedSegment {
    case RPSSegments.run:
      runButtonClicked()
    case RPSSegments.pause:
      pauseButtonClicked()
    case RPSSegments.stop:
      stopButtonClicked()
    default:
      break
    }
  }
  
  func runButtonClicked() {
    if state == .paused {
      state = .running
      manager.resume()
    } else {
      guard let locations = locations else {
        print("can't start. no locations")
        state = .ready
        return
      }
      state = .running
      manager.run(locations: locations)
    }
  }
  
  func pauseButtonClicked() {
    state = .paused
    manager.pause()
  }
  
  func stopButtonClicked(){
    state = .idle
    manager.stop()
  }
  
  @IBAction func settingsButtonClicked(sender: NSButton) {
    settingsController.toggle(sender: sender)
  }
  
  //MARK: routes
  private func drawRoute(){
    if shouldStickToRoads {
      fetchRoute {
        self.locations = self.parseRoute(route: $0)
        self.mapController.drawRoute(locations: self.locations)
      }
    } else {
      locations = parseLocations(start: startLocation, end: endLocation)
      mapController.drawRoute(locations: locations)
    }
  }
  
  private func fetchRoute(completion: (route: MKRoute?) -> Void) {
    print("fetching route")
    guard let startCoordinate = startLocation,
      let endCoordinate = endLocation else {
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
  
  //MARK: handling state changes
  private func handleStateChange(){
    
    switch state {
    case .idle:
      statusLabel.stringValue = "Status: \(state.rawValue.capitalized) 😴 "
      idleState()
    case .selectingStart:
      statusLabel.stringValue = "Status: \(state.rawValue.capitalized) 📍"
      selectingStartState()
    case .selectingEnd:
      statusLabel.stringValue = "Status: \(state.rawValue.capitalized) 📍"
      selectingEndState()
    case .ready:
      statusLabel.stringValue = "Status: \(state.rawValue.capitalized) 💪"
      readyState()
    case .running:
      statusLabel.stringValue = "Status: \(state.rawValue.capitalized) ✨"
      runningState()
    case .paused:
      statusLabel.stringValue = "Status: \(state.rawValue.capitalized) 🕙"
      pausedState()
    }
  }
  
  private func idleState(){
    startButton.isEnabled = true
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    runPauseStopSegmentedControl.selectedSegment = RPSSegments.none
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.run)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.pause)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.stop)
  }
  
  private func selectingStartState(){
    startButton.isEnabled = true
    startButton.state = NSOnState
    endButton.isEnabled = false
    endButton.state = NSOffState
    runPauseStopSegmentedControl.selectedSegment = RPSSegments.none
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.run)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.pause)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.stop)
  }
  
  private func selectingEndState(){
    startButton.isEnabled = false
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOnState
    runPauseStopSegmentedControl.selectedSegment = RPSSegments.none
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.run)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.pause)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.stop)
  }
  
  private func readyState(){
    startButton.isEnabled = true
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    runPauseStopSegmentedControl.selectedSegment = RPSSegments.none
    runPauseStopSegmentedControl.setEnabled(true, forSegment: RPSSegments.run)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.pause)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.stop)
  }
  
  private func runningState(){
    startButton.isEnabled = false
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.run)
    runPauseStopSegmentedControl.setEnabled(true, forSegment: RPSSegments.pause)
    runPauseStopSegmentedControl.setEnabled(true, forSegment: RPSSegments.stop)
  }
  
  private func pausedState(){
    startButton.isEnabled = false
    startButton.state = NSOffState
    endButton.isEnabled = true
    endButton.state = NSOffState
    runPauseStopSegmentedControl.setEnabled(true, forSegment: RPSSegments.run)
    runPauseStopSegmentedControl.setEnabled(false, forSegment: RPSSegments.pause)
    runPauseStopSegmentedControl.setEnabled(true, forSegment: RPSSegments.stop)
  }
  
}

//MARK: GPXManagerDelegate
extension WindowController: GPXManagerDelegate {
  func gpxManager(manager: GPXManager, didUpdateCurrentLocation location: CLLocationCoordinate2D?) {
    guard let location = location else {
      print("can't mark current location. location is nil")
      return
    }

    mapController.drawCurrentLocation(location: location)
  }
  
  func gpxManager(manager: GPXManager, didCompleteRouteAtLocation location: CLLocationCoordinate2D?) {
    state = .idle
    mapController.clearMap()
  }
}

extension WindowController: MapViewControllerDelegate {
  func mapViewController(controller: MapViewController, mapView: MKMapView, didClickAtLocation location: CLLocationCoordinate2D) {
    switch state {
    case .idle:
      break
    case .selectingStart:
      state = endLocation != nil ? .ready : .idle
      mapController.drawStartAnnotation(location: location)
      drawRoute()
    case .selectingEnd:
      state = startLocation != nil ? .ready : .idle
      mapController.drawEndLocation(location: location)
      drawRoute()
    case .ready:
      break
    case .paused, .running:
      break
    }
    
  }
}

extension WindowController: SettingsViewControllerDelegate {
  func settingsViewController(controller: SettingsViewController, stickToRoadsEnabled enabled: Bool) {
    shouldStickToRoads = enabled
    drawRoute()
  }
  
  func settingsViewController(controller: SettingsViewController, trackingSpeedChanged speed: TrackingSpeed) {
    manager.trackingSpeed = speed
  }
}
