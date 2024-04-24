import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';

import 'post/post_today.dart';

void main() {
  AwsLambdaRuntime()
    ..addHandler(
      FunctionHandler(
        name: 'main.today',
        action: (context, event) async {
          await postToday();

          return InvocationResult(
            requestId: context.requestId,
            body: {
              'statusCode': 200,
              'body': event,
            },
          );
        },
      ),
    )
    ..invoke();
}
