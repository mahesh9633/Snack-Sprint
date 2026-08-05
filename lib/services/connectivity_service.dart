import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Global connectivity monitor.
///
/// Exposes a broadcast stream of `bool` (true = online, false = offline)
/// so any screen/widget can listen and react — e.g. auto-refresh its
/// data the instant the connection comes back, with no retry button.
///
/// Add to pubspec.yaml:
///   connectivity_plus: ^6.0.5
class ConnectivityService {
  ConnectivityService._internal() {
    _init();
  }
  static final ConnectivityService instance = ConnectivityService._internal();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _isOnline;
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> _init() async {
    try {
      final initial = await Connectivity().checkConnectivity();
      _isOnline = _hasConnection(initial);
    } catch (_) {
      _isOnline = true; // fail open — don't block the app on a check error
    }

    _sub = Connectivity().onConnectivityChanged.listen((result) {
      final nowOnline = _hasConnection(result);
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        _controller.add(_isOnline);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Call once from main() if you ever need to tear it down (rare —
  /// this is normally a process-lifetime singleton).
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}