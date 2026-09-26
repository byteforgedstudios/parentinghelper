import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/pin_pad.dart';

const int kPinLength = 4;

/// Hashes a PIN with its salt. Iterated so a copied settings file can't be
/// brute-forced instantly; a 4-digit PIN is still only meant to stop kids.
@visibleForTesting
String hashPin(String pin, String salt) {
  var digest = utf8.encode('$salt:$pin');
  for (int i = 0; i < 10000; i++) {
    digest = Uint8List.fromList(sha256.convert(digest).bytes);
  }
  return base64Encode(digest);
}

/// PIN-protected gate for parent-only actions (redeeming rewards, deleting,
/// purchases, settings), so kids using the phone can't change things.
class ParentalGate extends ChangeNotifier {
  ParentalGate._();
  static final ParentalGate instance = ParentalGate._();

  static const _hashKey = 'parent_pin_hash';
  static const _saltKey = 'parent_pin_salt';
  static const unlockDuration = Duration(minutes: 2);
  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(seconds: 30);

  DateTime? _unlockedUntil;
  int _failedAttempts = 0;
  DateTime? _lockedOutUntil;

  bool get isUnlocked =>
      _unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!);

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hashKey) != null;
  }

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64Encode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saltKey, salt);
    await prefs.setString(_hashKey, hashPin(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_saltKey);
    final hash = prefs.getString(_hashKey);
    if (salt == null || hash == null) return false;
    return hashPin(pin, salt) == hash;
  }

  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_saltKey);
    lock();
  }

  void _unlock() {
    _unlockedUntil = DateTime.now().add(unlockDuration);
    _failedAttempts = 0;
    notifyListeners();
  }

  void lock() {
    _unlockedUntil = null;
    notifyListeners();
  }

  /// Returns true if a parent confirmed with the PIN (or unlocked in the
  /// last [unlockDuration]). Asks to create a PIN if none exists yet.
  Future<bool> requireParent(BuildContext context, {String? reason}) async {
    if (isUnlocked) return true;

    if (!await hasPin()) {
      if (!context.mounted) return false;
      return createPin(context);
    }
    if (!context.mounted) return false;

    final ok = await showPinSheet(
      context,
      title: 'Parent PIN',
      subtitle: reason ?? 'Enter your PIN to continue.',
      onForgot: () => _forgotPin(context),
      validate: (pin) async {
        final lockedOut = _lockedOutUntil;
        if (lockedOut != null && DateTime.now().isBefore(lockedOut)) {
          final secs = lockedOut.difference(DateTime.now()).inSeconds + 1;
          return 'Too many tries. Wait $secs seconds.';
        }
        if (await verifyPin(pin)) return null;

        _failedAttempts++;
        if (_failedAttempts >= _maxAttempts) {
          _failedAttempts = 0;
          _lockedOutUntil = DateTime.now().add(_lockoutDuration);
          return 'Too many tries. Wait 30 seconds.';
        }
        return 'Wrong PIN. Try again.';
      },
    );
    if (ok) _unlock();
    return ok;
  }

  /// Asks for a new PIN twice. Returns true once it's saved.
  Future<bool> createPin(BuildContext context, {bool isChange = false}) async {
    String? first;
    final entered = await showPinSheet(
      context,
      title: isChange ? 'New parent PIN' : 'Create a parent PIN',
      subtitle:
          'Protects rewards, purchases and settings from little fingers. '
          'Choose $kPinLength digits your kids won\'t guess.',
      validate: (pin) async {
        first = pin;
        return null;
      },
    );
    if (!entered || first == null || !context.mounted) return false;

    final confirmed = await showPinSheet(
      context,
      title: 'Confirm PIN',
      subtitle: 'Enter the same $kPinLength digits again.',
      validate: (pin) async => pin == first ? null : 'PINs don\'t match.',
    );
    if (!confirmed) return false;

    await setPin(first!);
    _unlock();
    return true;
  }

  /// Lets a grown-up reset the PIN after answering a maths question. This
  /// is a common parental-gate pattern; it stops young children, not
  /// determined older ones.
  Future<void> _forgotPin(BuildContext context) async {
    final random = Random();
    final a = 12 + random.nextInt(8);
    final b = 6 + random.nextInt(4);
    final passed = await showDialog<bool>(
      context: context,
      builder: (_) => _GrownUpQuestionDialog(a: a, b: b),
    );

    if (!context.mounted) return;
    if (passed != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That answer isn\'t right.')),
      );
      return;
    }
    // Close the PIN entry sheet, then create a new PIN.
    Navigator.pop(context, false);
    await createPin(context, isChange: true);
  }
}

/// "What is a × b?" check before resetting the PIN. Owns its controller so
/// it's disposed only after the dialog has fully closed.
class _GrownUpQuestionDialog extends StatefulWidget {
  final int a;
  final int b;

  const _GrownUpQuestionDialog({required this.a, required this.b});

  @override
  State<_GrownUpQuestionDialog> createState() => _GrownUpQuestionDialogState();
}

class _GrownUpQuestionDialogState extends State<_GrownUpQuestionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "To prove you're a grown-up, what is ${widget.a} × ${widget.b}?",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Answer'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            int.tryParse(_controller.text.trim()) == widget.a * widget.b,
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
