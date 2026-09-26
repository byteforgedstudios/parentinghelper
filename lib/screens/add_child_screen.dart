import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/premium_service.dart';
import '../state/premium_content.dart';
import '../widgets/emoji_picker.dart';
import 'paywall_screen.dart';

/// Adds a child, or edits one when a child map is passed as the route
/// argument.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _db = DatabaseService();
  final PremiumService _premium = PremiumService.instance;

  Map<String, dynamic>? _editing;
  String _avatar = kStandardAvatar;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _editing =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (_editing != null) {
        _controller.text = _editing!['name'] ?? '';
        _avatar = _editing!['avatar'] ?? kStandardAvatar;
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isLocked(String avatar) =>
      !_premium.isPremium && avatar != kStandardAvatar;

  Future<void> _unlockAvatar(String avatar) async {
    final unlocked = await showPaywall(context, PaywallTrigger.avatars);
    if (unlocked && mounted) setState(() => _avatar = avatar);
  }

  void saveChild() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    // Keep a premium avatar chosen earlier even if Premium has lapsed.
    final avatar = _isLocked(_avatar) && _avatar != _editing?['avatar']
        ? kStandardAvatar
        : _avatar;

    if (_editing == null) {
      await _db.insertChild(name, avatar: avatar);
    } else {
      await _db.updateChild(_editing!['id'], name, avatar);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? "Add Child" : "Edit Child"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "Child Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text("Avatar", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _premium,
            builder: (context, _) => EmojiPicker(
              options: kAvatars,
              selected: _avatar,
              isLocked: _isLocked,
              onSelected: (a) => setState(() => _avatar = a),
              onLockedTap: _unlockAvatar,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: saveChild, child: const Text("Save")),
        ],
      ),
    );
  }
}
