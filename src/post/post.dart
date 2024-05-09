import 'dart:io';
import 'dart:typed_data';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/cardyb.dart' as cardyb;
import 'package:bluesky_text/bluesky_text.dart';

import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:nasa/nasa.dart';

import 'session.dart';

const _apodOfficialUrl = 'https://apod.nasa.gov';
const _tags = ['apod', 'science', 'astronomy', 'astrophotos', '🔭'];

const _videoUrl = 'https://www.youtube.com/watch?v=';

const _markdownAboutAPOD =
    '[About Astronomy Picture Of the Day](https://apod.nasa.gov/apod/lib/about_apod.html)';

Future<bsky.AtUri> post([DateTime? date]) async {
  final bluesky = bsky.Bluesky.fromSession(await session);

  final nasa = NasaApi(
    token: Platform.environment['NASA_API_TOKEN']!,
    timeout: const Duration(seconds: 30),
  );

  final apod = (await nasa.apod.lookupImage(date: date)).data;

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

  return record.data.uri;
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

  if (apod.mediaType == 'video') {
    return '''$title

- [Video]($officialUrl)
- [YouTube](${apod.url})
- $_markdownAboutAPOD

#astrophotos

Maintained by @shinyakato.dev

🔭 READ MORE 🔭''';
  }

  if (apod.hdUrl == null) {
    return '''$title

- [Pic]($officialUrl)
- $_markdownAboutAPOD

#astrophotos

Maintained by @shinyakato.dev

🔭 READ MORE 🔭''';
  }

  return '''$title

- [Pic]($officialUrl)
- [HD Pic](${apod.hdUrl})
- $_markdownAboutAPOD

#astrophotos

Maintained by @shinyakato.dev

🔭 READ MORE 🔭''';
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
      quality -= 15;
    }

    fileBytes = encodedImage;
  }

  return fileBytes;
}
