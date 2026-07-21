import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class AuthRemoteDatasource {
  final http.Client client;

  AuthRemoteDatasource({required this.client});

  // ── Send OTP ──────────────────────────────────────────────────────────────

  Future<void> sendOtp(String phone) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    _throwIfError(response, 'sendOtp');
  }

  // ── Password Login → returns token map ────────────────────────────────────

  Future<Map<String, dynamic>> loginWithPassword(
    String phone,
    String password, {
    String? organizationId,
  }) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        if (organizationId != null) 'organizationId': organizationId,
      }),
    );
    _throwIfError(response, 'loginWithPassword');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Verify OTP → returns token map ───────────────────────────────────────

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    String? organizationId,
  }) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'code': code,
        if (organizationId != null) 'organizationId': organizationId,
      }),
    );
    _throwIfError(response, 'verifyOtp');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Create business ───────────────────────────────────────────────────────

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
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/create-business'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'fullName': fullName,
        'phone': phone,
        'otpCode': otpCode,
        'password': password,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (type != null) 'type': type,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
      }),
    );
    // createBusiness returns 201
    _throwIfError(response, 'createBusiness', expectedStatus: 201);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/refresh-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    _throwIfError(response, 'refreshToken');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout(String refreshToken) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    // Best-effort — ignore server errors on logout
    dev.log('[AuthDS] logout HTTP ${response.statusCode}');
  }

  // ── Reset Password ────────────────────────────────────────────────────────

  Future<void> resetPassword(String phone, String otpCode, String newPassword) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otpCode': otpCode,
        'newPassword': newPassword,
      }),
    );
    _throwIfError(response, 'resetPassword');
  }

  // ── Invitations ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getInvitations(String phone) async {
    final response = await client.get(
      Uri.parse('${AppConstants.baseUrl}/auth/invitations/$phone'),
      headers: {'Content-Type': 'application/json'},
    );
    _throwIfError(response, 'getInvitations');
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> activateInvitation({
    required String phone,
    required String otpCode,
    required String fullName,
    required String password,
    required String organizationId,
  }) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/activate-invitation'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otpCode': otpCode,
        'fullName': fullName,
        'password': password,
        'organizationId': organizationId,
      }),
    );
    _throwIfError(response, 'activateInvitation');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Get current user and organization ────────────────────────────────────

  Future<Map<String, dynamic>> getMe(String accessToken) async {
    final response = await client.get(
      Uri.parse('${AppConstants.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    _throwIfError(response, 'getMe');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Staff Management ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addStaff(String accessToken, {
    required String fullName,
    required String phone,
    required String role,
    String? password,
    String? branchId,
  }) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/staff'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'fullName': fullName,
        'phone': phone,
        'role': role.toUpperCase(),
        if (password != null) 'password': password,
        if (branchId != null) 'branchId': branchId,
      }),
    );
    _throwIfError(response, 'addStaff', expectedStatus: 201);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getStaff(String accessToken) async {
    final response = await client.get(
      Uri.parse('${AppConstants.baseUrl}/auth/staff'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    _throwIfError(response, 'getStaff');
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> removeStaff(String accessToken, String staffId) async {
    final response = await client.delete(
      Uri.parse('${AppConstants.baseUrl}/auth/staff/$staffId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    _throwIfError(response, 'removeStaff');
  }

  // ── Branch Management ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addBranch(String accessToken, {
    required String name,
    String? phone,
    required String address,
  }) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/branches'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'name': name,
        if (phone != null) 'phone': phone,
        'address': address,
      }),
    );
    _throwIfError(response, 'addBranch', expectedStatus: 201);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getBranches(String accessToken) async {
    final response = await client.get(
      Uri.parse('${AppConstants.baseUrl}/branches'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    _throwIfError(response, 'getBranches');
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> removeBranch(String accessToken, String branchId) async {
    final response = await client.delete(
      Uri.parse('${AppConstants.baseUrl}/branches/$branchId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    _throwIfError(response, 'removeBranch');
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  void _throwIfError(
    http.Response response,
    String method, {
    int expectedStatus = 200,
  }) {
    if (response.statusCode == expectedStatus) return;

    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'];
      message = msg is List
          ? (msg as List).join(', ')
          : (msg?.toString() ?? 'HTTP ${response.statusCode}');
    } catch (_) {
      message = 'HTTP ${response.statusCode}: ${response.body}';
    }

    dev.log('[AuthDS] $method error: $message');
    throw Exception(message);
  }
}
