import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;

void handler(String name, Function(Map<String, dynamic>) callback) async {
  if (name != Platform.environment['_HANDLER']) return;

  final api = Platform.environment['AWS_LAMBDA_RUNTIME_API'];

  while (true) {
    final response = await http.get(
      Uri.parse('http://$api/2018-06-01/runtime/invocation/next'),
    );

    final Map<String, dynamic> eventData =
        json.decode(utf8.decode(response.bodyBytes));
    final requestId = response.headers['lambda-runtime-aws-request-id'];

    try {
      final result = await callback(eventData);
      http.post(
          Uri.parse(
              'http://$api/2018-06-01/runtime/invocation/$requestId/response'),
          body: json.encode(result));
    } catch (e) {
      http.post(
          Uri.parse(
              'http://$api/2018-06-01/runtime/invocation/$requestId/error'),
          body: json.encode({
            'statusCode': 500,
            'body': json.encode({'error': e.toString()}),
          }));
    }
  }
}
