import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/jwt_utils.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Storage keys — kept private to this file.
const _kAccessToken = 'sv_access_token';
const _kRefreshToken = 'sv_refresh_token';
const _kRememberedLogin = 'sv_remembered_login';
const _kRememberMe = 'sv_remember_me';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;
  final FlutterSecureStorage secureStorage;

  // When true (user unchecked "Remember me"), tokens live only in the
  // in-memory auth state and are never written to secure storage — a fresh
  // app start lands on the login screen.
  bool _sessionOnly = false;

  AuthRepositoryImpl({
    required this.remoteDatasource,
    required this.secureStorage,
  });

  // ── Password Login ─────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> loginWithPassword(
    String identifier,
    String password, {
    String? organizationId,
    required bool rememberMe,
  }) async {
    final data = await remoteDatasource.loginWithPassword(
      identifier,
      password,
      organizationId: organizationId,
      rememberMe: rememberMe,
    );
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
      await setRememberMe(rememberMe);
    }
    return data;
  }

  // ── Owner registration (email verification) ────────────────────────────────

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    String? type,
    String? city,
    String? country,
  }) {
    return remoteDatasource.register(
      name: name,
      fullName: fullName,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      type: type,
      city: city,
      country: country,
    );
  }

  @override
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otpCode,
  }) async {
    final data = await remoteDatasource.verifyEmail(
      email: email,
      otpCode: otpCode,
    );
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> resendVerification(String email) {
    return remoteDatasource.resendVerification(email);
  }

  @override
  Future<void> forgotPassword(String email) {
    return remoteDatasource.forgotPassword(email);
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> refreshToken(String currentRefreshToken) async {
    final data = await remoteDatasource.refreshToken(currentRefreshToken);
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
    }
    return data;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await remoteDatasource.logout(refreshToken);
    } finally {
      // Best-effort revocation: an unreachable server must never leave a
      // locally valid session that would be restored on the next cold start.
      await clearTokens();
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────────

  @override
  Future<void> resetPassword(String email, String otpCode, String newPassword) {
    return remoteDatasource.resetPassword(email, otpCode, newPassword);
  }

  // ── Invitation Management ─────────────────────────────────────────────────

  @override
  Future<List<dynamic>> checkInvitation(String token, {String? phone}) {
    return remoteDatasource.checkInvitation(token, phone: phone);
  }

  @override
  Future<void> staffActivationOtp({required String email, String? token}) {
    return remoteDatasource.staffActivationOtp(email: email, token: token);
  }

  @override
  Future<List<dynamic>> getInvitations(String phone, String accessToken) {
    return remoteDatasource.getInvitations(phone, accessToken);
  }

  @override
  Future<Map<String, dynamic>> activateInvitation({
    required String token,
    required String password,
    required String confirmPassword,
  }) {
    // QR flow: no tokens are issued — staff logs in with username + password.
    return remoteDatasource.activateInvitation(
      token: token,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  @override
  Future<Map<String, dynamic>> getMe(String accessToken) {
    return remoteDatasource.getMe(accessToken);
  }

  // ── Staff Management ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> addStaff(String accessToken, {
    required String fullName,
    required String username,
    required String role,
    String? branchId,
  }) {
    return remoteDatasource.addStaff(
      accessToken,
      fullName: fullName,
      username: username,
      role: role,
      branchId: branchId,
    );
  }

  @override
  Future<List<dynamic>> listInvitations(String accessToken) {
    return remoteDatasource.listInvitations(accessToken);
  }

  @override
  Future<Map<String, dynamic>> revokeInvitation(String accessToken, String invitationId) {
    return remoteDatasource.revokeInvitation(accessToken, invitationId);
  }

  @override
  Future<Map<String, dynamic>> regenerateInvitation(String accessToken, String invitationId) {
    return remoteDatasource.regenerateInvitation(accessToken, invitationId);
  }

  @override
  Future<List<dynamic>> getStaff(String accessToken) {
    return remoteDatasource.getStaff(accessToken);
  }

  @override
  Future<void> removeStaff(String accessToken, String staffId) {
    return remoteDatasource.removeStaff(accessToken, staffId);
  }

  @override
  Future<Map<String, dynamic>> updateStaff(String accessToken, String staffId, {
    required String fullName,
    required String role,
    String? branchId,
  }) {
    return remoteDatasource.updateStaff(
      accessToken,
      staffId,
      fullName: fullName,
      role: role,
      branchId: branchId,
    );
  }

  // ── Branch Management ─────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> addBranch(String accessToken, {
    required String name,
    String? phone,
    required String address,
  }) {
    return remoteDatasource.addBranch(
      accessToken,
      name: name,
      phone: phone,
      address: address,
    );
  }

  @override
  Future<List<dynamic>> getBranches(String accessToken) {
    return remoteDatasource.getBranches(accessToken);
  }

  @override
  Future<void> removeBranch(String accessToken, String branchId) {
    return remoteDatasource.removeBranch(accessToken, branchId);
  }

  @override
  Future<Map<String, dynamic>> updateBranch(String accessToken, String branchId, {
    required String name,
    String? phone,
    required String address,
  }) {
    return remoteDatasource.updateBranch(
      accessToken,
      branchId,
      name: name,
      phone: phone,
      address: address,
    );
  }

  // ── Token persistence (secure storage) ───────────────────────────────────

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    if (_sessionOnly) return; // "Remember me" unchecked — memory only.
    await Future.wait([
      secureStorage.write(key: _kAccessToken, value: tokens.accessToken),
      secureStorage.write(key: _kRefreshToken, value: tokens.refreshToken),
    ]);
  }

  @override
  Future<void> setSessionOnly(bool value) async {
    _sessionOnly = value;
    // Switching to session-only should not silently keep a stale stored
    // session: drop it so the next cold start requires login.
    if (value) {
      await clearTokens();
    }
  }

  @override
  Future<void> saveRememberedLogin(String identifier) async {
    await secureStorage.write(key: _kRememberedLogin, value: identifier);
  }

  @override
  Future<String?> getRememberedLogin() async {
    return secureStorage.read(key: _kRememberedLogin);
  }

  @override
  Future<void> forgetRememberedLogin() async {
    await secureStorage.delete(key: _kRememberedLogin);
  }

  @override
  Future<void> setRememberMe(bool value) async {
    await secureStorage.write(key: _kRememberMe, value: value.toString());
  }

  @override
  Future<bool> getRememberMe() async {
    return (await secureStorage.read(key: _kRememberMe)) == 'true';
  }

  @override
  Future<AuthTokens?> getTokens() async {
    final results = await Future.wait([
      secureStorage.read(key: _kAccessToken),
      secureStorage.read(key: _kRefreshToken),
    ]);

    final accessToken = results[0];
    final refreshToken = results[1];

    if (accessToken == null || refreshToken == null) return null;

    // Extract role + orgId from the token itself (no network call needed)
    final role = JwtUtils.extractRole(accessToken) ?? 'CASHIER';
    final orgId = JwtUtils.extractOrganizationId(accessToken) ?? '';

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: role,
      organizationId: orgId,
    );
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      secureStorage.delete(key: _kAccessToken),
      secureStorage.delete(key: _kRefreshToken),
    ]);
  }

  // ── Select Business ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getBusinessSelectionChallenge(
    String accessToken,
  ) {
    return remoteDatasource.getBusinessSelectionChallenge(accessToken);
  }

  @override
  Future<Map<String, dynamic>> selectBusiness({
    required String selectionToken,
    required String organizationId,
    required bool rememberMe,
  }) async {
    final data = await remoteDatasource.selectBusiness(
      selectionToken: selectionToken,
      organizationId: organizationId,
      rememberMe: rememberMe,
    );
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
    }
    return data;
  }

  // ── Helper ────────────────────────────────────────────────────────────────

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
}
