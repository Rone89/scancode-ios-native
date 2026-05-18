# ScanCode

ScanCode is a minimal native iOS QR scanner built with UIKit and AVFoundation.

## Features

- Native QR scanning with `AVCaptureSession` and `AVCaptureMetadataOutput`.
- Camera preview through `AVCaptureVideoPreviewLayer`.
- QR success border using `transformedMetadataObject(for:)`.
- Medium haptic feedback on successful recognition.
- Pinch zoom by updating `AVCaptureDevice.videoZoomFactor`.
- Routing for WeChat, Alipay, and generic aggregate payment QR codes.

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
    <string>alipayqr</string>
    <string>alipays</string>
</array>
```

## CI Release

GitHub Actions builds an unsigned iOS IPA on every push to `main` and uploads it to a GitHub release with version notes.

Unsigned CI IPAs are useful as build artifacts. To install on physical devices outside Xcode, add Apple Developer signing assets and provisioning configuration.
