import 'dart:convert';

/// Lightweight JWT payload decoder.
/// Does NOT verify the signature — that's the server's job.
/// Used only to read claims (role, org, expiry) without a network call.
class JwtUtils {
  /// Decodes the payload of a JWT and returns the claims as a Map.
  /// Returns null if the token is malformed.
  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Base64-url → base64 standard
      String payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final normalised = payload.replaceAll('-', '+').replaceAll('_', '/');
      final bytes = base64Decode(normalised);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the access token has expired or will expire within
  /// [bufferSeconds] seconds.
  static bool isExpired(String token, {int bufferSeconds = 30}) {
    final claims = decode(token);
    if (claims == null) return true;
    final exp = claims['exp'];
    if (exp == null) return true;
    final expiry = DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    return DateTime.now().isAfter(
      expiry.subtract(Duration(seconds: bufferSeconds)),
    );
  }

  /// Extracts the role claim from the payload, or returns null.
  static String? extractRole(String token) {
    return decode(token)?['role'] as String?;
  }

  /// Extracts the organizationId claim from the payload, or returns null.
  static String? extractOrganizationId(String token) {
    return decode(token)?['organizationId'] as String?;
  }
}
