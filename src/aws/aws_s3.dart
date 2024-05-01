import 'dart:convert';

import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:csv/csv.dart';

const _toCsv = CsvToListConverter();
const _fromCsv = ListToCsvConverter();

const _kBucket = 's3-bluesky-bot-apod';
const _kBucketKey = 'history.csv';

Future<void> putObject(
  final S3 s3,
  final List<List<dynamic>> csv,
) async =>
    await s3.putObject(
      bucket: _kBucket,
      key: _kBucketKey,
      body: utf8.encode(_fromCsv.convert(csv)),
    );

Future<List<List<dynamic>>> getObject(final S3 s3) async {
  try {
    final object = await s3.getObject(bucket: _kBucket, key: _kBucketKey);

    return object.body != null
        ? _toCsv.convert(utf8.decode(object.body!))
        : <List<dynamic>>[];
  } catch (_) {
    return <List<dynamic>>[];
  }
}
