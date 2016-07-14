//
//  GPXFile.swift
//  location-spoofer
//
//  Created by Szymon Maślanka on 13/07/2016.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import MapKit

class GPXFile {
  
  // time offset in seconds for first location so manager can play catchup
  let timeOffset = 5.0
  let filePath = "track.gpx"
  var locations = [CLLocationCoordinate2D]()
  
  var exists: Bool {
    return FileManager().fileExists(atPath: filePath)
  }
  
  init(){
    if !exists {
      print("file did not exist. creating gpx file at \(filePath)")
      if write([CLLocationCoordinate2D]()) {
        print("gpx file created")
      } else {
        print("couldn't create file 😐")
      }
    }
  }
  
  func write(_ locations: [CLLocationCoordinate2D]) -> Bool {
    let gpxStart = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx>\n"
    var gpxMiddle = ""
    for (index,location) in locations.enumerated() {
      let date = stringFromDate(Date().addingTimeInterval(timeOffset + Double(index)))
      gpxMiddle += "\t<wpt lat=\"\(location.latitude)\" lon=\"\(location.longitude)\">\n<time>\(date)</time>\n</wpt>\n"
    }
    let gpxEnd = "</gpx>"
    let gpxFull = gpxStart + gpxMiddle + gpxEnd
    
    do {
      try gpxFull.write(toFile: filePath, atomically: true, encoding: String.Encoding.utf8)
      self.locations = locations
      print("file was written")
      return true
    } catch {
      print("couldn't write to file 😐")
      return false
    }
  }
  
  private func read() -> String? {
    if exists {
      return try? String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
    }
    return nil
  }
  
  private func stringFromDate(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm:ss"
    let dateString = dateFormatter.string(from: date)
    let timeString = timeFormatter.string(from: date)
    return dateString+"T"+timeString+"Z"
  }
}
