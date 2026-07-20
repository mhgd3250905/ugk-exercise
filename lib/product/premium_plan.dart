enum PremiumPlanId { monthly, annual }

class PremiumPlan {
  const PremiumPlan({required this.id, required this.price, int? freeTrialDays})
    : freeTrialDays = freeTrialDays == (id == PremiumPlanId.monthly ? 3 : 7)
          ? freeTrialDays
          : null;

  final PremiumPlanId id;
  final String price;
  final int? freeTrialDays;

  bool get hasFreeTrial => freeTrialDays != null;
}
