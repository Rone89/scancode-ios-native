# ScanCode

ScanCode is a native iOS 26 QR scanner app built with UIKit and AVFoundation.

## Features

- Native QR scanning with `AVCaptureSession` and `AVCaptureMetadataOutput`.
- Camera preview through `AVCaptureVideoPreviewLayer`.
- Scanner-only interface with the camera preview as the primary surface.
- QR success border using `transformedMetadataObject(for:)`.
- Medium haptic feedback on successful recognition.
- Pinch zoom by updating `AVCaptureDevice.videoZoomFactor`.
- Lower thermal load through a full-screen scan region, lower-cost session preset, throttled duplicate handling, automatic stop on success/background, and camera frame-rate limiting.
- Routing for WeChat QR codes, Alipay QR codes, and generic or aggregate QR codes with a minimal WeChat / Alipay chooser.
- Edge-only Matrix-style digital rain overlay in the main app.

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

The app keeps its `scancode` URL scheme for direct scanner entry points:

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

## QR Routing

- WeChat-related QR codes open WeChat Scan directly without confirmation.
- Alipay-related QR codes are percent-encoded and passed to `alipayqr://platformapi/startapp?saId=10000007&qrcode=`.
- Generic or aggregate QR codes show only a system action sheet with WeChat, Alipay, and Cancel.

## CI Release

GitHub Actions builds an unsigned iOS IPA on every push to `main` using the macOS 26 runner and Xcode 26 toolchain, then uploads it to a GitHub release with version notes.

Unsigned CI IPAs are useful as build artifacts. To install on physical devices outside Xcode, add Apple Developer signing assets and provisioning configuration.
