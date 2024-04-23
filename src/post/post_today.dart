import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;

import 'post.dart';
import 'session.dart';

Future<void> postToday() async {
  final bluesky = bsky.Bluesky.fromSession(
    await session,
    retryConfig: bsky.RetryConfig(
      maxAttempts: 10,
    ),
  );

  final head = await bluesky.feed.getAuthorFeed(
    actor: Platform.environment['BLUESKY_IDENTIFIER']!,
    limit: 15,
  );

  final headPost = head.data.feed.first.post;

  if (headPost.isNotReposted) {
    final headParent = head.data.feed
        .where((element) => element.reply == null && element.reason == null)
        .first
        .post;

    await bluesky.feed.repost(
      cid: headParent.cid,
      uri: headParent.uri,
    );

    return;
  }

  await post();
}
