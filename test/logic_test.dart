import 'package:flutter_test/flutter_test.dart';

import 'package:parentinghelper/services/parental_gate.dart';
import 'package:parentinghelper/services/subscription_offers.dart';
import 'package:parentinghelper/state/app_limits.dart';
import 'package:parentinghelper/state/routine_days.dart';

OfferPhase phase(int micros, String price, String period) => OfferPhase(
  priceMicros: micros,
  formattedPrice: price,
  billingPeriod: period,
);

void main() {
  group('subscription offers', () {
    const base = PlanOffer(
      productId: 'premium_yearly',
      offerId: null,
      phases: [
        OfferPhase(
          priceMicros: 19990000,
          formattedPrice: '\$19.99',
          billingPeriod: 'P1Y',
        ),
      ],
    );
    final trial = PlanOffer(
      productId: 'premium_yearly',
      offerId: 'free-trial',
      phases: [phase(0, 'Free', 'P1W'), phase(19990000, '\$19.99', 'P1Y')],
    );

    test('prefers the free-trial offer when Play returns one', () {
      final plan = selectPlan([base, trial])!;
      expect(plan.offer.offerId, 'free-trial');
      expect(plan.trialDays, 7);
      // Shows the price charged after the trial, not "Free".
      expect(plan.recurringPrice, '\$19.99');
    });

    test('falls back to the base plan when not eligible for a trial', () {
      final plan = selectPlan([base])!;
      expect(plan.offer.offerId, isNull);
      expect(plan.trialDays, isNull);
      expect(plan.recurringPrice, '\$19.99');
    });

    test('parses Play billing periods', () {
      expect(isoPeriodToDays('P7D'), 7);
      expect(isoPeriodToDays('P1W'), 7);
      expect(isoPeriodToDays('P1M'), 30);
      expect(isoPeriodToDays('bogus'), isNull);
    });
  });

  group('free plan limits after Premium lapses', () {
    test('keeps the oldest rows usable, whatever the list order', () {
      final rows = [
        {'id': 9},
        {'id': 2},
        {'id': 5},
        {'id': 7},
      ];
      expect(firstIds(rows, 3), {2, 5, 7});
      expect(firstIds(rows, FREE_MAX_CHILDREN), {2});
    });
  });

  group('routine days', () {
    test('weekday bitmask', () {
      expect(includesWeekday(kWeekdays, DateTime.monday), isTrue);
      expect(includesWeekday(kWeekdays, DateTime.saturday), isFalse);
      expect(includesWeekday(kWeekends, DateTime.sunday), isTrue);
      expect(toggleWeekday(0, DateTime.wednesday), 1 << 2);
    });

    test('describes days', () {
      expect(describeDays(kEveryDay), 'Every day');
      expect(describeDays(kWeekdays), 'Weekdays');
      expect(describeDays(0x05), 'Mon, Wed');
    });
  });

  group('parent PIN', () {
    test('hash depends on PIN and salt, never stores the PIN', () {
      final h = hashPin('1234', 'salt-a');
      expect(h, isNot(contains('1234')));
      expect(hashPin('1234', 'salt-a'), h);
      expect(hashPin('1235', 'salt-a'), isNot(h));
      expect(hashPin('1234', 'salt-b'), isNot(h));
    });
  });
}
