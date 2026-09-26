import 'package:flutter/material.dart';

/// A grid of emoji choices. Choices where [isLocked] returns true show a
/// padlock; tapping them calls [onLockedTap] instead of selecting.
class EmojiPicker extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final bool Function(String option) isLocked;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onLockedTap;

  const EmojiPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.isLocked,
    required this.onSelected,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final locked = isLocked(option);
        final isSelected = option == selected;

        return Semantics(
          button: true,
          selected: isSelected,
          label: locked ? '$option, locked' : option,
          child: GestureDetector(
            onTap: () => locked ? onLockedTap(option) : onSelected(option),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colors.primaryContainer : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colors.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: locked ? 0.35 : 1,
                    child: Text(option, style: const TextStyle(fontSize: 28)),
                  ),
                  if (locked)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Icon(Icons.lock, size: 16, color: colors.primary),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
