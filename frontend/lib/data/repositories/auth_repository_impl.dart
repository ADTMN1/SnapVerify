import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/jwt_utils.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Storage keys — kept private to this file.
const _kAccessToken = 'sv_access_token';
const _kRefreshToken = 'sv_refresh_token';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;
  final FlutterSecureStorage secureStorage;

  const AuthRepositoryImpl({
    required this.remoteDatasource,
    required this.secureStorage,
  });

  // ── OTP ───────────────────────────────────────────────────────────────────

  @override
  Future<void> sendOtp(String phone, {String? purpose}) => remoteDatasource.sendOtp(phone, purpose: purpose);

  @override
  Future<void> checkOtp(String phone, String code) =>
      remoteDatasource.checkOtp(phone, code);

  // ── Password Login ─────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> loginWithPassword(
    String phone,
    String password, {
    String? organizationId,
  }) async {
    final data = await remoteDatasource.loginWithPassword(
      phone,
      password,
      organizationId: organizationId,
    );
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
    }
    return data;
  }

  // ── OTP Login ─────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    String? organizationId,
  }) async {
    final data = await remoteDatasource.verifyOtp(
      phone,
      code,
      organizationId: organizationId,
    );
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
    }
    return data;
  }

  // ── Register business ─────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> createBusiness({
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
    final data = await remoteDatasource.createBusiness(
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

    // Auto-login: save the tokens that came back with the new business
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
    }

    return data;
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
    await remoteDatasource.logout(refreshToken);
    await clearTokens();
  }

  // ── Reset Password ────────────────────────────────────────────────────────

  @override
  Future<void> resetPassword(String phone, String otpCode, String newPassword) {
    return remoteDatasource.resetPassword(phone, otpCode, newPassword);
  }

  // ── Invitation Management ─────────────────────────────────────────────────

  @override
  Future<List<dynamic>> checkInvitation(String phone, {String? token}) {
    return remoteDatasource.checkInvitation(phone, token: token);
  }

  @override
  Future<List<dynamic>> getInvitations(String phone, String accessToken) {
    return remoteDatasource.getInvitations(phone, accessToken);
  }

  @override
  Future<Map<String, dynamic>> activateInvitation({
    required String phone,
    required String otpCode,
    required String fullName,
    required String password,
    required String organizationId,
    String? invitationToken,
  }) async {
    final data = await remoteDatasource.activateInvitation(
      phone: phone,
      otpCode: otpCode,
      fullName: fullName,
      password: password,
      organizationId: organizationId,
      invitationToken: invitationToken,
    );
    if (data['tokens'] != null) {
      final tokens = _tokensFromMap(data['tokens'] as Map<String, dynamic>);
      await saveTokens(tokens);
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> getMe(String accessToken) {
    return remoteDatasource.getMe(accessToken);
  }

  // ── Staff Management ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> addStaff(String accessToken, {
    required String fullName,
    required String phone,
    required String role,
    String? password,
    String? branchId,
  }) {
    return remoteDatasource.addStaff(
      accessToken,
      fullName: fullName,
      phone: phone,
      role: role,
      password: password,
      branchId: branchId,
    );
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
    await Future.wait([
      secureStorage.write(key: _kAccessToken, value: tokens.accessToken),
      secureStorage.write(key: _kRefreshToken, value: tokens.refreshToken),
    ]);
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
  Future<Map<String, dynamic>> selectBusiness({
    required String userId,
    required String organizationId,
  }) async {
    final data = await remoteDatasource.selectBusiness(
      userId: userId,
      organizationId: organizationId,
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
