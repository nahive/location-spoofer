//
//  GPXManager.swift
//  catchemall
//
//  Created by Szymon Maslanka on 12/07/16.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import MapKit

let speed = 2.0

protocol GPXManagerDelegate: class {
  func gpxManager(manager: GPXManager, didUpdateCurrentLocation location: CLLocationCoordinate2D?)
  func gpxManager(manager: GPXManager, didCompleteRouteAtLocation location: CLLocationCoordinate2D?)
}

class GPXManager {
  
  // much needed enums for saving states
  private enum State {
    case idle
    case running
    case paused
  }
  
  private var state: State = .idle
  
  // props
  weak var delegate: GPXManagerDelegate?
  
  private let file = GPXFile()
  private var timer: Timer?
  
  private var generatedLocations = [CLLocationCoordinate2D]()
  
  private var currentLocation: CLLocationCoordinate2D?
  private var startLocation: CLLocationCoordinate2D? {
    return generatedLocations.first!
  }
  private var endLocation: CLLocationCoordinate2D? {
    return generatedLocations.last!
  }
  
  func run(locations: [CLLocationCoordinate2D]){
    generatedLocations = generate(locations: locations)
    currentLocation = generatedLocations.first
    
    state = .running
    file.write(generatedLocations)
    apply()
    startTimer()
  }
  
  func pause(){
    if let currentLocation = currentLocation {
      state = .paused
      file.write([currentLocation])
      apply()
    } else {
      print("couldn't pause. no current location")
    }
  }
  
  func resume(){
    if let currentLocation = currentLocation {
      state = .running
      let resumeLocations = generate(locations: generatedLocations, from: currentLocation)
      file.write(resumeLocations)
      apply()
      startTimer()
    } else {
      print("couldn't resume. no current location")
    }
  }
  
  func stop(){
    state = .idle
    generatedLocations.removeAll()
    file.write(generatedLocations)
    apply()
  }
  
  private func generate(locations: [CLLocationCoordinate2D], from: CLLocationCoordinate2D? = nil) -> [CLLocationCoordinate2D] {
    var fixedLocations = [CLLocationCoordinate2D]()
    
    var startingIndex = 0
    
    if let from = from, let index = (locations.index { $0 == from })
      where index < locations.count {
      startingIndex = index
    }

    for index in startingIndex...locations.count-1 {
      let nextIndex = index+1
      if nextIndex < locations.count {
        let start = locations[index]
        let end = locations[nextIndex]
        let distance = CLLocation(coordinate: end).distance(from: CLLocation(coordinate: start))
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
    
    return fixedLocations
  }
  

  private func startTimer() {
    if timer == nil {
      timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(updateCurrentLocation), userInfo: nil, repeats: true)
    }
    timer?.fire()
  }
  
  private func stopTimer(){
    currentIndex = 0
    timer?.invalidate()
    timer = nil
  }
  
  // updates current location reference to keep track of where the user currently is
  private var currentIndex = 0
  @objc private func updateCurrentLocation(){
    if state == .running {
      
      if generatedLocations.count > currentIndex + 1 {
        currentIndex += 1
        currentLocation = generatedLocations[currentIndex]
        delegate?.gpxManager(manager: self, didUpdateCurrentLocation: currentLocation)
      } else {
        delegate?.gpxManager(manager: self, didCompleteRouteAtLocation: currentLocation)
        stopTimer()
      }
    } else {
      stopTimer()
    }
  }
  
  // runs script that selected menu in xcode Debug/Simulate location/track.gpx
  // which refreshes the track on device
  private func apply(){
    NSWorkspace.shared().launchApplication("RunGPX")
  }
}

// CLLocation and CLLocationCoordinate2D helpers
extension CLLocation {
  convenience init(coordinate: CLLocationCoordinate2D) {
    self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
  return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}
