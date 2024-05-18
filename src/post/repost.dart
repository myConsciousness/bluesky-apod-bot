import 'dart:io' show Platform;

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/ids.dart';

import 'session.dart';

Future<void> repost({required String rkey}) async {
  final bluesky = bsky.Bluesky.fromSession(await session);

  final did = await bluesky.identity.resolveHandle(
    handle: Platform.environment['BLUESKY_IDENTIFIER']!,
  );

  final posts = await bluesky.feed.getPosts(uris: [
    bsky.AtUri.make(did.data.did, appBskyFeedPost, rkey),
  ]);

  final post = posts.data.posts.first;

  if (post.isReposted) {
    await bluesky.repo.deleteRecord(uri: post.viewer.repost!);
  }

  await bluesky.feed.repost(cid: post.cid, uri: post.uri);
}
