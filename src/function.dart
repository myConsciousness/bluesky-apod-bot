import 'post/post_today.dart';

Future<Map<String, dynamic>> today(Map<String, dynamic> event) async {
  await postToday();

  return {
    'statusCode': 200,
    'body': event['body'],
  };
}
