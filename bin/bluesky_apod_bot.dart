import 'dart:io';
import 'dart:typed_data';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/cardyb.dart' as cardyb;
import 'package:bluesky_text/bluesky_text.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:nasa/nasa.dart';

const _apodOfficialUrl = 'https://apod.nasa.gov';
const _tags = ['nasa', 'apod', 'astronomy', 'astrophotos', '🔭'];

const _videoUrl = 'https://www.youtube.com/watch?v=';

const _markdownAboutAPOD =
    '[ℹ️About NASA Astronomy Picture Of the Day](https://apod.nasa.gov/apod/lib/about_apod.html)';

void main(List<String> args) async {
  final bluesky = bsky.Bluesky.fromSession(
    await _session,
    retryConfig: bsky.RetryConfig(
      maxAttempts: 10,
    ),
  );

  final head = await bluesky.feed.getAuthorFeed(
    actor: Platform.environment['BLUESKY_IDENTIFIER']!,
    limit: 50,
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

  final nasa = NasaApi(
    token: Platform.environment['NASA_API_TOKEN']!,
  );

  final apod = (await nasa.apod.lookupImage()).data;

  bsky.BlobData? blobData;
  if (apod.mediaType == 'image') {
    final imageBlob = await http.get(Uri.parse(apod.url));
    blobData = await _getBlobData(bluesky, imageBlob.bodyBytes);
  }

  final headerText = BlueskyText(
    _getHeaderText(apod),
    linkConfig: const LinkConfig(
      excludeProtocol: true,
      enableShortening: true,
    ),
  ).format();

  final entities = headerText.entities;

  final record = await bluesky.feed.post(
    text: headerText.value,
    facets: (await entities.toFacets()).map(bsky.Facet.fromJson).toList(),
    embed: blobData?.blob.toEmbedImage(
          alt: apod.description,
        ) ??
        await _getEmbedExternal(apod.url, bluesky),
    tags: _tags,
  );

  final chunks = BlueskyText(apod.description).split();

  var parentRecord = record;
  for (final chunk in chunks) {
    parentRecord = await bluesky.feed.post(
      text: chunk.value,
      reply: bsky.ReplyRef(
        root: record.data,
        parent: parentRecord.data,
      ),
      tags: _tags,
    );
  }
}

Future<bsky.Embed?> _getEmbedExternal(
  final String url,
  final bsky.Bluesky bluesky,
) async {
  try {
    final videoId = url.split('/').last.split('?').first;
    final preview = await cardyb.findLinkPreview(
      Uri.parse(_videoUrl + videoId),
    );

    final imageBlob = await http.get(Uri.parse(preview.data.image));
    final uploaded = await bluesky.repo.uploadBlob(imageBlob.bodyBytes);

    return bsky.Embed.external(
      data: bsky.EmbedExternal(
        external: bsky.EmbedExternalThumbnail(
          uri: preview.data.url,
          title: preview.data.title,
          description: preview.data.description,
          blob: uploaded.data.blob,
        ),
      ),
    );
  } catch (_) {
    return null;
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

  final tags = _tags.map((e) => '#$e').join(' ');

  if (apod.mediaType == 'video') {
    return '''$title

- [📹Video]($officialUrl)
- [📺YouTube](${apod.url})
- $_markdownAboutAPOD

$tags

Maintained by @shinyakato.dev

🧵 READ MORE 🧵''';
  }

  if (apod.hdUrl == null) {
    return '''$title

- [📷Photo]($officialUrl)
- $_markdownAboutAPOD

$tags

Maintained by @shinyakato.dev

🧵 READ MORE 🧵''';
  }

  return '''$title

- [📷Photo]($officialUrl)
- [📸HD Photo](${apod.hdUrl})
- $_markdownAboutAPOD

$tags

Maintained by @shinyakato.dev

🧵 READ MORE 🧵''';
}

Future<bsky.BlobData> _getBlobData(
  final bsky.Bluesky bluesky,
  final Uint8List image,
) async {
  final response = await bluesky.repo.uploadBlob(
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
