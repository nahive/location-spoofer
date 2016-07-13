//
//  GPXManager.swift
//  catchemall
//
//  Created by Szymon Maslanka on 12/07/16.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import Foundation
import AppKit
import MapKit

let speed = 2.0

protocol GPXManagerDelegate: class {
  func gpxManager(manager: GPXManager, didUpdateCurrentLocation location: CLLocation)
  func gpxManager(manager: GPXManager, didCompleteRouteAtLocation location: CLLocation)
}

class GPXManager {
  
  // much needed enums for saving states
  private enum State {
    case idle
    case moving
    case paused
  }
  
  enum Options: String {
    case create = "create"
    case start = "start"
    case pause = "pause"
    case resume = "resume"
    case move = "move"
    case end = "end"
  }
  
  // props
  weak var delegate: GPXManagerDelegate?
  
  private var timer: NSTimer?
  
  private var state: State = .idle
  private let file = GPXFile()
  
  private var currentIndex = 0
  private var startLocation: CLLocation!
  private var currentLocation: CLLocation!
  private var endLocation: CLLocation!
  
  private var locations = [CLLocation]()
  
  func create(){
    file.create()
  }
  
  func start(fromLocation start: CLLocation, toLocation end: CLLocation){
    startLocation = start
    currentLocation = start
    endLocation = end
    currentIndex = 0
    
    let distance = end.distanceFromLocation(start)
    let numberOfSteps = Int(distance/speed)
    let differenceLat = (end.coordinate.latitude - start.coordinate.latitude) / Double(numberOfSteps)
    let differenceLng = (end.coordinate.longitude - start.coordinate.longitude) / Double(numberOfSteps)
    
    locations.removeAll()
    
    for step in 0...numberOfSteps {
      let delta =  0.000001 * Double(arc4random_uniform(10))
      locations.append(CLLocation(latitude: start.coordinate.latitude + (differenceLat * Double(step)) + delta,
        longitude: start.coordinate.longitude + (differenceLng * Double(step)) + delta))
    }
    
    state = .moving
    file.write(locations)
    runScript()
    startTimer()
  }
  
  func start(routeLocations: [CLLocation]){
    
    var fixedLocations = [CLLocation]()
    
    for index in 0...routeLocations.count-1 {
      let nextIndex = index+1
      if nextIndex < routeLocations.count {
        let start = routeLocations[index]
        let end = routeLocations[nextIndex]
        let distance = end.distanceFromLocation(start)
        let numberOfSteps = Int(distance/speed)
        let differenceLat = (end.coordinate.latitude - start.coordinate.latitude) / Double(numberOfSteps)
        let differenceLng = (end.coordinate.longitude - start.coordinate.longitude) / Double(numberOfSteps)
        
        for step in 0...numberOfSteps {
          let delta =  0.000001 * Double(arc4random_uniform(10))
          fixedLocations.append(CLLocation(latitude: start.coordinate.latitude + (differenceLat * Double(step)) + delta,
            longitude: start.coordinate.longitude + (differenceLng * Double(step)) + delta))
        }
      } else {
        fixedLocations.append(routeLocations[index])
      }
    }
    
    startLocation = fixedLocations.first
    currentLocation = fixedLocations.first
    endLocation = fixedLocations.last
    
    currentIndex = 0
    
    locations.removeAll()
    locations = fixedLocations
    state = .moving
    file.write(locations)
    runScript()
    startTimer()
  }
  
  func pause(){
    if locations.count > currentIndex {
      state = .paused
      file.write([currentLocation])
      runScript()
      print("paused at location \(currentLocation)")
    } else {
      print("couldn't pause at location")
    }
  }
  
  func update(endLocation: CLLocation){
    start(fromLocation: currentLocation, toLocation: endLocation)
  }
  
  func resume(){
    if locations.count > currentIndex {
      state = .moving
      start(fromLocation: currentLocation, toLocation: endLocation)
    } else {
      print("couldn't resume from location")
    }
  }
  
  private func startTimer() {
    if timer == nil {
      timer = NSTimer.scheduledTimerWithTimeInterval(1.2, target: self, selector: #selector(updateCurrentLocation), userInfo: nil, repeats: true)
    }
    timer?.fire()
  }
  
  private func stopTimer(){
    timer?.invalidate()
    timer = nil
  }
  
  // updates current location reference to keep track of where the user currently is
  @objc func updateCurrentLocation(){
    if state == .moving {
      if self.locations.count > self.currentIndex+1 {
        self.currentIndex += 1
        self.currentLocation = self.locations[self.currentIndex]
        self.delegate?.gpxManager(self, didUpdateCurrentLocation: self.currentLocation)
      } else {
        if self.currentLocation == self.startLocation {
          self.currentIndex = 0
          self.locations.removeAll()
          self.file.write(self.locations)
          self.runScript()
        } else {
          self.delegate?.gpxManager(self, didCompleteRouteAtLocation: self.currentLocation)
        }
      }
    } else {
      stopTimer()
    }
  }
  
  // runs script that selected menu in xcode Debug/Simulate location/track.gpx
  // which refreshes the track on device
  private func runScript(){
    NSWorkspace.sharedWorkspace().launchApplication("RunGPX")
  }
}