import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:intl/intl.dart';

import '../post/post.dart';
import '../post/repost.dart';
import 'aws_s3.dart';

enum PostStatus {
  posted('0'),
  reposted('1'),
  repostedAgainADayLater('2'),
  repostedAgainTwoDaysLater('3');

  final String value;

  const PostStatus(this.value);

  static PostStatus? valueOf(final String value) {
    for (final $value in values) {
      if ($value.value == value) {
        return $value;
      }
    }

    return null;
  }
}

String _getCsvKey(final DateTime dateTime) =>
    DateFormat('yyyyMMdd').format(dateTime);

FunctionHandler postToday(final S3 s3) => FunctionHandler(
      name: 'post.today',
      action: (context, event) async {
        final today = DateTime.now();

        final uri = await post(today);
        final csv = await getObject(s3);

        await putObject(
          s3,
          csv
            ..add([
              _getCsvKey(today),
              uri.rkey,
              PostStatus.posted.value,
            ]),
        );

        return InvocationResult(requestId: context.requestId);
      },
    );

FunctionHandler repostToday(final S3 s3) => FunctionHandler(
      name: 'repost.today',
      action: (context, event) async {
        final csv = await getObject(s3);
        final status = PostStatus.valueOf(csv.last[2]);

        if (status != null && status == PostStatus.posted) {
          await repost(rkey: csv.last[1]);
          csv.last[2] = PostStatus.reposted.value;

          await putObject(s3, csv);
        }

        return InvocationResult(requestId: context.requestId);
      },
    );
