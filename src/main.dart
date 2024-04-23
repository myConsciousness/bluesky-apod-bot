import 'aws/runtime.dart';
import 'function.dart' as fn;

void main() {
  handler('main.today', fn.today);
}
