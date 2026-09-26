// Routine days are stored as a bitmask: bit 0 = Monday ... bit 6 = Sunday,
// matching DateTime.weekday - 1.

const int kEveryDay = 0x7F;
const int kWeekdays = 0x1F;
const int kWeekends = 0x60;

const List<String> kDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<String> kDayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

bool includesWeekday(int days, int weekday) => days & (1 << (weekday - 1)) != 0;

int toggleWeekday(int days, int weekday) => days ^ (1 << (weekday - 1));

String describeDays(int days) {
  if (days == kEveryDay) return 'Every day';
  if (days == kWeekdays) return 'Weekdays';
  if (days == kWeekends) return 'Weekends';
  return [
    for (int d = 1; d <= 7; d++)
      if (includesWeekday(days, d)) kDayNames[d - 1],
  ].join(', ');
}
