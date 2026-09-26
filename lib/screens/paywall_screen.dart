import 'package:flutter/material.dart';
import '../services/parental_gate.dart';
import '../services/premium_service.dart';

enum PaywallTrigger {
  addChild,
  addTask,
  addReward,
  reports,
  avatars,
  rewardIcons,
  readOnly,
  general,
}

class _PaywallCopy {
  final String title;
  final String subtitle;
  final List<String> highlights;
  const _PaywallCopy(this.title, this.subtitle, this.highlights);
}

// Screens 1–3 follow the requirements doc. Only features that exist in the
// app are listed, so we never sell something that isn't there yet.
const Map<PaywallTrigger, _PaywallCopy> _copy = {
  PaywallTrigger.addChild: _PaywallCopy(
    'Add another child',
    'The free plan includes 1 child profile.',
    [
      'Unlimited children profiles',
      'Unlimited tasks & rewards',
      'Weekly & monthly progress reports',
    ],
  ),
  PaywallTrigger.addTask: _PaywallCopy(
    'Unlock unlimited tasks',
    'The free plan includes 5 tasks per child per day.',
    [
      'Unlimited tasks every day',
      'Build detailed routines',
      'Better consistency with streak tracking',
    ],
  ),
  PaywallTrigger.addReward: _PaywallCopy(
    'Unlock unlimited rewards',
    'The free plan includes 3 rewards per child.',
    [
      'Unlimited rewards for every child',
      'Reward icons',
      'Unlimited children & tasks',
    ],
  ),
  PaywallTrigger.readOnly: _PaywallCopy(
    'Welcome back to Premium',
    'Your Premium plan has ended, so extra children, tasks and rewards are read-only.',
    [
      'Edit all your children again',
      'Unlimited tasks & rewards',
      'Weekly & monthly reports with streaks',
    ],
  ),
  PaywallTrigger.reports: _PaywallCopy(
    'Weekly reports & insights',
    'See how your kids are doing over time.',
    [
      'Weekly & monthly progress reports',
      'Streaks and completion stats',
      'Celebrate progress together',
    ],
  ),
  PaywallTrigger.avatars: _PaywallCopy(
    'Unlock all avatars',
    'The free plan includes 1 standard avatar.',
    [
      'All avatars for every child',
      'Unlimited children profiles',
      'Reward icons',
    ],
  ),
  PaywallTrigger.rewardIcons:
      _PaywallCopy('Make rewards fun', 'Give every reward its own icon.', [
        'Reward icons',
        'Unlimited children & tasks',
        'Weekly & monthly progress reports',
      ]),
  PaywallTrigger.general: _PaywallCopy(
    'Go Premium',
    'Everything you need to build great routines.',
    [
      'Unlimited children, tasks & rewards',
      'All avatars & reward icons',
      'Weekly & monthly reports with streaks',
    ],
  ),
};

/// Opens the paywall and returns whether Premium is active afterwards.
Future<bool> showPaywall(BuildContext context, PaywallTrigger trigger) async {
  if (PremiumService.instance.isPremium) return true;

  await Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(trigger: trigger),
    ),
  );
  return PremiumService.instance.isPremium;
}

class PaywallScreen extends StatelessWidget {
  final PaywallTrigger trigger;

  const PaywallScreen({super.key, required this.trigger});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PaywallContent(
        trigger: trigger,
        onPremium: () => Navigator.pop(context),
      ),
    );
  }
}

class PaywallContent extends StatefulWidget {
  final PaywallTrigger trigger;
  final VoidCallback? onPremium;

  const PaywallContent({super.key, required this.trigger, this.onPremium});

  @override
  State<PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends State<PaywallContent> {
  final PremiumService _premium = PremiumService.instance;
  String _selectedPlan = kPremiumYearlyId;
  bool _welcomed = false;

  @override
  void initState() {
    super.initState();
    _premium.addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    _premium.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    setState(() {});
    if (_premium.isPremium && !_welcomed) {
      _welcomed = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Welcome to Premium! 🎉')));
      widget.onPremium?.call();
    }
  }

  Future<void> _continue() async {
    final parentOk = await ParentalGate.instance.requireParent(
      context,
      reason: 'Purchases need a parent. Enter your PIN to continue.',
    );
    if (parentOk) await _premium.buy(_selectedPlan);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy[widget.trigger]!;
    final colors = Theme.of(context).colorScheme;
    final trialDays = _premium.yearlyTrialDays;
    final trialSelected =
        trialDays != null && _selectedPlan == kPremiumYearlyId;
    final savings = 'Save ${_premium.yearlySavingsPercent}%';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Icon(Icons.workspace_premium, size: 64, color: colors.primary),
        const SizedBox(height: 12),
        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(copy.subtitle, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ...copy.highlights.map(
          (h) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(h, style: const TextStyle(fontSize: 16))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _PlanCard(
          title: 'Yearly',
          price: trialDays != null
              ? '$trialDays days free, then ${_premium.yearlyPrice} / year'
              : '${_premium.yearlyPrice} / year',
          badge: trialDays != null ? 'Free trial' : savings,
          selected: _selectedPlan == kPremiumYearlyId,
          onTap: () => setState(() => _selectedPlan = kPremiumYearlyId),
        ),
        const SizedBox(height: 10),
        _PlanCard(
          title: 'Monthly',
          price: '${_premium.monthlyPrice} / month',
          selected: _selectedPlan == kPremiumMonthlyId,
          onTap: () => setState(() => _selectedPlan = kPremiumMonthlyId),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _premium.purchasePending ? null : _continue,
          child: _premium.purchasePending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  trialSelected
                      ? 'Start $trialDays-day free trial'
                      : 'Continue',
                  style: const TextStyle(fontSize: 16),
                ),
        ),
        if (_premium.lastError != null) ...[
          const SizedBox(height: 12),
          Text(
            _premium.lastError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.error),
          ),
        ],
        TextButton(
          onPressed: _premium.restore,
          child: const Text('Restore purchases'),
        ),
        const SizedBox(height: 8),
        Text(
          trialSelected
              ? 'Free for $trialDays days, then ${_premium.yearlyPrice} per '
                    'year. Cancel anytime in Google Play > Payments & '
                    'subscriptions before the trial ends and you won\'t be '
                    'charged. Renews automatically until cancelled.'
              : 'Subscriptions renew automatically until cancelled. '
                    'Cancel anytime in Google Play > Payments & subscriptions.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.primary : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(price),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
