enum PremiumPlanId { monthly, annual }

class PremiumPlan {
  const PremiumPlan({required this.id, required this.price});

  final PremiumPlanId id;
  final String price;
}
