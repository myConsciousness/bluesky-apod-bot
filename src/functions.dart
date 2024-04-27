import 'package:aws_lambda_dart_runtime_ns/aws_lambda_dart_runtime_ns.dart';

import 'post/post_today.dart' as post;

FunctionHandler get postToday => FunctionHandler(
      name: 'main.today',
      action: (context, event) async {
        await post.postToday();

        return InvocationResult(requestId: context.requestId);
      },
    );
