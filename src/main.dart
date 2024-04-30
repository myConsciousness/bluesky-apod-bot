import 'dart:io' show Platform;

import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';

import 'aws/aws_lambda.dart' as fn;

Future<void> main() async {
  final s3 = S3(region: Platform.environment['AWS_REGION']!);

  await invokeAwsLambdaRuntime([
    fn.postToday(s3),
    fn.repostToday(s3),
    fn.repostAgainADayLater(s3),
    fn.repostAgainTwoDaysLater(s3),
  ]);
}
