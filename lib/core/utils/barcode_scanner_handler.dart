import 'package:flutter/services.dart';

typedef BarcodeScanCallback = void Function(String barcode);

/// A listener utility for hardware HID Barcode Scanners (USB / Bluetooth).
/// Hardware barcode scanners transmit characters in rapid succession (< 80ms apart)
/// terminating with an Enter key (LogicalKeyboardKey.enter or LogicalKeyboardKey.numpadEnter).
class BarcodeScannerHandler {
  final BarcodeScanCallback onBarcodeScanned;
  final Duration maxInterKeyDelay;
  final int minLength;

  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyTime;
  bool _isListening = false;

  BarcodeScannerHandler({
    required this.onBarcodeScanned,
    this.maxInterKeyDelay = const Duration(milliseconds: 100),
    this.minLength = 2,
  });

  /// Starts listening to global hardware key events.
  void start() {
    if (_isListening) return;
    _isListening = true;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /// Stops listening to global hardware key events.
  void stop() {
    if (!_isListening) return;
    _isListening = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _buffer.clear();
    _lastKeyTime = null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();

    // If delay between key presses exceeds threshold, reset buffer (manual typing)
    if (_lastKeyTime != null && now.difference(_lastKeyTime!) > maxInterKeyDelay) {
      _buffer.clear();
    }
    _lastKeyTime = now;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final barcode = _buffer.toString().trim();
      _buffer.clear();
      _lastKeyTime = null;

      if (barcode.length >= minLength) {
        onBarcodeScanned(barcode);
        return true;
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      _buffer.write(char);
    }

    return false;
  }
}
