import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/limit_service.dart';

class TaskChecklistScreen extends StatefulWidget {
  const TaskChecklistScreen({super.key});

  @override
  State<TaskChecklistScreen> createState() => _TaskChecklistScreenState();
}

class _TaskChecklistScreenState extends State<TaskChecklistScreen> {
  final DatabaseService _db = DatabaseService();
  final LimitService _limits = LimitService(isPremium: false);
  List<Map<String, dynamic>> tasks = [];
  late Map<String, dynamic> child;
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  final ScrollController _dayScrollController = ScrollController();

  String get formattedDate => selectedDate.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
  }

  bool _initialized = false;

  String get prettyDate {
    return "${_weekday(selectedDate.weekday)}, "
        "${selectedDate.day} "
        "${_month(selectedDate.month)} "
        "${selectedDate.year}";
  }

  String _weekday(int day) {
    const names = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[day];
  }

  String _month(int month) {
    const names = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return names[month];
  }

  // Calendar-day arithmetic. Adding Duration(days: n) adds 24-hour blocks,
  // which skips or repeats a day across a daylight-saving change.
  DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  String _weekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      child =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _initializeTasks();
      _initialized = true;
    }
  }

  Future<void> _initializeTasks() async {
    await _db.generateDailyTasksIfNeeded(child['id']);
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    final date = formattedDate;

    final loadedTasks = await _db.getTasksForChild(child['id'], date);

    // Ignore stale results if the user moved to another day meanwhile.
    if (!mounted || date != formattedDate) return;
    setState(() {
      tasks = loadedTasks;
    });
  }

  Future<void> addTask() async {
    TextEditingController controller = TextEditingController();
    final templates = await _db.getAllTemplates();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Task"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Manual entry
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "Enter task name"),
            ),

            const SizedBox(height: 20),

            // Template dropdown
            if (templates.isNotEmpty)
              DropdownButtonFormField<Map<String, dynamic>>(
                hint: const Text("Or select from templates"),
                items: templates.map((template) {
                  return DropdownMenuItem(
                    value: template,
                    child: Text(template['title']),
                  );
                }).toList(),
                onChanged: (selected) {
                  if (selected != null) {
                    controller.text = selected['title'];
                  }
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;

              // Save to the day being viewed, not always today.
              final date = formattedDate;
              if (!await _limits.canAddTask(child['id'], date)) {
                if (!mounted) return;
                Navigator.pop(context);
                // TODO: show Paywall Screen 2 (Unlock Unlimited Tasks)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "The free plan allows 5 tasks per day. Upgrade to Premium for unlimited tasks.",
                    ),
                  ),
                );
                return;
              }

              await _db.insertTaskWithDate(child['id'], title, date);

              if (!mounted) return;
              Navigator.pop(context);
              _loadTasks();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${child['name']}'s Tasks"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: copyTasksToSelectedDays,
          ),
          IconButton(
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
      floatingActionButton: FloatingActionButton(
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
            _buildPlannerHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildAnimatedTaskList()),
          ],
        ),
      ),
    );
  }

  Future<void> copyTasksToSelectedDays() async {
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
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];

                return CheckboxListTile(
                  title: Text(task['title']),
                  value: task['isCompleted'] == 1,
                  onChanged: (value) async {
                    await _db.updateTaskStatus(task['id'], value ?? false);

                    await _loadTasks();
                  },
                );
              },
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
          Text(
            "${child['name']}'s Tasks",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),

          // Selected full date
          Text(
            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),

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
                          _weekdayShort(date.weekday),
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
