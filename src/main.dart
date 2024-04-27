import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';

import 'functions.dart' as fn;

Future<void> main() async => await invokeAwsLambdaRuntime([
      fn.postToday,
    ]);
