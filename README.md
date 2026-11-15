# Camera

A tiny macOS app that does one thing: open it from Spotlight, see yourself,
take a photo or switch cameras, and close it. Like Raycast's "Show Camera",
as a standalone app.

<p>
  <img src="docs/camera.png" width="49%" alt="The Camera window: a cartoon orc waving close up on the built-in camera, with a photo thumbnail, shutter button and switch-camera button along the bottom">
  <img src="docs/switching.png" width="49%" alt="The same orc from further back after switching to the display camera, with the new camera's name shown at the top">
</p>

## Download

Requires macOS 14+. Grab `Camera-<version>.zip` from the
[latest release](https://github.com/Rixcy/camera/releases/latest), unzip it and
drag `Camera.app` into Applications. Then press ⌘Space, type "camera" and hit
Return.

If a release isn't notarized, macOS blocks the first launch. Allow it once in
System Settings → Privacy & Security → Open Anyway, or run
`xattr -dr com.apple.quarantine /Applications/Camera.app`.

## Build from source

Requires macOS 14+ and the Xcode command line tools.

```sh
make install
```

Then open it from Spotlight the same way. It installs to
`~/Applications` (change with `INSTALL_DIR`). Set `SIGN_IDENTITY` to your
signing certificate to keep camera access between reinstalls.

## Use

| Action | How |
| --- | --- |
| Take a photo | Space, Return, or the shutter button |
| Switch to the next camera | Tab, or click the switch button |
| Pick a camera | Hold the switch button, the Camera menu, or ⌘1–⌘9 |
| See your last photo | Click the thumbnail (reveals it in Finder) |
| Close | Esc or ⌘W |

Photos are saved to `~/Pictures/Camera`. Built-in, external, iPhone and Desk
View cameras all work, and the app reopens the one you used last. The camera
turns off when you close or hide the app.

## Develop

```sh
make test         # unit tests
make run          # build and open build/Camera.app
make screenshots  # retake the images above
make package      # build/Camera-<version>.zip, a universal app as released
```

Pushing a `v*` tag (for example `git tag v1.1.0 && git push origin v1.1.0`)
runs `.github/workflows/release.yml`, which tests, packages and publishes that
zip as a GitHub release. Add the secrets listed at the top of the workflow to
sign and notarize it with a Developer ID certificate.

## License

MIT — see [LICENSE](LICENSE).
