import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:intl/intl.dart';

import '../post/post.dart';
import '../post/repost.dart';
import 'aws_s3.dart';

enum PostStatus {
  posted(0, 0),
  reposted(1, 0),
  repostedAgainADayLater(2, 1),
  repostedAgainTwoDaysLater(3, 2);

  final int value;
  final int offset;

  const PostStatus(this.value, this.offset);

  static PostStatus? valueOf(final int value) {
    for (final $value in values) {
      if ($value.value == value) {
        return $value;
      }
    }

    return null;
  }

  static PostStatus? getPreviousStatus(final PostStatus status) {
    switch (status) {
      case PostStatus.posted:
        return null;
      case PostStatus.reposted:
        return PostStatus.posted;
      case PostStatus.repostedAgainADayLater:
        return PostStatus.reposted;
      case PostStatus.repostedAgainTwoDaysLater:
        return PostStatus.repostedAgainADayLater;
    }
  }
}

String _getCsvKey(final DateTime dateTime) =>
    DateFormat('yyyyMMdd').format(dateTime);

FunctionHandler postToday(final S3 s3) => FunctionHandler(
      name: 'post.today',
      action: (context, event) async {
        final uri = await post();
        final csv = await getObject(s3);

        await putObject(
          s3,
          csv
            ..add([
              _getCsvKey(DateTime.now().toUtc()),
              uri.rkey,
              PostStatus.posted.value,
            ]),
        );

        return InvocationResult(requestId: context.requestId);
      },
    );

FunctionHandler repostToday(final S3 s3) => FunctionHandler(
      name: 'repost.today',
      action: _repost(s3, PostStatus.reposted),
    );

FunctionHandler repostAgainADayLater(final S3 s3) => FunctionHandler(
      name: 'repost.againADayLater',
      action: _repost(
        s3,
        PostStatus.repostedAgainADayLater,
        again: true,
      ),
    );

FunctionHandler repostAgainTwoDaysLater(final S3 s3) => FunctionHandler(
      name: 'repost.againTwoDaysLater',
      action: _repost(
        s3,
        PostStatus.repostedAgainTwoDaysLater,
        again: true,
      ),
    );

FunctionAction _repost(
  final S3 s3,
  final PostStatus nextStatus, {
  bool again = false,
}) =>
    (context, event) async {
      final csv = await getObject(s3);

      if (csv.length <= nextStatus.offset) {
        return InvocationResult(requestId: context.requestId);
      }

      final record = csv[csv.length - nextStatus.offset - 1];
      final status = PostStatus.valueOf(record[2]);

      if (status != null &&
          status == PostStatus.getPreviousStatus(nextStatus)) {
        await repost(rkey: record[1], again: again);
        record[2] = nextStatus.value;

        await putObject(s3, csv);
      }

      return InvocationResult(requestId: context.requestId);
    };
