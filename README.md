<p align="center"><img src="https://github.com/nahive/location-spoofer/blob/master/preview.png" alt="Location spoofer">
</p>

# Location Spoofer
##### *Spoof moving location on iOS device*

## Features

- [x] Simulating moving location
- [x] Pause&resume
- [x] Change end location while running
- [x] Stopping to return to starting location
- [x] Using both straight line and stick to roads
- [ ] Settings for walking/driving/bike speed

[Changelog](https://github.com/nahive/location-spoofer/blob/master/CHANGELOG.md)

## Building

```
$ git clone https://github.com/nahive/location-spoofer.git
$ open location-spoofer.xcodeproj
```

##Using

1. Download
2. Open ```location-spoofer``` app.
3. Open test project in Xcode. 
4. Drag the created track.gpx into project and *uncheck* copy files if needed.
5. Run test project on the device or simulator.
6. Select start and end location.
7. Click run.
7a. If dialog appears that says that script cannot run - in xcode of test project go to menu Debug/Simulate location/track.gpx
8. Profit

## Contributing

If you found a **bug**, open an issue.

If you have a **feature** request, open an issue.

If you want to **contribute**, submit a pull request.

## License

The source code is dedicated to the public domain. See the `LICENCE.md` file for
more information.