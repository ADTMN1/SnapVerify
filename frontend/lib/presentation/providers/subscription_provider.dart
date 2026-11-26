import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/subscription_remote_datasource.dart';
import '../../domain/entities/subscription_checkout.dart';
import '../../domain/entities/subscription_plan.dart';
import 'auth_provider.dart';

final subscriptionRemoteDatasourceProvider =
    Provider<SubscriptionRemoteDatasource>(
      (ref) => SubscriptionRemoteDatasource(client: ref.watch(httpClientProvider)),
    );

class SubscriptionCheckoutState {
  final bool isLoading;
  final List<SubscriptionPlan> plans;
  final SubscriptionCheckout? checkout;
  final bool verified;
  final String? error;

  const SubscriptionCheckoutState({
    this.isLoading = false,
    this.plans = const [],
    this.checkout,
    this.verified = false,
    this.error,
  });

  SubscriptionCheckoutState copyWith({
    bool? isLoading,
    List<SubscriptionPlan>? plans,
    SubscriptionCheckout? checkout,
    bool? verified,
    String? error,
    bool clearCheckout = false,
    bool clearError = false,
  }) {
    return SubscriptionCheckoutState(
      isLoading: isLoading ?? this.isLoading,
      plans: plans ?? this.plans,
      checkout: clearCheckout ? null : checkout ?? this.checkout,
      verified: verified ?? this.verified,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final subscriptionCheckoutProvider =
    StateNotifierProvider<
      SubscriptionCheckoutNotifier,
      SubscriptionCheckoutState
    >((ref) {
      return SubscriptionCheckoutNotifier(ref);
    });

class SubscriptionCheckoutNotifier
    extends StateNotifier<SubscriptionCheckoutState> {
  SubscriptionCheckoutNotifier(this._ref)
    : super(const SubscriptionCheckoutState());

  final Ref _ref;

  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _token();
      if (token == null) return;
      final plans = await _ref
          .read(subscriptionRemoteDatasourceProvider)
          .getPlans(token);
      state = state.copyWith(isLoading: false, plans: plans);
    } catch (e) {
      debugPrint('[Subscription] loadPlans failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  Future<bool> activateFree() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _token();
      if (token == null) return false;
      await _ref.read(subscriptionRemoteDatasourceProvider).activateFree(token);
      await _ref.read(authNotifierProvider.notifier).refreshSubscription();
      state = const SubscriptionCheckoutState();
      return true;
    } catch (e) {
      debugPrint('[Subscription] activateFree failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  Future<void> startCheckout(String planId) async {
    final authState = _ref.read(authNotifierProvider);
    if (authState.role != UserRole.owner) {
      state = state.copyWith(
        error: 'Only the business owner can purchase a subscription plan.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _token();
      if (token == null) return;
      final checkout = await _ref
          .read(subscriptionRemoteDatasourceProvider)
          .createCheckout(token, planId);
      state = state.copyWith(isLoading: false, checkout: checkout);
    } catch (e) {
      debugPrint('[Subscription] startCheckout failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  Future<bool> verifyWithScreenshot(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    String? ocrText,
  }) async {
    final checkout = state.checkout;
    if (checkout == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _token();
      if (token == null) return false;
      await _ref
          .read(subscriptionRemoteDatasourceProvider)
          .verifyCheckoutByImage(
            token,
            checkout.id,
            imageBytes,
            mimeType: mimeType,
            ocrText: ocrText,
          );
      final subscription = await _ref
          .read(authNotifierProvider.notifier)
          .refreshSubscription();
      final active = subscription?.isActive ?? false;
      state = state.copyWith(isLoading: false, verified: active);
      if (!active) {
        state = state.copyWith(
          error: 'Payment was accepted but the subscription is not active yet.',
        );
      }
      return active;
    } catch (e) {
      debugPrint('[Subscription] verify failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  void reset() {
    state = const SubscriptionCheckoutState();
  }

  Future<String?> _token() async {
    final token = await _ref
        .read(authNotifierProvider.notifier)
        .ensureFreshAccessToken();
    if (token == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Your session expired. Please log in again.',
      );
    }
    return token;
  }
}
