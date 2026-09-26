// Picks which Google Play subscription offer to show and buy.
//
// Play returns one entry per offer for each subscription, all with the same
// product ID: the base plan, plus e.g. a 7-day free trial offer. Google only
// returns offers the user is eligible for, so if a free-trial offer is
// present we show and buy it; otherwise the base plan.

class OfferPhase {
  final int priceMicros;
  final String formattedPrice;
  final String billingPeriod; // ISO 8601, e.g. P7D, P1W, P1M, P1Y
  final int billingCycleCount;

  const OfferPhase({
    required this.priceMicros,
    required this.formattedPrice,
    required this.billingPeriod,
    this.billingCycleCount = 1,
  });

  bool get isFree => priceMicros == 0;
}

class PlanOffer {
  final String productId;
  final String? offerId; // null for the base plan
  final List<OfferPhase> phases;
  final Object? source; // the store's ProductDetails, used to buy

  const PlanOffer({
    required this.productId,
    required this.offerId,
    required this.phases,
    this.source,
  });

  bool get hasFreeTrial =>
      phases.length > 1 && phases.first.isFree && !phases.last.isFree;
}

class SelectedPlan {
  final PlanOffer offer;
  const SelectedPlan(this.offer);

  /// The price charged after any trial, e.g. "$19.99".
  String get recurringPrice => offer.phases.last.formattedPrice;
  double get recurringRawPrice => offer.phases.last.priceMicros / 1000000.0;

  /// Length of the free trial in days, or null if there isn't one.
  int? get trialDays {
    if (!offer.hasFreeTrial) return null;
    final phase = offer.phases.first;
    final days = isoPeriodToDays(phase.billingPeriod);
    return days == null ? null : days * phase.billingCycleCount;
  }
}

SelectedPlan? selectPlan(List<PlanOffer> offers) {
  final usable = offers.where((o) => o.phases.isNotEmpty).toList();
  if (usable.isEmpty) return null;

  for (final o in usable) {
    if (o.hasFreeTrial) return SelectedPlan(o);
  }
  return SelectedPlan(
    usable.firstWhere((o) => o.offerId == null, orElse: () => usable.first),
  );
}

/// Converts Play's billing periods (P7D, P1W, P1M, P1Y) to days.
int? isoPeriodToDays(String period) {
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(period);
  if (match == null) return null;
  final n = int.parse(match.group(1)!);
  return switch (match.group(2)) {
    'D' => n,
    'W' => n * 7,
    'M' => n * 30,
    'Y' => n * 365,
    _ => null,
  };
}
