import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/jwt_utils.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/organization.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';

// ── DI Providers ──────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(client: http.Client());
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDatasource: ref.watch(authRemoteDatasourceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

// ── State ─────────────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// User roles mirrored from the backend enum.
enum UserRole { owner, manager, cashier, waiter, unknown }

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
      businessId: json['businessId'] as String,
      branchId: json['branchId'] as String?,
      role: _parseRole(json['role'] as String),
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

  /// QR Code Management Permissions
  bool get canGenerateQRCode =>
      this == UserRole.owner;

  bool get canManageQRCode =>
      this == UserRole.owner;

  bool get canViewQRCode =>
      this != UserRole.unknown;

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
  final accessToken = data['accessToken'] as String;
  final refreshToken = data['refreshToken'] as String;
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
  final List<UserRoleAssignment> roles;

  const AuthState({
    required this.status,
    this.tokens,
    this.role = UserRole.unknown,
    this.errorMessage,
    this.user,
    this.organization,
    this.roles = const [],
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
    List<UserRoleAssignment>? roles,
  }) {
    return AuthState(
      status: status ?? this.status,
      tokens: tokens ?? this.tokens,
      role: role ?? this.role,
      errorMessage: errorMessage,   // always replace (null clears the error)
      user: user ?? this.user,
      organization: organization ?? this.organization,
      roles: roles ?? this.roles,
    );
  }

  /// Unauthenticated initial state used on logout / error recovery.
  static const unauthenticated = AuthState(
    status: AuthStatus.unauthenticated,
    role: UserRole.unknown,
    user: null,
    organization: null,
    roles: [],
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref)
      : super(const AuthState(status: AuthStatus.initial)) {
    _restoreSession();
  }

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  // ── Session restore on app start ─────────────────────────────────────────

  Future<void> _restoreSession() async {
    try {
      final tokens = await _repo.getTokens();
      if (tokens == null) {
        state = AuthState.unauthenticated;
        return;
      }

      // Proactively refresh if the access token is about to expire
      AuthTokens finalTokens;
      if (JwtUtils.isExpired(tokens.accessToken)) {
        dev.log('[Auth] access token expired on restore — refreshing');
        final refreshData = await _repo.refreshToken(tokens.refreshToken);
        finalTokens = _tokensFromMap(refreshData['tokens'] as Map<String, dynamic>);
      } else {
        finalTokens = tokens;
      }

      // Fetch user and organization
      final userAndOrg = await _fetchUserAndOrganization(finalTokens.accessToken);
      state = _authenticatedState(
        finalTokens, 
        user: userAndOrg['user'], 
        organization: userAndOrg['organization'],
      );
    } catch (e) {
      dev.log('[Auth] session restore failed: $e');
      await _repo.clearTokens();
      state = AuthState.unauthenticated;
    }
  }

  Future<Map<String, dynamic>> _fetchUserAndOrganization(String accessToken) async {
    final data = await _repo.getMe(accessToken);
    final user = data['user'] != null 
        ? User.fromJson(data['user'] as Map<String, dynamic>) 
        : null;
    final organization = data['organization'] != null 
        ? Organization.fromJson(data['organization'] as Map<String, dynamic>) 
        : null;
    return {'user': user, 'organization': organization};
  }

  // ── Send OTP ─────────────────────────────────────────────────────────────

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repo.sendOtp(phone);
      // Return to previous state (or unauthenticated) without triggering navigation
      state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Password Login ───────────────────────────────────────────────────────

  Future<void> loginWithPassword(
    String phone,
    String password, {
    String? organizationId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      dev.log('[Auth] Logging in with password for phone: $phone');
      final data = await _repo.loginWithPassword(
        phone,
        password,
        organizationId: organizationId,
      );
      dev.log('[Auth] Login data received: $data');
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      final user = data['user'] != null 
          ? User.fromJson(data['user'] as Map<String, dynamic>) 
          : null;
      final rolesList = (data['roles'] as List<dynamic>?) 
          ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
          .toList() ?? [];
      
      final userAndOrg = await _fetchUserAndOrganization(tokens.accessToken);
      state = _authenticatedState(
        tokens, 
        user: user, 
        organization: userAndOrg['organization'],
        roles: rolesList,
      );
    } catch (e, stackTrace) {
      dev.log('[Auth] Login error: $e', stackTrace: stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Verify OTP / Login ───────────────────────────────────────────────────

  Future<void> verifyOtp(
    String phone,
    String code, {
    String? organizationId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final data = await _repo.verifyOtp(
        phone,
        code,
        organizationId: organizationId,
      );
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      final user = data['user'] != null 
          ? User.fromJson(data['user'] as Map<String, dynamic>) 
          : null;
      final rolesList = (data['roles'] as List<dynamic>?) 
          ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
          .toList() ?? [];
      
      final userAndOrg = await _fetchUserAndOrganization(tokens.accessToken);
      state = _authenticatedState(
        tokens, 
        user: user, 
        organization: userAndOrg['organization'],
        roles: rolesList,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Register business ─────────────────────────────────────────────────────

  Future<void> createBusiness({
    required String name,
    required String fullName,
    required String phone,
    required String otpCode,
    required String password,
    String? email,
    String? address,
    String? type,
    String? city,
    String? country,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      dev.log('[Auth] Creating business...');
      final data = await _repo.createBusiness(
        name: name,
        fullName: fullName,
        phone: phone,
        otpCode: otpCode,
        password: password,
        email: email,
        address: address,
        type: type,
        city: city,
        country: country,
      );
      dev.log('[Auth] Business created! Data: $data');

      // Parse user, organization, and roles from response
      final user = data['user'] != null 
          ? User.fromJson(data['user'] as Map<String, dynamic>) 
          : null;
      final organization = data['organization'] != null 
          ? Organization.fromJson(data['organization'] as Map<String, dynamic>) 
          : null;
      final rolesList = (data['roles'] as List<dynamic>?) 
          ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
          .toList() ?? [];

      // Tokens are saved inside the repository; load them back to get role.
      final tokens = await _repo.getTokens();
      dev.log('[Auth] Tokens from getTokens: $tokens');
      if (tokens != null) {
        dev.log('[Auth] Setting authenticated state with tokens from storage');
        state = _authenticatedState(tokens, user: user, organization: organization, roles: rolesList);
      } else {
        // Fallback: parse from response if getTokens somehow returns null
        final raw = data['tokens'] as Map<String, dynamic>?;
        dev.log('[Auth] Tokens from response: $raw');
        if (raw != null) {
          final t = _tokensFromMap(raw);
          dev.log('[Auth] Setting authenticated state with tokens from response: $t');
          state = _authenticatedState(t, user: user, organization: organization, roles: rolesList);
        } else {
          dev.log('[Auth] No tokens found, setting unauthenticated');
          state = AuthState.unauthenticated;
        }
      }
    } catch (e) {
      dev.log('[Auth] Error creating business: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Silent token refresh (called by API layer when a 401 is received) ────

  Future<AuthTokens?> silentRefresh() async {
    final current = state.tokens;
    if (current == null) return null;

    try {
      final refreshData = await _repo.refreshToken(current.refreshToken);
      final refreshedTokens = _tokensFromMap(refreshData['tokens'] as Map<String, dynamic>);
      state = _authenticatedState(refreshedTokens, user: state.user, organization: state.organization, roles: state.roles);
      return refreshedTokens;
    } catch (e) {
      dev.log('[Auth] silent refresh failed: $e — logging out');
      await logout();
      return null;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      if (state.tokens != null) {
        await _repo.logout(state.tokens!.refreshToken);
      }
    } catch (e) {
      dev.log('[Auth] logout server revocation failed — token may remain active for up to 7 days: $e');
    } finally {
      state = AuthState.unauthenticated;
    }
  }

  // ── Clear Error ───────────────────────────────────────────────────────────

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = AuthState.unauthenticated;
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────────

  Future<void> resetPassword(String phone, String otpCode, String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repo.resetPassword(phone, otpCode, newPassword);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Activate Invitation ───────────────────────────────────────────────────

  Future<void> activateInvitation({
    required String phone,
    required String otpCode,
    required String fullName,
    required String password,
    required String organizationId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final data = await _repo.activateInvitation(
        phone: phone,
        otpCode: otpCode,
        fullName: fullName,
        password: password,
        organizationId: organizationId,
      );
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      final user = data['user'] != null
          ? User.fromJson(data['user'] as Map<String, dynamic>)
          : null;
      final rolesList = (data['roles'] as List<dynamic>?)
          ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
          .toList() ?? [];
      
      final userAndOrg = await _fetchUserAndOrganization(tokens.accessToken);
      state = _authenticatedState(
        tokens, 
        user: user, 
        organization: userAndOrg['organization'],
        roles: rolesList,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  AuthState _authenticatedState(AuthTokens tokens, {User? user, Organization? organization, List<UserRoleAssignment>? roles}) => AuthState(
        status: AuthStatus.authenticated,
        tokens: tokens,
        role: _parseRole(tokens.role),
        user: user,
        organization: organization,
        roles: roles ?? state.roles,
      );

  String _friendly(Object e) {
    final msg = e.toString();
    // Strip the "Exception: " prefix Flutter adds
    if (msg.startsWith('Exception: ')) return msg.substring(11);
    return msg;
  }
}
