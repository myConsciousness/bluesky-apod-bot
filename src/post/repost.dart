import 'dart:io' show Platform;

import 'package:bluesky/app_bsky_feed_defs.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/com_atproto_repo_strong_ref.dart';
import 'package:bluesky/core.dart' hide Platform;
import 'package:bluesky/ids.dart';

import 'session.dart';

Future<void> repost({required String rkey}) async {
  final bluesky = bsky.Bluesky.fromSession(await session);

  final did = await bluesky.identity.resolveHandle(
    handle: Platform.environment['BLUESKY_IDENTIFIER']!,
  );

  final posts = await bluesky.feed.getPosts(uris: [
    AtUri.make(did.data.did, appBskyFeedPost, rkey),
  ]);

  final post = posts.data.posts.first;

  if (post.viewer.hasRepost) {
    await bluesky.feed.repost.delete(rkey: post.viewer.repost!.rkey);
  }

  await bluesky.feed.repost.create(
    subject: StrongRef(cid: post.cid, uri: post.uri),
  );
}
