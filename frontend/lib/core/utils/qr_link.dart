/// Client-side validation of SnapVerify payment-account QR payloads.
///
/// A SnapVerify QR encodes a versioned HTTPS deep link:
///
///   `https://<public-host>/qr/v1/<publicId>`
///
/// The public identifier is the only data in the payload — never an account
/// number, holder name, amount or provider. This parser mirrors the backend
/// parser exactly and is intentionally strict: anything that is not an
/// http(s) URL with exactly `/qr/<known-version>/<valid id>` is rejected, so
/// untrusted scanned input is never forwarded to the resolver.
class QrLink {
  QrLink._();

  static const String version = 'v1';
  static const String pathPrefix = '/qr/$version/';

  static final RegExp _publicIdPattern = RegExp(r'^[0-9a-f]{24}$');

  /// True when [value] is a well-formed public identifier.
  static bool isValidPublicId(String? value) =>
      value != null && _publicIdPattern.hasMatch(value);

  /// Extract the public identifier from a scanned payload.
  ///
  /// Returns null for plain text, arbitrary links, unknown versions, extra
  /// path segments, query strings, fragments or embedded credentials.
  static String? parsePublicId(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty || text.length > 2048) return null;

    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (uri.userInfo.isNotEmpty) return null;
    if (uri.hasQuery || uri.hasFragment) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 3) return null;
    if (segments[0] != 'qr' || segments[1] != version) return null;

    final publicId = segments[2].toLowerCase();
    return isValidPublicId(publicId) ? publicId : null;
  }

  /// Build the versioned deep link for a public identifier.
  static String build(String baseUrl, String publicId) {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base$pathPrefix$publicId';
  }

  /// Host to show as a human-readable hint next to the QR code.
  static String? hostOf(String? qrUrl) {
    if (qrUrl == null || qrUrl.isEmpty) return null;
    return Uri.tryParse(qrUrl)?.host;
  }
}
