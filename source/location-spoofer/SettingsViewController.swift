//
//  SettingsViewController.swift
//  location-spoofer
//
//  Created by Szymon Maślanka on 15/07/2016.
//  Copyright © 2016 Szymon Maslanka. All rights reserved.
//

import Cocoa

enum TrackingSpeed: Double {
  case walking = 2.0
  case cycling = 6.0
  case driving = 15.0
  
  static func fromSegment(segment: Int) -> TrackingSpeed {
    switch segment {
    case 0:
      return .walking
    case 1:
      return .cycling
    case 2:
      return .driving
    default:
      return .walking
    }
  }
}

protocol SettingsViewControllerDelegate: class {
  func settingsViewController(controller: SettingsViewController, stickToRoadsEnabled enabled: Bool)
  func settingsViewController(controller: SettingsViewController, trackingSpeedChanged speed: TrackingSpeed)
}

class SettingsViewController: NSViewController, NSPopoverDelegate {
  
  weak var delegate: SettingsViewControllerDelegate?
  
  @IBOutlet weak var stickToRoadsButton: NSButtonCell!
  @IBOutlet weak var speedSegmentedControl: NSSegmentedControl!
  
  private let popover = NSPopover()
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    setup()
  }
  
  private func setup(){
    popover.contentViewController = self
  }
  
  func show(sender: NSView) {
    popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.maxY)
  }
  
  func hide(sender: NSView){
    popover.performClose(sender)
  }
  
  func toggle(sender: NSView) {
    popover.isShown ? hide(sender: sender) : show(sender: sender)
  }
  
  @IBAction func stickToRoadButtonClicked(sender: NSButton) {
    delegate?.settingsViewController(controller: self, stickToRoadsEnabled: sender.state == NSOnState)
  }
  
  @IBAction func trackingSpeedSegmentedControlClicked(_ sender: NSSegmentedControl) {
    delegate?.settingsViewController(controller: self, trackingSpeedChanged: TrackingSpeed.fromSegment(segment: sender.selectedSegment))
  }
  
}
