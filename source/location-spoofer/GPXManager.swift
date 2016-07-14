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
    case running
    case paused
  }
  
  // props
  weak var delegate: GPXManagerDelegate?
  
  private var state: State = .idle {
    didSet {
      handleStateChange()
    }
  }
  
  private let file = GPXFile()
  private var timer: NSTimer?
  
  private var currentIndex = 0
  private var startLocation: CLLocationCoordinate2D! {
    return locations.first!
  }
  private var currentLocation: CLLocationCoordinate2D!
  private var endLocation: CLLocationCoordinate2D! {
    return locations.last!
  }
  
  var locations = [CLLocationCoordinate2D]()
  
  private func run(){
    
    var fixedLocations = [CLLocationCoordinate2D]()
    
    for index in 0...locations.count-1 {
      let nextIndex = index+1
      if nextIndex < locations.count {
        let start = locations[index]
        let end = locations[nextIndex]
        let distance = CLLocation(coordinate: end).distanceFromLocation(CLLocation(coordinate: start))
        let numberOfSteps = Int(distance/speed)
        let differenceLat = (end.latitude - start.latitude) / Double(numberOfSteps)
        let differenceLng = (end.longitude - start.longitude) / Double(numberOfSteps)
        
        for step in 0...numberOfSteps {
          let delta =  0.000001 * Double(arc4random_uniform(10))
          fixedLocations.append(CLLocationCoordinate2D(latitude: start.latitude + (differenceLat * Double(step)) + delta,
            longitude: start.longitude + (differenceLng * Double(step)) + delta))
        }
      } else {
        fixedLocations.append(locations[index])
      }
    }
    
    currentLocation = fixedLocations.first
    currentIndex = 0
    
    locations.removeAll()
    locations = fixedLocations
    
    write(locations)
  }
  
  private func write(locations: [CLLocationCoordinate2D]){
    state = .running
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
  
  func resume(){
    if locations.count > currentIndex {
      state = .running
      run(fromLocation: currentLocation, toLocation: endLocation)
    } else {
      print("couldn't resume from location")
    }
  }
  
  func stop(){
    
  }
  
  private func startTimer() {
    if timer == nil {
      timer = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: #selector(updateCurrentLocation), userInfo: nil, repeats: true)
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
  
  private func handleStateChange(){
    
  }
  
  // runs script that selected menu in xcode Debug/Simulate location/track.gpx
  // which refreshes the track on device
  private func runScript(){
    NSWorkspace.sharedWorkspace().launchApplication("RunGPX")
  }
}

extension CLLocation {
  convenience init(coordinate: CLLocationCoordinate2D) {
    self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}