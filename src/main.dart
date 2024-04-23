import 'aws/runtime.dart';
import 'post/post_today.dart';

void main(List<String> args) {
  handler('main.today', (event) async {
    await postToday();

    return {
      'statusCode': 200,
      'body': event['body'],
    };
  });
}
