import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/limit_service.dart';
import '../services/parental_gate.dart';
import '../state/app_limits.dart';
import '../state/routine_days.dart';
import '../widgets/read_only_banner.dart';
import '../widgets/task_dialog.dart';
import 'paywall_screen.dart';
import 'routines_screen.dart';

class TaskChecklistScreen extends StatefulWidget {
  const TaskChecklistScreen({super.key});

  @override
  State<TaskChecklistScreen> createState() => _TaskChecklistScreenState();
}

class _TaskChecklistScreenState extends State<TaskChecklistScreen> {
  final DatabaseService _db = DatabaseService();
  final LimitService _limits = LimitService();
  final ParentalGate _gate = ParentalGate.instance;
  List<Map<String, dynamic>> tasks = [];
  late Map<String, dynamic> child;
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  final ScrollController _dayScrollController = ScrollController();

  // Without Premium: extra children are read-only, and tasks beyond the
  // first 5 of a day can't be ticked.
  bool _readOnly = false;
  Set<int> _editableIds = {};

  String get formattedDate => selectedDate.toIso8601String().split('T').first;

  bool _initialized = false;

  String get prettyDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${kDayNames[selectedDate.weekday - 1]}, "
        "${selectedDate.day} ${months[selectedDate.month - 1]} "
        "${selectedDate.year}";
  }

  // Calendar-day arithmetic. Adding Duration(days: n) adds 24-hour blocks,
  // which skips or repeats a day across a daylight-saving change.
  DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      child =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _loadTasks();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final date = formattedDate;
    final readOnly = await _limits.isChildReadOnly(child['id']);

    // Create today's/future tasks from the child's routines.
    if (!readOnly) {
      await _db.generateRoutineTasks(
        child['id'],
        selectedDate,
        maxTasks: _limits.isPremium ? null : FREE_MAX_TASKS_PER_CHILD,
      );
    }
    final loadedTasks = await _db.getTasksForChild(child['id'], date);

    // Ignore stale results if the user moved to another day meanwhile.
    if (!mounted || date != formattedDate) return;
    setState(() {
      tasks = loadedTasks;
      _readOnly = readOnly;
      _editableIds = readOnly ? {} : _limits.editableTaskIds(loadedTasks);
    });
  }

  Future<void> addTask() async {
    if (!await _gate.requireParent(
          context,
          reason: 'Enter your PIN to add a task.',
        ) ||
        !mounted) {
      return;
    }

    final result = await showTaskDialog(
      context,
      dialogTitle: "Add Task",
      oneOffLabel: "Just on $prettyDate",
    );
    if (result == null || !mounted) return;
    final (title, repeatDays) = result;

    // Save to the day being viewed, not always today.
    final date = formattedDate;
    if (!await _limits.canAddTask(child['id'], date)) {
      if (!mounted) return;
      // Paywall Screen 2: adding a 6th task on the free plan.
      if (!await showPaywall(context, PaywallTrigger.addTask)) return;
    }

    if (repeatDays == 0) {
      await _db.insertTaskWithDate(child['id'], title, date);
    } else {
      // A routine; its task for the viewed day is created by _loadTasks
      // (if the day is one of the repeat days).
      await _db.insertRoutine(child['id'], title, repeatDays);
    }
    await _loadTasks();
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    if (!await _gate.requireParent(
          context,
          reason: 'Enter your PIN to delete a task.',
        ) ||
        !mounted) {
      return;
    }

    final fromRoutine = task['routineId'] != null;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete \"${task['title']}\"?"),
        content: Text(
          fromRoutine
              ? "This removes it from $prettyDate only. To stop it repeating, "
                    "edit the routine."
              : "This removes it from $prettyDate.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _db.deleteTask(task['id']);
    await _loadTasks();
  }

  Future<void> _openRoutines() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoutinesScreen(child: child)),
    );
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${child['name']}'s Tasks"),
        actions: [
          if (!_readOnly) ...[
            IconButton(
              tooltip: "Routines",
              icon: const Icon(Icons.repeat),
              onPressed: _openRoutines,
            ),
            IconButton(
              tooltip: "Copy tasks to other days",
              icon: const Icon(Icons.copy),
              onPressed: copyTasksToSelectedDays,
            ),
          ],
          IconButton(
            tooltip: "Pick a date",
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );

              if (picked != null) {
                setState(() {
                  selectedDate = DateUtils.dateOnly(picked);
                });
                await _loadTasks();
              }
            },
          ),
        ],
      ),
      floatingActionButton: _readOnly
          ? null
          : FloatingActionButton(
              tooltip: "Add task",
              onPressed: addTask,
              child: const Icon(Icons.add),
            ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) async {
          if (details.primaryVelocity == null) return;

          if (details.primaryVelocity! < 0) {
            // Swipe Left → Next Day
            await _changeDay(1);
          } else if (details.primaryVelocity! > 0) {
            // Swipe Right → Previous Day
            await _changeDay(-1);
          }
        },
        child: Column(
          children: [
            if (_readOnly)
              ReadOnlyBanner(
                message:
                    "${child['name']} is read-only because Premium has "
                    "ended. Upgrade to tick tasks and plan again.",
                onUpgrade: () async {
                  await showPaywall(context, PaywallTrigger.readOnly);
                  await _loadTasks();
                },
              ),
            _buildPlannerHeader(),
            const SizedBox(height: 8),
            Expanded(child: _buildAnimatedTaskList()),
          ],
        ),
      ),
    );
  }

  Future<void> copyTasksToSelectedDays() async {
    if (!await _gate.requireParent(
          context,
          reason: 'Enter your PIN to copy tasks.',
        ) ||
        !mounted) {
      return;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    DateTime current = picked.start;
    bool hitLimit = false;

    while (!current.isAfter(picked.end)) {
      final newDate = current.toIso8601String().split('T').first;

      for (var task in tasks) {
        if (!await _limits.canAddTask(child['id'], newDate)) {
          hitLimit = true;
          break;
        }
        await _db.insertTaskWithDate(child['id'], task['title'], newDate);
      }

      current = _addDays(current, 1);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        action: hitLimit
            ? SnackBarAction(
                label: "Upgrade",
                onPressed: () => showPaywall(context, PaywallTrigger.addTask),
              )
            : null,
        content: Text(
          hitLimit
              ? "Some tasks were not copied: the free plan allows 5 tasks per day."
              : "Tasks copied successfully",
        ),
      ),
    );
    await _loadTasks();
  }

  Future<void> _changeDay(int offset) async {
    setState(() {
      selectedDate = _addDays(selectedDate, offset);
    });
    await _loadTasks();
  }

  Widget _buildAnimatedTaskList() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.2, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: tasks.isEmpty
          ? const Center(key: ValueKey("empty"), child: Text("No tasks yet"))
          : ListView.builder(
              key: ValueKey(selectedDate.toIso8601String()),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: tasks.length,
              itemBuilder: (context, index) => _buildTaskTile(tasks[index]),
            ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final editable = _editableIds.contains(task['id']);
    final fromRoutine = task['routineId'] != null;
    final lockedByPlan = !_readOnly && !editable;

    return GestureDetector(
      onLongPress: _readOnly ? null : () => _deleteTask(task),
      child: CheckboxListTile(
        title: Text(task['title']),
        subtitle: lockedByPlan
            ? const Text("Premium: free plan ticks 5 tasks a day")
            : fromRoutine
            ? const Text("Routine")
            : null,
        secondary: lockedByPlan
            ? IconButton(
                tooltip: "Unlock with Premium",
                icon: const Icon(Icons.lock_outline),
                onPressed: () async {
                  await showPaywall(context, PaywallTrigger.readOnly);
                  await _loadTasks();
                },
              )
            : fromRoutine
            ? const Icon(Icons.repeat, size: 20)
            : null,
        value: task['isCompleted'] == 1,
        onChanged: editable
            ? (value) async {
                await _db.updateTaskStatus(task['id'], value ?? false);
                await _loadTasks();
              }
            : null,
      ),
    );
  }

  Widget _buildPlannerHeader() {
    final today = DateTime.now();

    List<DateTime> days = List.generate(
      14,
      (index) => _addDays(today, index - 3),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prettyDate, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              controller: _dayScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final isSelected =
                    date.year == selectedDate.year &&
                    date.month == selectedDate.month &&
                    date.day == selectedDate.day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDate = date;
                    });
                    _loadTasks();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          kDayNames[date.weekday - 1],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${date.day}",
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
