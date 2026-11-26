import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/http_client.dart';
import '../../core/utils/jwt_utils.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

const _unset = Object();

// ── DI Providers ──────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(client: ref.watch(httpClientProvider));
});

/// Shared HTTP client that retries once on HTTP 401 by refreshing the access
/// token. All remote datasources use this single client so connections are
/// pooled and expired tokens are retried transparently.
final httpClientProvider = Provider<http.Client>((ref) {
  final inner = http.Client();
  return RefreshingHttpClient(
    inner: inner,
    // `ref.read` is used inside the closure (called at request time, not
    // provider creation time) so Riverpod does not track
    // authNotifierProvider as a dependency of this provider — avoiding a
    // circular dependency through authRepositoryProvider.
    onRefresh: () async {
      final tokens =
          await ref.read(authNotifierProvider.notifier).silentRefresh();
      return tokens?.accessToken;
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDatasource: ref.watch(authRemoteDatasourceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

// ── State ─────────────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, reconnecting, error, requiresBusinessSelection }

/// User roles mirrored from the backend enum.
enum UserRole { owner, manager, cashier, waiter, unknown }

/// Represents a user's membership in a specific organization.
class UserBusinessMembership {
  final String organizationId;
  final String organizationName;
  final UserRole role;
  final String? branchId;

  const UserBusinessMembership({
    required this.organizationId,
    required this.organizationName,
    required this.role,
    this.branchId,
  });

  factory UserBusinessMembership.fromJson(Map<String, dynamic> json) {
    return UserBusinessMembership(
      organizationId: json['organizationId']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? 'Unknown Organization',
      role: _parseRole(json['role']?.toString() ?? 'unknown'),
      branchId: json['branchId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'organizationName': organizationName,
      'role': role.toString().split('.').last.toUpperCase(),
      if (branchId != null) 'branchId': branchId,
    };
  }
}

class UserRoleAssignment {
  final String businessId;
  final String? branchId;
  final UserRole role;

  UserRoleAssignment({
    required this.businessId,
    this.branchId,
    required this.role,
  });

  factory UserRoleAssignment.fromJson(Map<String, dynamic> json) {
    return UserRoleAssignment(
      businessId: json['businessId']?.toString() ?? '',
      branchId: json['branchId']?.toString(),
      role: _parseRole(json['role']?.toString() ?? 'unknown'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessId': businessId,
      'branchId': branchId,
      'role': role.toString().split('.').last.toUpperCase(),
    };
  }
}

extension UserRoleX on UserRole {
  /// True when this role can access management/admin features.
  bool get canManage =>
      this == UserRole.owner || this == UserRole.manager;

  /// True when this role can perform payment verifications.
  bool get canVerifyPayments =>
      this != UserRole.unknown;

  /// Staff Management Permissions
  bool get canAddStaff =>
      this == UserRole.owner;

  bool get canRemoveStaff =>
      this == UserRole.owner;

  bool get canAddManager =>
      this == UserRole.owner;

  bool get canRemoveManager =>
      this == UserRole.owner;

  /// Branch Management Permissions
  bool get canAddBranch =>
      this == UserRole.owner;

  bool get canEditBranch =>
      this == UserRole.owner;

  bool get canRemoveBranch =>
      this == UserRole.owner;

  bool get canViewAllBranches =>
      this == UserRole.owner;

  /// Payment Account Management Permissions
  bool get canAddPaymentAccount =>
      this == UserRole.owner;

  bool get canEditPaymentAccount =>
      this == UserRole.owner;

  bool get canRemovePaymentAccount =>
      this == UserRole.owner;

  /// Reports Permissions
  bool get canExportReports =>
      this == UserRole.owner;

  /// Payment Operations Permissions
  bool get canCapturePayment =>
      this != UserRole.unknown;

  String get label {
    switch (this) {
      case UserRole.owner:   return 'Owner';
      case UserRole.manager: return 'Manager';
      case UserRole.cashier: return 'Cashier';
      case UserRole.waiter:  return 'Waiter';
      case UserRole.unknown: return 'Unknown';
    }
  }
}

UserRole _parseRole(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'OWNER':   return UserRole.owner;
    case 'MANAGER': return UserRole.manager;
    case 'CASHIER': return UserRole.cashier;
    case 'WAITER':  return UserRole.waiter;
    default:        return UserRole.unknown;
  }
}

AuthTokens _tokensFromMap(Map<String, dynamic> data) {
  final accessToken = data['accessToken']?.toString();
  final refreshToken = data['refreshToken']?.toString();
  
  if (accessToken == null || refreshToken == null) {
    throw Exception('Missing access or refresh token in response');
  }
  
  final role = JwtUtils.extractRole(accessToken) ?? 'CASHIER';
  final orgId = JwtUtils.extractOrganizationId(accessToken) ?? '';

  return AuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    role: role,
    organizationId: orgId,
  );
}

class AuthState {
  final AuthStatus status;
  final AuthTokens? tokens;
  final UserRole role;
  final String? errorMessage;
  final User? user;
  final Organization? organization;
  final Subscription? subscription;
  final List<UserRoleAssignment> roles;
  final List<UserBusinessMembership> availableOrganizations;
  final User? pendingUser;
  final String? pendingSelectionToken;
  final String? currentBranchId;

  const AuthState({
    required this.status,
    this.tokens,
    this.role = UserRole.unknown,
    this.errorMessage,
    this.user,
    this.organization,
    this.subscription,
    this.roles = const [],
    this.availableOrganizations = const [],
    this.pendingUser,
    this.pendingSelectionToken,
    this.currentBranchId,
  });

  /// Convenience: is the user currently logged in?
  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthTokens? tokens,
    UserRole? role,
    String? errorMessage,
    User? user,
    Organization? organization,
    Subscription? subscription,
    List<UserRoleAssignment>? roles,
    List<UserBusinessMembership>? availableOrganizations,
    Object? pendingUser = _unset,
    Object? pendingSelectionToken = _unset,
    String? currentBranchId,
  }) {
    return AuthState(
      status: status ?? this.status,
      tokens: tokens ?? this.tokens,
      role: role ?? this.role,
      errorMessage: errorMessage,   // always replace (null clears the error)
      user: user ?? this.user,
      organization: organization ?? this.organization,
      subscription: subscription ?? this.subscription,
      roles: roles ?? this.roles,
      availableOrganizations: availableOrganizations ?? this.availableOrganizations,
      pendingUser: identical(pendingUser, _unset)
          ? this.pendingUser
          : pendingUser as User?,
      pendingSelectionToken: identical(pendingSelectionToken, _unset)
          ? this.pendingSelectionToken
          : pendingSelectionToken as String?,
      currentBranchId: currentBranchId ?? this.currentBranchId,
    );
  }

  /// Unauthenticated initial state used on logout / error recovery.
  static const unauthenticated = AuthState(
    status: AuthStatus.unauthenticated,
    role: UserRole.unknown,
    user: null,
    organization: null,
    roles: [],
    availableOrganizations: [],
    pendingUser: null,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  Timer? _refreshTimer;
  Future<Subscription?>? _subscriptionRefresh;

  AuthNotifier(this._ref)
      : super(const AuthState(status: AuthStatus.initial)) {
    _restoreSession();
    // Keep the short-lived access token fresh while the app is open instead
    // of waiting for a request to fail with 401 once the 15-minute JWT lapses.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.status == AuthStatus.authenticated) {
        ensureFreshAccessToken();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  // ── Session restore on app start ─────────────────────────────────────────

  /// Upper bound on the whole restore (secure-storage read + token refresh +
  /// `/auth/me`). Startup must never wait on an unreachable backend: without
  /// this cap a stored session plus a dead server left the app on a blank
  /// screen for the full HTTP timeout (30s per call, twice).
  static const Duration _restoreTimeout = Duration(seconds: 8);

  Future<void>? _restoreInFlight;
  int _sessionGeneration = 0;

  Future<void> _restoreSession() async {
    final pending = _restoreInFlight;
    if (pending != null) return pending;

    final future = _restoreSessionOnce();
    _restoreInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_restoreInFlight, future)) _restoreInFlight = null;
    }
  }

  Future<void> _restoreSessionOnce() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final restored = await _restoreStoredSession().timeout(
          _restoreTimeout,
        );
        state = restored ?? AuthState.unauthenticated;
        return;
      } on TimeoutException {
        debugPrint('[Auth] session restore attempt ${attempt + 1} timed out');
      } catch (e) {
        if (!_isTransientError(e)) {
          debugPrint('[Auth] session restore rejected: $e');
          _sessionGeneration++;
          await _repo.clearTokens();
          state = AuthState.unauthenticated;
          return;
        }
        debugPrint(
          '[Auth] session restore attempt ${attempt + 1} failed (transient): $e',
        );
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    // Connectivity failed, but the stored session is still intact. Keep it
    // and let the user retry instead of forcing them to re-enter credentials.
    state = const AuthState(status: AuthStatus.reconnecting);
  }

  /// Retries restoring the stored session after a connectivity failure.
  Future<void> retryRestore() => _restoreSession();

  /// Reads the persisted session and validates it against the backend.
  /// Returns the authenticated state, or `null` when there is nothing stored.
  Future<AuthState?> _restoreStoredSession() async {
    final tokens = await _repo.getTokens();
    if (tokens == null) return null;

    // Proactively refresh if the access token is about to expire
    AuthTokens finalTokens;
    if (JwtUtils.isExpired(tokens.accessToken)) {
      debugPrint('[Auth] access token expired on restore — refreshing');
      final refreshed = await _refreshTokensSingleFlight(storedTokens: tokens);
      if (refreshed == null) return null;
      finalTokens = refreshed;
    } else {
      finalTokens = tokens;
    }

    // Fetch user and organization
    final userAndOrg = await _fetchUserAndOrganization(finalTokens.accessToken);
    return _authenticatedState(
      finalTokens,
      user: userAndOrg['user'],
      organization: userAndOrg['organization'],
      subscription: userAndOrg['subscription'],
    );
  }

  Future<Map<String, dynamic>> _fetchUserAndOrganization(String accessToken) async {
    final data = await _repo.getMe(accessToken);
    final user = data['user'] != null 
        ? User.fromJson(data['user'] as Map<String, dynamic>) 
        : null;
    final organization = data['organization'] != null 
        ? Organization.fromJson(data['organization'] as Map<String, dynamic>) 
        : null;
    final subscription = _parseSubscription(data['subscription']);
    return {
      'user': user,
      'organization': organization,
      'subscription': subscription,
    };
  }

  // ── Password Login ───────────────────────────────────────────────────────

  Future<void> loginWithPassword(
    String identifier,
    String password, {
    String? organizationId,
    bool rememberMe = true,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      // Persist tokens only when "Remember me" is checked.
      await _repo.setSessionOnly(!rememberMe);
      if (rememberMe) {
        await _repo.saveRememberedLogin(identifier);
      } else {
        await _repo.forgetRememberedLogin();
      }
      final data = await _repo.loginWithPassword(
        identifier,
        password,
        organizationId: organizationId,
        rememberMe: rememberMe,
      );
      // Check if multi-business selection is required
      if (data['requiresBusinessSelection'] == true) {
        final businesses = (data['businesses'] as List<dynamic>)
            .map((b) => UserBusinessMembership.fromJson(b as Map<String, dynamic>))
            .toList();
        final pendingUser = data['user'] != null 
            ? User.fromJson(data['user'] as Map<String, dynamic>) 
            : null;
        state = state.copyWith(
          status: AuthStatus.requiresBusinessSelection,
          availableOrganizations: businesses,
          pendingUser: pendingUser,
          pendingSelectionToken: data['selectionToken']?.toString(),
          errorMessage: null,
        );
        return;
      }

      await _completeLogin(data);
    } catch (e) {
      debugPrint('[Auth] Login error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  /// Shared completion for login flows: parses tokens/user/org from the
  /// response payload and transitions to the authenticated state.
  Future<void> _completeLogin(Map<String, dynamic> data) async {
    final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
    final user = data['user'] != null 
        ? User.fromJson(data['user'] as Map<String, dynamic>) 
        : null;
    final org = data['organization'] != null 
        ? Organization.fromJson(data['organization'] as Map<String, dynamic>) 
        : null;
    final subscription = _parseSubscription(data['subscription']);
    final rolesList = (data['roles'] as List<dynamic>?) 
        ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
        .toList() ?? [];
    
    final userAndOrg = org != null 
        ? {'organization': org} 
        : await _fetchUserAndOrganization(tokens.accessToken);
    state = _authenticatedState(
      tokens, 
      user: user, 
      organization: userAndOrg['organization'],
      subscription: subscription ?? userAndOrg['subscription'],
      roles: rolesList,
    );
  }

  // ── Select Business (for multi-org users) ─────────────────────────────────

  Future<void> selectBusiness(String organizationId) async {
    final selectionToken = state.pendingSelectionToken;
    if (selectionToken == null || selectionToken.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Business selection session is missing. Please log in again.',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final rememberMe = await _repo.getRememberMe();
      final data = await _repo.selectBusiness(
        selectionToken: selectionToken,
        organizationId: organizationId,
        rememberMe: rememberMe,
      );
      _applySelectedBusiness(data, state.availableOrganizations);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── In-app: Switch to another existing organization ───────────────────────

  Future<void> switchBusiness(String organizationId) async {
    if (state.tokens == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'User not authenticated',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final accessToken = await ensureFreshAccessToken();
      if (accessToken == null) {
        throw Exception('Session expired. Please log in again.');
      }
      // A selection challenge is single-use, so in-app switching needs a new
      // one issued for the currently authenticated user.
      final challenge = await _repo.getBusinessSelectionChallenge(accessToken);
      final selectionToken = challenge['selectionToken']?.toString();
      if (selectionToken == null || selectionToken.isEmpty) {
        throw Exception('Could not start business switch. Please try again.');
      }
      final rememberMe = await _repo.getRememberMe();
      final data = await _repo.selectBusiness(
        selectionToken: selectionToken,
        organizationId: organizationId,
        rememberMe: rememberMe,
      );
      final challengeBusinesses =
          (challenge['businesses'] as List<dynamic>?)
              ?.map(
                (b) => UserBusinessMembership.fromJson(
                  b as Map<String, dynamic>,
                ),
              )
              .toList() ??
          state.availableOrganizations;
      _applySelectedBusiness(data, challengeBusinesses);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  void _applySelectedBusiness(
    Map<String, dynamic> data,
    List<UserBusinessMembership> organizations,
  ) {
    final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
    final user = data['user'] != null
        ? User.fromJson(data['user'] as Map<String, dynamic>)
        : state.user ?? state.pendingUser;
    final org = data['organization'] != null
        ? Organization.fromJson(data['organization'] as Map<String, dynamic>)
        : null;
    final subscription = _parseSubscription(data['subscription']);
    final rolesList = (data['roles'] as List<dynamic>?)
        ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
        .toList();

    state = _authenticatedState(
      tokens,
      user: user,
      organization: org,
      subscription: subscription,
      roles: rolesList,
      availableOrganizations: organizations,
    );
  }

  // ── Owner registration (step 1: create account → email OTP) ───────────────

  Future<bool> register({
    required String name,
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    String? type,
    String? city,
    String? country,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repo.register(
        name: name,
        fullName: fullName,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
        type: type,
        city: city,
        country: country,
      );
      state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
      return false;
    }
  }

  // ── Verify email (step 2: OTP → login) ──────────────────────────────────────

  Future<void> verifyEmail({
    required String email,
    required String otpCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final data = await _repo.verifyEmail(email: email, otpCode: otpCode);
      await _completeLogin(data);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Resend verification OTP ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> resendVerification(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _repo.resendVerification(email);
      state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
      return result;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
      return {'message': ''};
    }
  }

  // ── Staff activation (email OTP for QR-invited staff) ───────────────────────

  Future<void> sendStaffActivationOtp({
    required String email,
    String? token,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repo.staffActivationOtp(email: email, token: token);
      state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Silent token refresh (called by API layer when a 401 is received) ────

  Future<AuthTokens?> silentRefresh() async {
    final pending = _refreshInFlight;
    if (pending != null) {
      try {
        return await pending;
      } catch (e) {
        return _handleRefreshError(e);
      }
    }

    try {
      return await _refreshTokensSingleFlight();
    } catch (e) {
      return _handleRefreshError(e);
    }
  }

  Future<AuthTokens?> _refreshTokensSingleFlight({
    AuthTokens? storedTokens,
  }) async {
    final pending = _refreshInFlight;
    if (pending != null) return pending;

    final future = _refreshTokens(storedTokens);
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  Future<AuthTokens?> _handleRefreshError(Object e) async {
    if (_isTransientError(e)) {
      debugPrint('[Auth] silent refresh failed (transient), keeping session: $e');
      return null;
    }
    debugPrint('[Auth] silent refresh rejected, clearing session: $e');
    _sessionGeneration++;
    await _repo.clearTokens();
    state = AuthState.unauthenticated;
    return null;
  }

  /// Returns a valid access token, silently refreshing first when the current
  /// one is expired (or expiring within the buffer). Use this for EVERY
  /// authenticated request instead of reading `tokens.accessToken` directly —
  /// otherwise calls fail with "session has expired" whenever the short-lived
  /// access token (15 min) lapses between user actions.
  Future<String?> ensureFreshAccessToken() async {
    final tokens = state.tokens;
    if (tokens == null) return null;
    if (!JwtUtils.isExpired(tokens.accessToken, bufferSeconds: 60)) {
      return tokens.accessToken;
    }
    debugPrint('[Auth] access token expired/expiring — silent refresh before request');
    final refreshed = await silentRefresh();
    // Keep the existing token on transient failure so callers never crash on a
    // null token; the next retry or timer tick will refresh it.
    return refreshed?.accessToken ?? tokens.accessToken;
  }

  Future<AuthTokens?>? _refreshInFlight;

  Future<AuthTokens?> _refreshTokens(AuthTokens? storedTokens) async {
    final current = state.tokens ?? storedTokens ?? await _repo.getTokens();
    if (current == null) return null;

    final generation = _sessionGeneration;
    final startedAuthenticated = state.status == AuthStatus.authenticated;
    final startedRefreshToken = state.tokens?.refreshToken;

    final refreshData = await _repo.refreshToken(current.refreshToken);
    final refreshedTokens = _tokensFromMap(refreshData['tokens'] as Map<String, dynamic>);

    final tokenChanged =
        startedAuthenticated && state.tokens?.refreshToken != startedRefreshToken;
    final anotherLogin = !startedAuthenticated &&
        state.status == AuthStatus.authenticated &&
        state.tokens?.refreshToken != refreshedTokens.refreshToken;
    final sessionChanged = generation != _sessionGeneration || tokenChanged || anotherLogin;
    if (sessionChanged) {
      debugPrint('[Auth] refresh result discarded — session changed');
      return null;
    }

    final roles = (refreshData['roles'] as List<dynamic>?)
        ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
        .toList();
    state = _authenticatedState(
      refreshedTokens,
      roles: roles ?? state.roles,
      availableOrganizations: state.availableOrganizations,
      branchId: state.currentBranchId,
    );
    return refreshedTokens;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      if (state.tokens != null) {
        await _repo.logout(state.tokens!.refreshToken);
      }
    } catch (e) {
      debugPrint('[Auth] logout server revocation failed — local session still cleared: $e');
    } finally {
      // Repeated/offline logout must never leave a stored session behind.
      _sessionGeneration++;
      await _repo.clearTokens();
      state = AuthState.unauthenticated;
    }
  }

  // ── Clear Error ───────────────────────────────────────────────────────────

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = state.copyWith(
        status: AuthStatus.initial,
        errorMessage: null,
      );
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────────

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repo.forgotPassword(email);
      state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  Future<void> resetPassword(
    String email,
    String otpCode,
    String newPassword,
  ) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repo.resetPassword(email, otpCode, newPassword);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Activate Invitation (QR flow: no auto-login) ──────────────────────────

  Future<Map<String, dynamic>> activateInvitation({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final data = await _repo.activateInvitation(
        token: token,
        password: password,
        confirmPassword: confirmPassword,
      );
      state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
      return data;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
      return {'message': ''};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  AuthState _authenticatedState(
    AuthTokens tokens, {
    User? user,
    Organization? organization,
    Subscription? subscription,
    List<UserRoleAssignment>? roles,
    List<UserBusinessMembership>? availableOrganizations,
    String? branchId,
  }) =>
      AuthState(
        status: AuthStatus.authenticated,
        tokens: tokens,
        role: _parseRole(tokens.role),
        user: user ?? state.user,
        organization: organization ?? state.organization,
        subscription: subscription ?? state.subscription,
        roles: roles ?? state.roles,
        availableOrganizations: availableOrganizations ?? state.availableOrganizations,
        currentBranchId:
            JwtUtils.extractBranchId(tokens.accessToken) ?? branchId ?? state.currentBranchId,
      );

  Subscription? _parseSubscription(dynamic value) {
    if (value == null) return null;
    if (value is Subscription) return value;
    if (value is Map) {
      return Subscription.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  /// Re-fetch the latest subscription from the server after a renewal/payment.
  Future<Subscription?> refreshSubscription() {
    final pending = _subscriptionRefresh;
    if (pending != null) return pending;

    final future = _refreshSubscription();
    _subscriptionRefresh = future;
    future.whenComplete(() {
      if (identical(_subscriptionRefresh, future)) {
        _subscriptionRefresh = null;
      }
    });
    return future;
  }

  Future<Subscription?> _refreshSubscription() async {
    final token = await ensureFreshAccessToken();
    if (token == null) return state.subscription;
    try {
      final data = await _repo.getMe(token);
      final subscription = _parseSubscription(data['subscription']);
      state = state.copyWith(subscription: subscription);
      return subscription;
    } catch (e) {
      debugPrint('[Auth] Subscription refresh failed: $e');
      return state.subscription;
    }
  }

  /// Network loss, DNS failures, timeouts and server errors are recoverable:
  /// the refresh token may still be valid, so never wipe the session for them.
  /// A 4xx from the auth endpoint means the session itself is no longer valid.
  bool _isTransientError(Object e) {
    if (e is ApiException) {
      final code = e.statusCode;
      if (code == null) return true;
      if (code == 429) return true;
      return code >= 500;
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('failed host lookup') ||
        msg.contains('handshake');
  }

  String _friendly(Object e) {
    if (e is ApiException) return e.message;
    final msg = e.toString();
    // Strip the "Exception: " prefix Flutter adds
    if (msg.startsWith('Exception: ')) return msg.substring(11);
    
    // Convert common technical errors to user-friendly messages
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Unable to connect to server. Please check your internet connection.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please check your network connection.';
    }
    if (msg.contains('HTTP 500') || msg.contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    }
    if (msg.contains('HTTP 401') || msg.contains('Unauthorized')) {
      return 'Please log in to continue.';
    }
    if (msg.contains('HTTP 403') || msg.contains('Forbidden')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('HTTP 404') || msg.contains('Not Found')) {
      return 'Resource not found. Please try again.';
    }
    
    return msg;
  }
}
