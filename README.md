# ScanCode

ScanCode is a native iOS 26 QR scanner app built with UIKit, WidgetKit, and AVFoundation.

## Features

- Native QR scanning with `AVCaptureSession` and `AVCaptureMetadataOutput`.
- Camera preview through `AVCaptureVideoPreviewLayer`.
- iOS 26 Liquid Glass style using native UIKit and SwiftUI system components.
- QR success border using `transformedMetadataObject(for:)`.
- Medium haptic feedback on successful recognition.
- Pinch zoom by updating `AVCaptureDevice.videoZoomFactor`.
- Lower thermal load through a narrower scan region, lower session preset, throttled duplicate handling, and camera frame-rate limiting.
- Routing for WeChat, Alipay, and generic aggregate payment QR codes.
- Generic QR path can open WeChat Scan directly without an extra confirmation step after the user chooses WeChat.
- Home screen, Lock Screen, and Dynamic Island surfaces for scanner, WeChat scan, and Alipay scan entry points.
- Generated app icon set included in `Assets.xcassets`.

## Permissions

The app includes the required camera permission description:

```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机扫描二维码。</string>
```

It also includes URL scheme query allowlist entries for WeChat and Alipay:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>weixin</string>
    <string>wxp</string>
    <string>wechat</string>
    <string>alipay</string>
    <string>alipayqr</string>
    <string>alipays</string>
</array>
```

And the app registers its own deep link scheme for widgets:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>scancode</string>
        </array>
    </dict>
</array>
```

## Widgets

The widget extension supports:

- `systemSmall`
- `systemMedium`
- `systemLarge`
- `accessoryInline`
- `accessoryCircular`
- `accessoryRectangular`

Each widget can deep-link into one of the app actions:

- `scancode://startscan`
- `scancode://wechat-scanner`
- `scancode://alipay-scanner`

## CI Release

GitHub Actions builds an unsigned iOS IPA on every push to `main` using the macOS 26 runner and Xcode 26 toolchain, then uploads it to a GitHub release with version notes.

Unsigned CI IPAs are useful as build artifacts. To install on physical devices outside Xcode, add Apple Developer signing assets and provisioning configuration.
