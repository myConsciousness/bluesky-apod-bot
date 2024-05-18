import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:intl/intl.dart';

import '../post/post.dart';
import '../post/repost.dart' as fn;
import 'aws_s3.dart';

enum PostStatus {
  posted(0),
  reposted(1),
  repostedAgain(2),
  failed(9);

  final int value;

  const PostStatus(this.value);

  static PostStatus? valueOf(final int value) {
    for (final $value in values) {
      if ($value.value == value) {
        return $value;
      }
    }

    return null;
  }

  static PostStatus getPreviousStatus(final PostStatus status) {
    switch (status) {
      case PostStatus.reposted:
        return PostStatus.posted;
      case PostStatus.repostedAgain:
        return PostStatus.reposted;
      default:
        throw UnsupportedError('No previous status for "$status".');
    }
  }
}

String _getCsvKey(final DateTime dateTime) =>
    DateFormat('yyyyMMdd').format(dateTime);

FunctionHandler postToday(final S3 s3) => FunctionHandler(
      name: 'post.today',
      action: (context, event) async {
        final csv = await getObject(s3);

        try {
          final uri = await post();

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
        } catch (_) {
          await putObject(
            s3,
            csv
              ..add([
                _getCsvKey(DateTime.now().toUtc()),
                '',
                PostStatus.failed.value,
              ]),
          );

          rethrow;
        }
      },
    );

FunctionHandler postRecovery(final S3 s3) => FunctionHandler(
      name: 'post.recovery',
      action: (context, event) async {
        final csv = await getObject(s3);

        for (final record in csv) {
          if (record[2] == PostStatus.failed.value) {
            final uri = await post();

            record[1] = uri.rkey;
            record[2] = PostStatus.posted.value;

            await putObject(s3, csv);

            break;
          }
        }

        return InvocationResult(requestId: context.requestId);
      },
    );

FunctionHandler repost(final S3 s3) => FunctionHandler(
      name: 'repost',
      action: _repost(s3, PostStatus.reposted),
    );

FunctionHandler repostAgain(final S3 s3) => FunctionHandler(
      name: 'repost.again',
      action: _repost(s3, PostStatus.repostedAgain),
    );

FunctionAction _repost(final S3 s3, final PostStatus nextStatus) =>
    (context, event) async {
      final csv = await getObject(s3);

      final previousStatus = PostStatus.getPreviousStatus(nextStatus);
      for (final record in csv) {
        if (record[2] == previousStatus.value) {
          await fn.repost(rkey: record[1]);

          record[2] = nextStatus.value;
          await putObject(s3, csv);

          break;
        }
      }

      return InvocationResult(requestId: context.requestId);
    };
