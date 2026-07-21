import '../entities/auth_tokens.dart';

abstract class AuthRepository {
  Future<void> sendOtp(String phone);

  Future<Map<String, dynamic>> loginWithPassword(
    String phone,
    String password, {
    String? organizationId,
  });

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    String? organizationId,
  });

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
  });

  Future<Map<String, dynamic>> refreshToken(String currentRefreshToken);

  Future<void> logout(String refreshToken);

  /// Reset Password
  Future<void> resetPassword(String phone, String otpCode, String newPassword);

  /// Invitation Management
  Future<List<dynamic>> getInvitations(String phone);
  Future<Map<String, dynamic>> activateInvitation({
    required String phone,
    required String otpCode,
    required String fullName,
    required String password,
    required String organizationId,
  });

  /// Get current user and organization
  Future<Map<String, dynamic>> getMe(String accessToken);

  /// Staff Management
  Future<Map<String, dynamic>> addStaff(String accessToken, {
    required String fullName,
    required String phone,
    required String role,
    String? password,
    String? branchId,
  });
  Future<List<dynamic>> getStaff(String accessToken);
  Future<void> removeStaff(String accessToken, String staffId);

  /// Branch Management
  Future<Map<String, dynamic>> addBranch(String accessToken, {
    required String name,
    String? phone,
    required String address,
  });
  Future<List<dynamic>> getBranches(String accessToken);
  Future<void> removeBranch(String accessToken, String branchId);

  /// Persist tokens to secure storage.
  Future<void> saveTokens(AuthTokens tokens);

  /// Load tokens from secure storage. Returns null when not logged in.
  Future<AuthTokens?> getTokens();

  /// Remove all stored tokens (clears session).
  Future<void> clearTokens();
}
