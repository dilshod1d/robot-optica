import 'dart:io';
import 'package:flutter/services.dart';
import 'scan_sound.dart';

typedef BarcodeScanCallback = void Function(String code);

class BarcodeKeyboardListener {
  BarcodeKeyboardListener._();

  static final BarcodeKeyboardListener instance = BarcodeKeyboardListener._();

  final Map<int, _Handler> _handlers = {};
  int _nextToken = 1;
  bool _listening = false;

  String _buffer = '';
  DateTime? _firstAt;
  DateTime? _lastAt;

  bool get _isDesktop => Platform.isWindows || Platform.isMacOS;

  int pushHandler(
    BarcodeScanCallback onScan, {
    int minLength = 4,
    Duration maxGap = const Duration(milliseconds: 60),
    Duration maxTotal = const Duration(milliseconds: 700),
    bool enabled = true,
  }) {
    if (!_isDesktop) return -1;
    final token = _nextToken++;
    _handlers[token] = _Handler(
      onScan: onScan,
      minLength: minLength,
      maxGap: maxGap,
      maxTotal: maxTotal,
      enabled: enabled,
    );
    _startListening();
    return token;
  }

  void removeHandler(int token) {
    if (token < 0) return;
    _handlers.remove(token);
    if (_handlers.isEmpty) {
      _stopListening();
    }
  }

  _Handler? _activeHandler() {
    if (_handlers.isEmpty) return null;
    return _handlers[_handlers.keys.last];
  }

  void _startListening() {
    if (_listening) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _listening = true;
  }

  void _stopListening() {
    if (!_listening) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _listening = false;
    _reset();
  }

  bool _onKey(KeyEvent event) {
    final handler = _activeHandler();
    if (handler == null || !handler.enabled) return false;
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      _emit(handler);
      return false;
    }

    final char = event.character;
    if (char == null || char.isEmpty) return false;

    if (!_allowedChar(char)) return false;

    final now = DateTime.now();
    if (_lastAt != null && now.difference(_lastAt!) > handler.maxGap) {
      _reset();
    }

    _firstAt ??= now;
    _lastAt = now;
    _buffer += char;
    return false;
  }

  bool _allowedChar(String char) {
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);
    if (code < 32 || code > 126) return false;
    return RegExp(r'[0-9A-Za-z\-\._]').hasMatch(char);
  }

  void _emit(_Handler handler) {
    final code = _buffer;
    final firstAt = _firstAt;
    final lastAt = _lastAt;
    _reset();
    if (code.isEmpty || code.length < handler.minLength) return;
    if (firstAt != null && lastAt != null) {
      final duration = lastAt.difference(firstAt);
      if (duration > handler.maxTotal) return;
    }
    ScanSound.play();
    handler.onScan(code);
  }

  void _reset() {
    _buffer = '';
    _firstAt = null;
    _lastAt = null;
  }
}

class _Handler {
  final BarcodeScanCallback onScan;
  final int minLength;
  final Duration maxGap;
  final Duration maxTotal;
  final bool enabled;

  _Handler({
    required this.onScan,
    required this.minLength,
    required this.maxGap,
    required this.maxTotal,
    required this.enabled,
  });
}
