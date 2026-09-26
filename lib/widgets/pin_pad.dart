import 'package:flutter/material.dart';
import '../services/parental_gate.dart';

/// Shows a PIN keypad. [validate] returns an error message, or null to
/// accept. Resolves to true when a PIN was accepted.
Future<bool> showPinSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Future<String?> Function(String pin) validate,
  VoidCallback? onForgot,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PinSheet(
      title: title,
      subtitle: subtitle,
      validate: validate,
      onForgot: onForgot,
    ),
  );
  return result ?? false;
}

class _PinSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<String?> Function(String pin) validate;
  final VoidCallback? onForgot;

  const _PinSheet({
    required this.title,
    required this.subtitle,
    required this.validate,
    this.onForgot,
  });

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';
  String? _error;
  bool _checking = false;

  Future<void> _press(String digit) async {
    if (_checking || _pin.length >= kPinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });

    if (_pin.length == kPinLength) {
      setState(() => _checking = true);
      final error = await widget.validate(_pin);
      if (!mounted) return;
      if (error == null) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = error;
          _pin = '';
          _checking = false;
        });
      }
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(widget.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Semantics(
              label: '${_pin.length} of $kPinLength digits entered',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(kPinLength, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? colors.primary : Colors.transparent,
                      border: Border.all(color: colors.primary, width: 2),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  _error ?? '',
                  style: TextStyle(color: colors.error),
                ),
              ),
            ),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map(_digitKey).toList(),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 88, height: 72),
                _digitKey('0'),
                SizedBox(
                  width: 88,
                  height: 72,
                  child: IconButton(
                    tooltip: 'Delete digit',
                    icon: const Icon(Icons.backspace_outlined),
                    onPressed: _backspace,
                  ),
                ),
              ],
            ),
            if (widget.onForgot != null)
              TextButton(
                onPressed: widget.onForgot,
                child: const Text('Forgot PIN?'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _digitKey(String digit) {
    return SizedBox(
      width: 88,
      height: 72,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(shape: const CircleBorder()),
          onPressed: () => _press(digit),
          child: Text(digit, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
