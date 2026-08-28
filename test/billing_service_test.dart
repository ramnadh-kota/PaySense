import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/config/pricing_config.dart';
import 'package:paysense/shared/services/billing/billing_models.dart';
import 'package:paysense/shared/services/billing/billing_service.dart';

void main() {
  group('StubBillingService', () {
    const service = StubBillingService();

    test('loadProducts mirrors PricingConfig.plans for display', () async {
      final products = await service.loadProducts();
      expect(products.length, PricingConfig.plans.length);
      for (final plan in PricingConfig.plans) {
        final product = products.firstWhere((p) => p.productId == plan.id);
        expect(product.formattedPrice, plan.formattedPrice);
      }
    });

    test('purchase never reports success — always productsUnavailable', () async {
      final result = await service.purchase(PricingConfig.defaultPlan.id);
      expect(result.status, PurchaseStatus.productsUnavailable);
      expect(result.status, isNot(PurchaseStatus.purchased));
      expect(result.message, isNotNull);
    });

    test('restorePurchases never fabricates a restored purchase', () async {
      final results = await service.restorePurchases();
      expect(results, isEmpty);
    });

    test('verifyAndGrantEntitlement always returns false — no backend exists to verify against', () async {
      final granted = await service.verifyAndGrantEntitlement('fake-token');
      expect(granted, isFalse);
    });
  });
}
