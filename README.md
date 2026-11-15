# Camera

A tiny macOS app that does one thing: open it from Spotlight, see yourself,
take a photo or switch cameras, and close it. Like Raycast's "Show Camera",
as a standalone app.

## Install

Requires macOS 14+ and the Xcode command line tools.

```sh
make install
```

This builds `Camera.app`, copies it to `~/Applications` (override with
`INSTALL_DIR=/Applications make install`) and registers it with Spotlight.
Press ⌘Space, type "camera", hit Return. The first launch asks for camera
access.

The app is ad-hoc signed, so macOS asks for camera access again after each
reinstall. Set `SIGN_IDENTITY="Apple Development: …"` to sign with your own
certificate and keep the permission between builds.

## Use

| Action | How |
| --- | --- |
| Take a photo | Space, Return, or the shutter button |
| Switch to the next camera | Tab, or click the switch button |
| Pick a camera | Hold the switch button, the Camera menu, or ⌘1–⌘9 |
| See your last photo | Click the thumbnail (reveals it in Finder) |
| Close | Esc or ⌘W (quits the app and turns the camera off) |

Photos are saved as full-resolution JPEGs to `~/Pictures/Camera`. They are
tagged to display mirrored, matching the preview (the pixels aren't
re-encoded; apps that strip EXIF orientation will show them unmirrored). Built-in, external, iPhone (Continuity Camera) and Desk
View cameras are supported; the app reopens whichever camera you used last.
The camera turns off while the app is hidden (⌘H).

## Develop

```sh
make test   # unit tests for CameraCore
make run    # build build/Camera.app and open it
make clean
```

- `Sources/CameraCore` — hardware-free logic (camera ordering and cycling,
  photo file names, EXIF mirroring, thumbnails), covered by
  `Tests/CameraCoreTests`.
- `Sources/Camera` — the SwiftUI app: `CaptureEngine` owns the
  `AVCaptureSession` on its own queue, `CameraController` is the window's
  model, `ContentView` is the UI.
- `scripts/build-app.sh` assembles and signs the `.app` bundle;
  `scripts/make-icon.swift` draws the icon.
