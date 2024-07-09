import 'dart:io';

import 'package:bluesky/atproto.dart';
import 'package:bluesky/com_atproto_server_create_session.dart';
import 'package:bluesky/core.dart';

Future<Session> get session async {
  final session = await createSession(
    identifier: Platform.environment['BLUESKY_IDENTIFIER']!,
    password: Platform.environment['BLUESKY_PASSWORD']!,
  );

  return session.data.toSession();
}
