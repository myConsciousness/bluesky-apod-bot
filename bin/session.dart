import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;

Future<bsky.Session> get session async {
  final session = await bsky.createSession(
    identifier: Platform.environment['BLUESKY_IDENTIFIER']!,
    password: Platform.environment['BLUESKY_PASSWORD']!,
  );

  return session.data;
}
