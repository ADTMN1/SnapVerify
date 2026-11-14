import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class AuthRemoteDatasource {
  final http.Client client;

  AuthRemoteDatasource({required this.client});

  Duration get _timeout => const Duration(seconds: 30);

  // ── Send OTP ──────────────────────────────────────────────────────────────

  Future<void> sendOtp(String phone, {String? purpose}) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          if (purpose != null) 'purpose': purpose,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'sendOtp');
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'sendOtp');
    }
  }

  // ── Check OTP (verify without consuming — for multi-step UI flows) ────────

  Future<void> checkOtp(String phone, String code) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/check-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'code': code,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'checkOtp');
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'checkOtp');
    }
  }

  // ── Password Login → returns token map ────────────────────────────────────

  Future<Map<String, dynamic>> loginWithPassword(
    String phone,
    String password, {
    String? organizationId,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
          if (organizationId != null) 'organizationId': organizationId,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'loginWithPassword');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'loginWithPassword');
      rethrow;
    }
  }

  // ── Verify OTP → returns token map ───────────────────────────────────────

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    String? organizationId,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'code': code,
          if (organizationId != null) 'organizationId': organizationId,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'verifyOtp');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'verifyOtp');
      rethrow;
    }
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
    try {
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
      ).timeout(_timeout);
      // createBusiness returns 201
      _throwIfError(response, 'createBusiness', expectedStatus: 201);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'createBusiness');
      rethrow;
    }
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(_timeout);
      _throwIfError(response, 'refreshToken');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'refreshToken');
      rethrow;
    }
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
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otpCode': otpCode,
          'newPassword': newPassword,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'resetPassword');
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'resetPassword');
    }
  }

  // ── Invitations ───────────────────────────────────────────────────────────

  // Public (pre-login) check: finds pending non-expired invitations for a
  // phone (+ optional invitation token). Does NOT require auth.
  // Used by Activate Invitation flow step 0.
  Future<List<dynamic>> checkInvitation(String phone, {String? token}) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/check-invitation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          if (token != null) 'token': token,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'checkInvitation');
      return jsonDecode(response.body) as List<dynamic>;
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'checkInvitation');
      rethrow;
    }
  }

  // Authenticated-only legacy lookup. Kept for owners viewing staff.
  Future<List<dynamic>> getInvitations(String phone, String accessToken) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/auth/invitations/$phone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'getInvitations');
      return jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'getInvitations');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> activateInvitation({
    required String phone,
    required String otpCode,
    required String fullName,
    required String password,
    required String organizationId,
    String? invitationToken,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/activate-invitation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otpCode': otpCode,
          'fullName': fullName,
          'password': password,
          'organizationId': organizationId,
          if (invitationToken != null) 'token': invitationToken,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'activateInvitation');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'activateInvitation');
      rethrow;
    }
  }

  // ── Get current user and organization ────────────────────────────────────

  Future<Map<String, dynamic>> getMe(String accessToken) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'getMe');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'getMe');
      rethrow;
    }
  }

  // ── Staff Management ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addStaff(String accessToken, {
    required String fullName,
    required String phone,
    required String role,
    String? password,
    String? branchId,
  }) async {
    try {
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
      ).timeout(_timeout);
      _throwIfError(response, 'addStaff', expectedStatus: 201);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'addStaff');
      rethrow;
    }
  }

  Future<List<dynamic>> getStaff(String accessToken) async {
    try {
      dev.log('[AuthDS] getStaff → ${AppConstants.baseUrl}/auth/staff');
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/auth/staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      dev.log('[AuthDS] getStaff response: ${response.statusCode}');
      _throwIfError(response, 'getStaff');
      return jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      dev.log('[AuthDS] getStaff error: $e');
      _handleConnectionError(e, 'getStaff');
      rethrow;
    }
  }

  Future<void> removeStaff(String accessToken, String staffId) async {
    try {
      final response = await client.delete(
        Uri.parse('${AppConstants.baseUrl}/auth/staff/$staffId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'removeStaff');
    } catch (e) {
      _handleConnectionError(e, 'removeStaff');
    }
  }

  Future<Map<String, dynamic>> updateStaff(String accessToken, String staffId, {
    required String fullName,
    required String role,
    String? branchId,
  }) async {
    try {
      final response = await client.put(
        Uri.parse('${AppConstants.baseUrl}/auth/staff/$staffId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'fullName': fullName,
          'role': role.toUpperCase(),
          if (branchId != null) 'branchId': branchId,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'updateStaff');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'updateStaff');
      rethrow;
    }
  }

  // ── Branch Management ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addBranch(String accessToken, {
    required String name,
    String? phone,
    required String address,
  }) async {
    try {
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
      ).timeout(_timeout);
      _throwIfError(response, 'addBranch', expectedStatus: 201);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'addBranch');
      rethrow;
    }
  }

  Future<List<dynamic>> getBranches(String accessToken) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/branches'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'getBranches');
      return jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'getBranches');
      rethrow;
    }
  }

  Future<void> removeBranch(String accessToken, String branchId) async {
    try {
      final response = await client.delete(
        Uri.parse('${AppConstants.baseUrl}/branches/$branchId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'removeBranch');
    } catch (e) {
      _handleConnectionError(e, 'removeBranch');
    }
  }

  Future<Map<String, dynamic>> updateBranch(String accessToken, String branchId, {
    required String name,
    String? phone,
    required String address,
  }) async {
    try {
      final response = await client.put(
        Uri.parse('${AppConstants.baseUrl}/branches/$branchId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'name': name,
          if (phone != null) 'phone': phone,
          'address': address,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'updateBranch');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'updateBranch');
      rethrow;
    }
  }

  // ── Select Business ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> selectBusiness({
    required String userId,
    required String organizationId,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/select-business'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'organizationId': organizationId,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'selectBusiness');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'selectBusiness');
      rethrow;
    }
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  void _handleConnectionError(dynamic e, String method) {
    dev.log('[AuthDS] $method connection error: $e');
    
    String message;
    if (e.toString().contains('Connection closed before full header was received')) {
      message = 'Connection lost. Please check your internet connection and try again.';
    } else if (e.toString().contains('Connection refused')) {
      message = 'Unable to connect to server. Please check your internet connection.';
    } else if (e.toString().contains('timeout')) {
      message = 'Request timed out. Please check your network connection.';
    } else if (e.toString().contains('No route to host')) {
      message = 'Unable to reach server. Please check your internet connection.';
    } else {
      message = 'Connection error. Please check your internet and try again.';
    }
    
    throw Exception(message);
  }

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
      if (msg is List) {
        message = (msg as List).join(', ');
      } else if (msg != null) {
        message = msg.toString();
      } else {
        message = 'HTTP ${response.statusCode}';
      }
    } catch (_) {
      message = 'HTTP ${response.statusCode}: ${response.body}';
    }

    dev.log('[AuthDS] $method error: $message');
    throw Exception(message);
  }
}
