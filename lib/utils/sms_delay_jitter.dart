import 'dart:math';

final _rand = Random();

Duration smsDelayWithJitter() {
  return Duration(seconds: 5 + _rand.nextInt(6)); // 5–10 seconds
}
