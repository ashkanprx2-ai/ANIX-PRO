import 'dart:async';

/// App-wide events the corner companion (ORACLE / LUNA) reacts to (wins, losses, purchases…).
class OracleBus {
  OracleBus._();
  static final StreamController<String> _c = StreamController<String>.broadcast();
  static Stream<String> get stream => _c.stream;
  static void emit(String event) {
    if (!_c.isClosed) _c.add(event);
  }

  /// Any touch anywhere (idle detection).
  static DateTime lastTouch = DateTime.now();
}
