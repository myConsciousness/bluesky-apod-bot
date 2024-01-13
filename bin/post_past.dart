import 'dart:convert';
import 'dart:io';

import 'post.dart';

Future<void> main(List<String> args) async {
  final metaFile = File('./data/meta.json');

  final meta = jsonDecode(metaFile.readAsStringSync());
  final date = DateTime.parse(meta['pastLastIndexedAt']).add(
    Duration(days: -1),
  );

  await post(date);

  meta['pastLastIndexedAt'] = date.toIso8601String();

  metaFile.writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(meta),
  );
}
