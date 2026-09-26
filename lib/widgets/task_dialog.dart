import 'package:flutter/material.dart';
import '../state/routine_days.dart';
import 'day_picker.dart';

/// Asks for a task name and repeat days. Returns (title, days), where
/// days == 0 means a one-off task, or null if cancelled.
///
/// The dialog owns its text controller, so it's disposed only after the
/// dialog has fully closed (disposing it while the dialog animates out
/// crashes the framework).
Future<(String, int)?> showTaskDialog(
  BuildContext context, {
  required String dialogTitle,
  String initialText = '',
  int initialDays = 0,
  String? oneOffLabel, // null = repeat days are required (routines)
  String confirmLabel = 'Add',
}) {
  return showDialog<(String, int)>(
    context: context,
    builder: (_) => _TaskDialog(
      dialogTitle: dialogTitle,
      initialText: initialText,
      initialDays: initialDays,
      oneOffLabel: oneOffLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

class _TaskDialog extends StatefulWidget {
  final String dialogTitle;
  final String initialText;
  final int initialDays;
  final String? oneOffLabel;
  final String confirmLabel;

  const _TaskDialog({
    required this.dialogTitle,
    required this.initialText,
    required this.initialDays,
    required this.oneOffLabel,
    required this.confirmLabel,
  });

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  late int _days = widget.initialDays;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _controller.text.trim().isNotEmpty &&
      (widget.oneOffLabel != null || _days != 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.initialText.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: "Enter task name"),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text("Repeat", style: theme.titleSmall),
            const SizedBox(height: 8),
            DayPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
            const SizedBox(height: 6),
            Text(
              _days != 0
                  ? "Repeats: ${describeDays(_days)}"
                  : widget.oneOffLabel ?? "Pick at least one day",
              style: theme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _canSave
              ? () => Navigator.pop(context, (_controller.text.trim(), _days))
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
