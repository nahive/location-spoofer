//
//  MapViewController.swift
//  location-spoofer
//
//  Created by Szymon Maslanka on 13/07/16.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import Cocoa
import MapKit

let knownLocations = ["smt" : CLLocation(latitude:  51.102411, longitude: 17.032319)]

protocol MapViewControllerDelegate: class {
  func mapViewController(controller: MapViewController, mapView: MKMapView, didClickAtLocation location: CLLocationCoordinate2D)
}

class MapViewController: NSViewController {
  
  weak var delegate: MapViewControllerDelegate?
  
  @IBOutlet weak var mapView: MKMapView!
  
  var startAnnotation: Annotation?
  var currentAnnotation: Annotation?
  var endAnnotation: Annotation?
  var routePolyline: MKPolyline?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupMapView()
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
  
  func mouseClick(_ recognizer: NSClickGestureRecognizer){
    let point = recognizer.location(in: mapView)
    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
    delegate?.mapViewController(controller: self, mapView: mapView, didClickAtLocation: coordinate)
  }
  
  func drawStartAnnotation(location: CLLocationCoordinate2D){
    if startAnnotation == nil {
      startAnnotation = Annotation(title: "Starting location", coordinate: CLLocationCoordinate2D())
      mapView.addAnnotation(startAnnotation!)
    }
    startAnnotation?.coordinate = location
    mapView.removeOverlays(mapView.overlays)
  }
  
  func drawCurrentLocation(location: CLLocationCoordinate2D){
    if currentAnnotation == nil {
      currentAnnotation = Annotation(title: "Current location", coordinate: CLLocationCoordinate2D())
      mapView.addAnnotation(self.currentAnnotation!)
    }
    currentAnnotation?.coordinate = location
  }
  
  func drawEndLocation(location: CLLocationCoordinate2D){
    if endAnnotation == nil {
      endAnnotation = Annotation(title: "End location", coordinate: CLLocationCoordinate2D())
      mapView.addAnnotation(endAnnotation!)
    }
    endAnnotation?.coordinate = location
    mapView.removeOverlays(mapView.overlays)
  }
  
  func drawRoute(locations: [CLLocationCoordinate2D]?) {
    guard var locations = locations else {
      return print("can't draw nil route 🤔")
    }
    
    if let routePolyline = routePolyline {
      mapView.remove(routePolyline)
    }
    
    routePolyline = MKPolyline(coordinates: &locations, count: locations.count)
    mapView.add((routePolyline!), level: MKOverlayLevel.aboveRoads)
  }
  
  func clearMap(){
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
extension MapViewController: MKMapViewDelegate {
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

