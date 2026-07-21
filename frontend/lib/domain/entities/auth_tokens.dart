class AuthTokens {
  final String accessToken;
  final String refreshToken;

  /// Role extracted from the JWT payload (e.g. 'OWNER', 'MANAGER', 'CASHIER', 'WAITER')
  final String role;

  /// Organization the token is scoped to
  final String organizationId;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.organizationId,
  });

  /// Returns true when the access token has expired (or is within a 30-second
  /// buffer so we refresh proactively before the server rejects it).
  bool get isAccessTokenExpired {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return true;

      // Base64-url decode the payload
      String payload = parts[1];
      // Pad to a multiple of 4 for standard base64
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = String.fromCharCodes(
        Uri.decodeFull(payload
                .replaceAll('-', '+')
                .replaceAll('_', '/'))
            .codeUnits,
      );
      // Simple regex parse — avoids importing a JSON library for this tiny job
      final expMatch = RegExp(r'"exp":(\d+)').firstMatch(decoded);
      if (expMatch == null) return true;

      final exp = int.parse(expMatch.group(1)!);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // 30-second proactive refresh buffer
      return now >= (exp - 30);
    } catch (_) {
      return true;
    }
  }
}
