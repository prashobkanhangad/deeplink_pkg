// deeplink_sdk - All-in-One attribution, deep linking, and smart routing.

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';

/// All-in-One SDK for attribution, deep linking, and smart routing.
///
/// Use [Deeplink()] to get the singleton instance, then call [init]
/// early in app startup. Listen to [uriStream] for incoming links and use
/// [openSmartLink] for outgoing links with web fallback.
class Deeplink {
  Deeplink._();

  static final Deeplink _instance = Deeplink._();

  /// Singleton accessor. Use [Deeplink()] to get the single instance.
  factory Deeplink() => _instance;

  static const String _firstRunKey = 'deeplink_first_run';
  static const String _defaultInstallTrackPath = '/api/v1/track/install';

  /// Base URL for the install track API (e.g. `http://localhost:3000` or `https://link.invyto.in`).
  /// Request is sent to [installTrackBaseUrl] + `/api/v1/track/install`.
  String installTrackBaseUrl = 'http://localhost:3000';

  String get _installTrackUrl => '$installTrackBaseUrl$_defaultInstallTrackPath';

  AppLinks? _appLinks;

  AppLinks get _links {
    _appLinks ??= AppLinks();
    return _appLinks!;
  }

  /// One-time async initialization. Call early (e.g. in [WidgetsFlutterBinding.ensureInitialized] or main).
  ///
  /// On first run, sets [deeplink_first_run] to false in SharedPreferences and
  /// performs install attribution via [_trackInstall]. On subsequent runs returns null.
  ///
  /// Returns the parsed JSON response from the install track API on first run success, otherwise null.
  Future<Map<String, dynamic>?> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstRun = prefs.getBool(_firstRunKey) ?? true;
      if (!isFirstRun) return null;

      await prefs.setBool(_firstRunKey, false);
      return await _trackInstall();
    } catch (_) {
      return null;
    }
  }

  /// Collects platform-specific attribution data and POSTs to the install track API.
  ///
  /// Request body matches backend API:
  /// - **Android (with referrer):** `{ "platform": "android", "referrer": "utm_source=..." }`
  /// - **Android (organic):** `{ "platform": "android" }`
  /// - **iOS (model for IP-based match):** `{ "platform": "ios", "model": "iPhone14,2" }`
  /// - **iOS (organic):** `{ "platform": "ios" }`
  ///
  /// Returns the API response body as [Map<String, dynamic>] on success, null on failure.
  Future<Map<String, dynamic>?> _trackInstall() async {
    String platform;
    final Map<String, dynamic> payload = {};

    try {
      if (Platform.isAndroid) {
        platform = 'android';
        try {
          final referrerDetails = await AndroidPlayInstallReferrer.installReferrer;
          final referrer = referrerDetails.installReferrer;
          if (referrer != null && referrer.isNotEmpty) {
            payload['referrer'] = referrer;
          }
        } catch (_) {
          // Install referrer unavailable (e.g. sideload, old Play)
        }
      } else if (Platform.isIOS) {
        platform = 'ios';
        try {
          final deviceInfo = DeviceInfoPlugin();
          final iosInfo = await deviceInfo.iosInfo;
          final machine = iosInfo.utsname.machine;
          if (machine.isNotEmpty) {
            payload['model'] = machine;
          }
        } catch (_) {
          // Device info unavailable
        }
      } else {
        return null;
      }

      payload['platform'] = platform;

      final response = await http
          .post(
            Uri.parse(_installTrackUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'raw': decoded};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Stream of incoming link [Uri]s (App Links / Universal Links / custom schemes).
  ///
  /// Proxies [AppLinks.uriLinkStream]. Subscribe to handle deep links while the app is running.
  Stream<Uri> get uriStream => _links.uriLinkStream;

  /// Tries to open [nativeUrl] in an external app; if it cannot be launched, opens [webUrl] in external mode.
  ///
  /// Both URLs are launched with [LaunchMode.externalApplication].
  /// Returns true if any URL was launched, false otherwise.
  Future<bool> openSmartLink(String nativeUrl, String webUrl) async {
    final nativeUri = Uri.tryParse(nativeUrl);
    final webUri = Uri.tryParse(webUrl);

    if (nativeUri == null && webUri == null) return false;
    if (nativeUri != null && await canLaunchUrl(nativeUri)) {
      return launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    }
    if (webUri != null) {
      return launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
