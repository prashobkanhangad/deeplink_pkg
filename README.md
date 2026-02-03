# deeplink_sdk

A complete SDK for **deferred deep linking**, **attribution**, and **smart routing** in Flutter.

## Features

- **Attribution** — Track app installs and where they came from (Android Install Referrer, iOS device model for IP-based match).
- **Deep linking** — Listen for incoming App Links, Universal Links, and custom URL schemes.
- **Smart routing** — Open native URLs when available, with a web fallback.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  deeplink_sdk: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

### 1. Initialize (attribution)

Call `init()` early in your app (e.g. in `main` after `WidgetsFlutterBinding.ensureInitialized()`). On first run, the SDK records install attribution and sends it to your backend.

```dart
import 'package:deeplink_sdk/deeplink_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deeplink = Deeplink();

  // Optional: set backend base URL (default is http://localhost:3000)
  // deeplink.installTrackBaseUrl = 'https://link.invyto.in';

  await deeplink.init();

  runApp(const MyApp());
}
```

### 2. Incoming links

Subscribe to `uriStream` to handle deep links while the app is running.

```dart
final deeplink = Deeplink();

deeplink.uriStream.listen((Uri uri) {
  // Handle the incoming link (e.g. navigate, show content)
  print('Received: $uri');
});
```

### 3. Smart routing (outgoing links)

Use `openSmartLink` to try a native URL first and fall back to a web URL.

```dart
final deeplink = Deeplink();

final launched = await deeplink.openSmartLink(
  'myapp://path/to/content',   // native URL
  'https://example.com/path',   // web fallback
);

if (launched) {
  // Link was opened (native app or browser)
}
```

## Example

See the [example](example/) app for a full testbed that demonstrates all three features.

## License

MIT — see [LICENSE](LICENSE) for details.
# deeplink_pkg
