import '../entities/auth_tokens.dart';

abstract class AuthRepository {
  Future<void> sendOtp(String phone, {String? purpose});

  /// Check OTP validity without consuming it (no session created,
  /// OTP remains valid for subsequent calls like createBusiness).
  /// Throws on invalid/expired OTP.
  Future<void> checkOtp(String phone, String code);

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
  /// Pre-login public check — for staff activating an invitation. Returns the
  /// list of valid (pending, non-expired) invitations for a phone, optionally
  /// scoped to a specific invitation token.
  Future<List<dynamic>> checkInvitation(String phone, {String? token});

  /// Authenticated invitation lookup — for owners/managers inspecting staff
  /// invitations. Requires a valid access token.
  Future<List<dynamic>> getInvitations(String phone, String accessToken);

  Future<Map<String, dynamic>> activateInvitation({
    required String phone,
    required String otpCode,
    required String fullName,
    required String password,
    required String organizationId,
    String? invitationToken,
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
  Future<Map<String, dynamic>> updateStaff(String accessToken, String staffId, {
    required String fullName,
    required String role,
    String? branchId,
  });

  /// Branch Management
  Future<Map<String, dynamic>> addBranch(String accessToken, {
    required String name,
    String? phone,
    required String address,
  });
  Future<List<dynamic>> getBranches(String accessToken);
  Future<void> removeBranch(String accessToken, String branchId);
  Future<Map<String, dynamic>> updateBranch(String accessToken, String branchId, {
    required String name,
    String? phone,
    required String address,
  });

  /// Persist tokens to secure storage.
  Future<void> saveTokens(AuthTokens tokens);

  /// Load tokens from secure storage. Returns null when not logged in.
  Future<AuthTokens?> getTokens();

  /// Remove all stored tokens (clears session).
  Future<void> clearTokens();

  /// Select business (for users in multiple orgs)
  Future<Map<String, dynamic>> selectBusiness({
    required String userId,
    required String organizationId,
  });
}
