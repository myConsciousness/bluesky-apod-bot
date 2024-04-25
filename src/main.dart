import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';

import 'post/post_today.dart';

Future<void> main() async {
  await AwsLambdaRuntime()
      .addHandler(
        FunctionHandler(
          name: 'main.today',
          action: (context, event) async {
            await postToday();

            return InvocationResult(
              requestId: context.requestId,
              body: {
                'message': 'success',
              },
            );
          },
        ),
      )
      .invoke();
}
