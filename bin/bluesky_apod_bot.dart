import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:cron/cron.dart';
import 'package:http/http.dart' as http;
import 'package:nasa/nasa.dart';

bsky.Record? repostRecord;

void main(List<String> args) async {
  Cron().schedule(Schedule.parse('0 10,22 0 * *'), () async {
    final bluesky = bsky.Bluesky.fromSession(
      await _session,
      retryConfig: bsky.RetryConfig(
        maxAttempts: 10,
      ),
    );

    if (repostRecord != null) {
      await bluesky.feeds.createRepost(
        cid: repostRecord!.cid,
        uri: repostRecord!.uri,
      );

      repostRecord = null;
    }

    final nasa = NasaApi(
      token: Platform.environment['NASA_API_TOKEN']!,
    );

    final imageData = await nasa.apod.lookupImage();
    final image = imageData.data;

    final response = await http.get(Uri.parse(image.url));

    final file = File('dummy.jpg');
    file.writeAsBytesSync(response.bodyBytes);

    final blob = await bluesky.repositories.uploadBlob(file);

    final header = getHeader(image);
    final record = await bluesky.feeds.createPost(
      text: header,
      facets: getFacets(
        image,
        header,
      ),
      embed: bsky.Embed.images(
        data: bsky.EmbedImages(
          images: [
            bsky.Image(
              alt: image.title,
              image: blob.data.blob,
            )
          ],
        ),
      ),
    );

    repostRecord = record.data;
    final chunks = splitTextIntoChunks(image.description, 300);

    var parentRecord = record;
    for (final chunk in chunks) {
      parentRecord = await bluesky.feeds.createPost(
        text: chunk,
        reply: bsky.ReplyRef(
          root: bsky.StrongRef(
            cid: record.data.cid,
            uri: record.data.uri,
          ),
          parent: bsky.StrongRef(
            cid: parentRecord.data.cid,
            uri: parentRecord.data.uri,
          ),
        ),
      );
    }
  });
}

Future<bsky.Session> get _session async {
  final session = await bsky.createSession(
    identifier: Platform.environment['BLUESKY_AOOD_IDENTIFIER']!,
    password: Platform.environment['BLUESKY_AOOD_PASSWORD']!,
  );

  return session.data;
}

String getTitle(final APODData apod) {
  if (apod.copyright == null) {
    return apod.title;
  }

  return '${apod.title} - ©${apod.copyright}';
}

String getHeader(final APODData apod) {
  final title = getTitle(apod);

  if (apod.hdUrl == null) {
    return '''$title

Please read the following thread for an explanation of this image! 👇
''';
  }

  return '''$title

HD: ${apod.hdUrl}

Please read the following thread for an explanation of this image! 👇
''';
}

List<String> splitTextIntoChunks(String text, int maxChunkSize) {
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

List<bsky.Facet>? getFacets(final APODData apod, final String header) {
  if (apod.hdUrl == null) {
    return null;
  }

  final urlStart = header.indexOf(apod.hdUrl!);

  return [
    bsky.Facet(
      index: bsky.ByteSlice(
        byteStart: urlStart,
        byteEnd: urlStart + apod.hdUrl!.length + 1,
      ),
      features: [
        bsky.FacetFeature.link(
          data: bsky.FacetLink(
            uri: apod.hdUrl!,
          ),
        )
      ],
    ),
  ];
}
