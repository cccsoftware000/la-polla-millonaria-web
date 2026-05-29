// lib/core/utils/debounce.dart
import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

// ✅ Uso correcto (sin _performSearch undefined)
// En tu widget:
// final _debouncer = Debouncer();
//
// void onChanged(String value) {
//   _debouncer.call(() {
//     // Tu código aquí
//     setState(() {});
//   });
// }