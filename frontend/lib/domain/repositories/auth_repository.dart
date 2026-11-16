import '../entities/auth_tokens.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> loginWithPassword(
    String identifier,
    String password, {
    String? organizationId,
  });

  /// Owner registration (step 1): creates the account + business and sends an
  /// email verification OTP.
  Future<Map<String, dynamic>> register({
    required String name,
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    String? type,
    String? city,
    String? country,
  });

  /// Owner registration (step 2): verify email OTP → tokens.
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otpCode,
  });

  Future<Map<String, dynamic>> resendVerification(String email);

  Future<void> forgotPassword(String email);

  Future<Map<String, dynamic>> refreshToken(String currentRefreshToken);

  Future<void> logout(String refreshToken);

  /// Password recovery (email OTP)
  Future<void> resetPassword(String email, String otpCode, String newPassword);

  /// Invitation Management
  /// Pre-login public check — validates an invitation token from the QR
  /// deep link. Legacy phone lookup is still supported.
  Future<List<dynamic>> checkInvitation(String token, {String? phone});

  /// Send the email OTP used to verify a staff registration.
  Future<void> staffActivationOtp({required String email, String? token});

  /// Authenticated invitation lookup — for owners/managers inspecting staff
  /// invitations. Requires a valid access token.
  Future<List<dynamic>> getInvitations(String phone, String accessToken);

  Future<Map<String, dynamic>> activateInvitation({
    String? token,
    required String email,
    required String otpCode,
    required String fullName,
    required String password,
  });

  /// Get current user and organization
  Future<Map<String, dynamic>> getMe(String accessToken);

  /// Staff Management
  Future<Map<String, dynamic>> addStaff(String accessToken, {
    required String fullName,
    required String email,
    required String role,
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
