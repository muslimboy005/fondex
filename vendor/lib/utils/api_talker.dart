import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Single Talker instance for API logs.
///
/// - Debug: verbose logs enabled
/// - Release: logs disabled by default
final Talker apiTalker = Talker(
  settings: TalkerSettings(
    enabled: kDebugMode,
    useConsoleLogs: kDebugMode,
  ),
);

