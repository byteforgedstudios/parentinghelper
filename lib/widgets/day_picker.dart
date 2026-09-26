import 'package:flutter/material.dart';
import '../state/routine_days.dart';

/// Monday–Sunday toggle chips for choosing which days a routine repeats.
class DayPicker extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;

  const DayPicker({super.key, required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int d = 1; d <= 7; d++)
              Semantics(
                button: true,
                selected: includesWeekday(days, d),
                label: kDayNames[d - 1],
                child: GestureDetector(
                  onTap: () => onChanged(toggleWeekday(days, d)),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: includesWeekday(days, d)
                          ? colors.primary
                          : Colors.grey.shade200,
                    ),
                    child: Text(
                      kDayLetters[d - 1],
                      style: TextStyle(
                        color: includesWeekday(days, d)
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final (label, mask) in const [
              ('Every day', kEveryDay),
              ('Weekdays', kWeekdays),
              ('Weekends', kWeekends),
            ])
              ActionChip(
                label: Text(label),
                visualDensity: VisualDensity.compact,
                onPressed: () => onChanged(days == mask ? 0 : mask),
              ),
          ],
        ),
      ],
    );
  }
}
