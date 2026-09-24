import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Notifications, alarms and the home-screen widget exist only on Android/iOS.
/// On other targets (e.g. running the app in a browser) those features are skipped.
final bool supportsDeviceFeatures = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
