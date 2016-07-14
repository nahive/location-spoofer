//
//  GPXFile.swift
//  location-spoofer
//
//  Created by Szymon Maślanka on 13/07/2016.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import Foundation
import MapKit

class GPXFile {
  
  let filePath = "track.gpx"
  
  var exists: Bool {
    return NSFileManager().fileExistsAtPath(filePath)
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
  
  func write(locations: [CLLocationCoordinate2D]) -> Bool {
    var gpxStructure = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx>\n"
    for (index,location) in locations.enumerate() {
      let date = stringFromDate(NSDate().dateByAddingTimeInterval(Double(index)))
      gpxStructure += "\t<wpt lat=\"\(location.latitude)\" lon=\"\(location.longitude)\">\n<time>\(date)</time>\n</wpt>\n"
    }
    gpxStructure += "</gpx>"
    
    do {
      try gpxStructure.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding)
      print("file was written")
      return true
    } catch {
      print("couldn't write to file 😐")
      return false
    }
  }
  
  private func read() -> String? {
    if exists {
      return try? String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding)
    }
    return nil
  }
  
  private func stringFromDate(date: NSDate) -> String {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let timeFormatter = NSDateFormatter()
    timeFormatter.dateFormat = "HH:mm:ss"
    let dateString = dateFormatter.stringFromDate(date)
    let timeString = timeFormatter.stringFromDate(date)
    return dateString+"T"+timeString+"Z"
  }
}