import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthRemoteDatasource {
  final http.Client client;

  AuthRemoteDatasource({required this.client});

  Duration get _timeout => const Duration(seconds: 30);

  // ── Password Login → returns token map ────────────────────────────────────

  Future<Map<String, dynamic>> loginWithPassword(
    String identifier,
    String password, {
    String? organizationId,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
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

  // ── Owner registration (step 1: create account → email OTP sent) ──────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    String? type,
    String? city,
    String? country,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'fullName': fullName,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
          if (type != null) 'type': type,
          if (city != null) 'city': city,
          if (country != null) 'country': country,
        }),
      ).timeout(_timeout);
      // register returns 201
      _throwIfError(response, 'register', expectedStatus: 201);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'register');
      rethrow;
    }
  }

  // ── Verify email (step 2: OTP → tokens) ───────────────────────────────────

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otpCode': otpCode,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'verifyEmail');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _handleConnectionError(e, 'verifyEmail');
      rethrow;
    }
  }

  // ── Resend verification OTP ───────────────────────────────────────────────

  Future<Map<String, dynamic>> resendVerification(String email) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeout);
      _throwIfError(response, 'resendVerification');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'resendVerification');
      rethrow;
    }
  }

  // ── Forgot password (send email OTP) ──────────────────────────────────────

  Future<void> forgotPassword(String email) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeout);
      _throwIfError(response, 'forgotPassword');
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'forgotPassword');
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
    final response = await client
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(_timeout);
    // Best-effort — ignore server errors on logout
    debugPrint('[AuthDS] logout HTTP ${response.statusCode}');
  }

  // ── Reset Password ────────────────────────────────────────────────────────

  Future<void> resetPassword(
    String email,
    String otpCode,
    String newPassword,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
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

  // Public (pre-login) check: validates an invitation token from the QR
  // deep link. Legacy phone lookup still supported. Does NOT require auth.
  Future<List<dynamic>> checkInvitation(String token, {String? phone}) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/check-invitation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          if (phone != null) 'phone': phone,
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

  // ── Staff activation (email OTP for QR-invited staff) ─────────────────────

  Future<void> staffActivationOtp({
    required String email,
    String? token,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/staff-activation-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          if (token != null) 'token': token,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'staffActivationOtp');
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'staffActivationOtp');
    }
  }

  // ── Staff activation (QR invitation: scan → set password) ─────────────────

  Future<Map<String, dynamic>> activateInvitation({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/activate-invitation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'password': password,
          'confirmPassword': confirmPassword,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'activateInvitation');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception catch (e) {
      rethrow;
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
    required String username,
    required String role,
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
          'username': username,
          'role': role.toUpperCase(),
          if (branchId != null) 'branchId': branchId,
        }),
      ).timeout(_timeout);
      _throwIfError(response, 'addStaff', expectedStatus: 201);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'addStaff');
      rethrow;
    }
  }

  // ── QR invitation lifecycle (owner/manager) ───────────────────────────────

  Future<List<dynamic>> listInvitations(String accessToken) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/auth/invitations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'listInvitations');
      return jsonDecode(response.body) as List<dynamic>;
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'listInvitations');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> revokeInvitation(
    String accessToken,
    String invitationId,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/invitations/$invitationId/revoke'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'revokeInvitation');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'revokeInvitation');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> regenerateInvitation(
    String accessToken,
    String invitationId,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/invitations/$invitationId/regenerate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      _throwIfError(response, 'regenerateInvitation');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception catch (e) {
      rethrow;
    } catch (e) {
      _handleConnectionError(e, 'regenerateInvitation');
      rethrow;
    }
  }

  Future<List<dynamic>> getStaff(String accessToken) async {
    try {
      debugPrint('[AuthDS] getStaff → ${AppConstants.baseUrl}/auth/staff');
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/auth/staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_timeout);
      debugPrint('[AuthDS] getStaff response: ${response.statusCode}');
      _throwIfError(response, 'getStaff');
      return jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      debugPrint('[AuthDS] getStaff error: $e');
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
    // API errors (4xx/5xx with server message) are not connection errors —
    // rethrow them untouched so the user sees the real message.
    if (e is ApiException) {
      throw e;
    }

    debugPrint('[AuthDS] $method connection error: $e');

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

    debugPrint('[AuthDS] $method error: $message');
    throw ApiException(message, statusCode: response.statusCode);
  }
}
