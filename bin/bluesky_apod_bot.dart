import 'dart:io';
import 'dart:typed_data';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky_text/bluesky_text.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:nasa/nasa.dart';

const _apodOfficialUrl = 'https://apod.nasa.gov';

void main(List<String> args) async {
  final bluesky = bsky.Bluesky.fromSession(
    await _session,
    retryConfig: bsky.RetryConfig(
      maxAttempts: 10,
    ),
  );

  final head = await bluesky.feeds.findFeed(
    actor: Platform.environment['BLUESKY_IDENTIFIER']!,
    limit: 50,
  );

  final headPost = head.data.feed.first.post;

  if (headPost.isNotReposted) {
    final headParent = head.data.feed
        .where((element) => element.reply == null && element.reason == null)
        .first
        .post;

    await bluesky.feeds.createRepost(
      cid: headParent.cid,
      uri: headParent.uri,
    );

    return;
  }

  final nasa = NasaApi(
    token: Platform.environment['NASA_API_TOKEN']!,
  );

  final apod = (await nasa.apod.lookupImage()).data;

  final imageBlob = await http.get(Uri.parse(apod.url));
  final blobData = await _getBlobData(bluesky, imageBlob.bodyBytes);

  final headerText = BlueskyText(_getHeaderText(apod));
  final links = headerText.links;

  final record = await bluesky.feeds.createPost(
    text: headerText.value,
    facets: (await links.toFacets()).map(bsky.Facet.fromJson).toList(),
    embed: blobData.blob.toEmbedImage(
      alt: apod.description,
    ),
  );

  final chunks = _splitTextIntoChunks(
    apod.description,
    300,
  );

  var parentRecord = record;
  for (final chunk in chunks) {
    parentRecord = await bluesky.feeds.createPost(
      text: chunk,
      reply: bsky.ReplyRef(
        root: record.data,
        parent: parentRecord.data,
      ),
    );
  }
}

Future<bsky.Session> get _session async {
  final session = await bsky.createSession(
    identifier: Platform.environment['BLUESKY_IDENTIFIER']!,
    password: Platform.environment['BLUESKY_PASSWORD']!,
  );

  return session.data;
}

String _getTitle(final APODData apod) {
  if (apod.copyright == null) {
    return apod.title;
  }

  return '${apod.title} - ©${apod.copyright}';
}

String _getOfficialUrl(final DateTime createdAt) {
  final formattedDate = '${createdAt.year.toString().substring(2)}'
      '${createdAt.month.toString().padLeft(2, '0')}'
      '${createdAt.day.toString().padLeft(2, '0')}';

  return '$_apodOfficialUrl/apod/ap$formattedDate.html';
}

String _getHeaderText(final APODData apod) {
  final title = _getTitle(apod);
  final officialUrl = _getOfficialUrl(apod.createdAt);

  if (apod.hdUrl == null) {
    return '''$title

Official: $officialUrl

Please enjoy following threads too! 🔭''';
  }

  return '''$title

Official: $officialUrl
HD: ${apod.hdUrl}

Please enjoy following threads too! 🔭''';
}

List<String> _splitTextIntoChunks(String text, int maxChunkSize) {
  final chunks = <String>[];
  final words = text.split(' ');
  String chunk = '';

  for (int i = 0; i < words.length; i++) {
    if ((chunk.length + words[i].length + 1) <= maxChunkSize) {
      if (chunk.isNotEmpty) {
        chunk += ' ';
      }
      chunk += words[i];
    } else {
      chunks.add(chunk);
      chunk = words[i];
    }
  }

  if (chunk.isNotEmpty) {
    chunks.add(chunk);
  }

  return chunks;
}

Future<bsky.BlobData> _getBlobData(
  final bsky.Bluesky bluesky,
  final Uint8List image,
) async {
  final response = await bluesky.repositories.uploadBlob(
    _compressImage(image),
  );

  return response.data;
}

Uint8List _compressImage(Uint8List fileBytes) {
  int quality = 100;

  while (fileBytes.length > 976.56 * 1024) {
    final decodedImage = decodeImage(fileBytes);
    final encodedImage = encodeJpg(decodedImage!, quality: quality);

    final compressedSize = encodedImage.length;

    if (compressedSize < 976.56 * 1024) {
      quality += 10;
    } else {
      quality -= 10;
    }

    fileBytes = encodedImage;
  }

  return fileBytes;
}
