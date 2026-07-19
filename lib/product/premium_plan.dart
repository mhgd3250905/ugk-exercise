enum PremiumPlanId { monthly, annual }

class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.price,
    this.freeTrialDays,
  });

  final PremiumPlanId id;
  final String price;
  final int? freeTrialDays;

  bool get hasFreeTrial => freeTrialDays != null;
}
