import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/child_avatar.dart';

class _DayStats {
  final int done;
  final int total;
  const _DayStats(this.done, this.total);
  bool get allDone => total > 0 && done == total;
}

class _ChildReport {
  final Map<String, dynamic> child;
  final List<(DateTime, _DayStats)> days; // every day in the period
  final int done;
  final int total;
  final int currentStreak;
  final int bestStreak;

  _ChildReport({
    required this.child,
    required this.days,
    required this.done,
    required this.total,
    required this.currentStreak,
    required this.bestStreak,
  });

  int get completionPercent => total == 0 ? 0 : (done * 100 / total).round();
}

String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

/// Premium: weekly/monthly progress, completion stats and streaks.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService();

  int _periodDays = 7;
  List<_ChildReport> reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final periodStart = DateTime(
      today.year,
      today.month,
      today.day - (_periodDays - 1),
    );
    final kids = await _db.getChildren();

    final result = <_ChildReport>[];
    for (final child in kids) {
      // All history up to today, for streaks.
      final tasks = await _db.getTasksForChildBetween(
        child['id'],
        '0000-01-01',
        _ymd(today),
      );

      final byDate = <String, _DayStats>{};
      for (final t in tasks) {
        final s = byDate[t['date']] ?? const _DayStats(0, 0);
        byDate[t['date']] = _DayStats(
          s.done + (t['isCompleted'] == 1 ? 1 : 0),
          s.total + 1,
        );
      }

      final days = <(DateTime, _DayStats)>[];
      int done = 0, total = 0;
      for (int i = 0; i < _periodDays; i++) {
        final date = DateTime(
          periodStart.year,
          periodStart.month,
          periodStart.day + i,
        );
        final s = byDate[_ymd(date)] ?? const _DayStats(0, 0);
        days.add((date, s));
        done += s.done;
        total += s.total;
      }

      final (current, best) = _streaks(byDate, _ymd(today));
      result.add(
        _ChildReport(
          child: child,
          days: days,
          done: done,
          total: total,
          currentStreak: current,
          bestStreak: best,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      reports = result;
      _loading = false;
    });
  }

  /// A streak counts days where every task was done. Days with no tasks
  /// don't break a streak, and today doesn't break it while still in
  /// progress.
  (int current, int best) _streaks(
    Map<String, _DayStats> byDate,
    String today,
  ) {
    final dates = byDate.keys.toList()..sort();
    int best = 0, run = 0;
    for (final d in dates) {
      if (byDate[d]!.allDone) {
        run++;
        if (run > best) best = run;
      } else if (d != today) {
        run = 0;
      }
    }
    return (run, best);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text("Last 7 days")),
                    ButtonSegment(value: 30, label: Text("Last 30 days")),
                  ],
                  selected: {_periodDays},
                  onSelectionChanged: (s) {
                    setState(() => _periodDays = s.first);
                    loadReports();
                  },
                ),
                const SizedBox(height: 16),
                if (reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      "Add a child and some tasks to see reports.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...reports.map(_buildReportCard),
              ],
            ),
    );
  }

  Widget _buildReportCard(_ChildReport r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChildAvatar(avatar: r.child['avatar']),
                const SizedBox(width: 12),
                Text(
                  r.child['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _stat("${r.completionPercent}%", "completed"),
                _stat("${r.done}/${r.total}", "tasks done"),
                _stat("⭐ ${r.done}", "stars earned"),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat("🔥 ${r.currentStreak}", "day streak"),
                _stat("🏆 ${r.bestStreak}", "best streak"),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 20),
            _buildDailyChart(r.days),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildDailyChart(List<(DateTime, _DayStats)> days) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: "Daily completion chart",
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days.map((entry) {
            final (date, s) = entry;
            final fraction = s.total == 0 ? 0.0 : s.done / s.total;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _periodDays <= 7 ? 6 : 1,
                ),
                child: Column(
                  children: [
                    // Bars share whatever height the label leaves, so a
                    // full bar never overflows (including large fonts).
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: (fraction * constraints.maxHeight).clamp(
                              4.0,
                              constraints.maxHeight,
                            ),
                            decoration: BoxDecoration(
                              color: s.total == 0
                                  ? Colors.grey.shade300
                                  : s.allDone
                                  ? colors.primary
                                  : colors.primary.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _periodDays <= 7
                          ? weekdays[date.weekday - 1]
                          : (date.day % 5 == 0 ? '${date.day}' : ''),
                      style: const TextStyle(fontSize: 11),
                      // Month bars are narrow; let "25" spill into the
                      // neighbouring (empty) labels rather than wrap.
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
