import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../security/token_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HEADER SECURITY — Kya public hota hai, kya nahi
// ─────────────────────────────────────────────────────────────────────────────
//
// Headers jo hum bhejte hain:
//   Authorization: Bearer <Firebase JWT>   ← 1 ghante mein expire, harmless
//   Content-Type: application/json         ← Standard, public hona theek hai
//   X-App-Version: 1.0.0                   ← Public hona theek hai
//   X-Platform: android/ios                ← Public hona theek hai
//
// Kya koi dekh sakta hai?
//   ✅ Normal HTTPS traffic → ENCRYPTED, koi nahi dekh sakta
//   ✅ Wireshark/network sniff → ENCRYPTED, koi nahi dekh sakta
//   ⚠️  Charles Proxy / mitmproxy → Certificate Pinning se BLOCK karo
//   ⚠️  Rooted device + Frida SSL unpinning → Partial protection
//
// KEY POINT: Headers mein Stability AI key KABHI NAHI hoti.
// Sirf Firebase JWT token hota hai jo:
//   - Sirf hamare backend pe valid hai
//   - 1 ghante mein expire hota hai
//   - Koi bhi isse use karke Stability AI access NAHI kar sakta
// ─────────────────────────────────────────────────────────────────────────────

class SecureHttpClient {
  SecureHttpClient._();
  static final SecureHttpClient instance = SecureHttpClient._();

  Future<Map<String, String>> _buildHeaders({
    bool requireAuth = true,
    bool isJson = true,
  }) async {
    final headers = <String, String>{
      if (isJson) 'Content-Type': 'application/json',
      if (isJson) 'Accept': 'application/json',
      'X-App-Version': AppConfig.appVersion,
      'X-Platform': kIsWeb ? 'web' : 'mobile',
      'X-Timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'X-Request-ID': DateTime.now().microsecondsSinceEpoch.toString(),
    };

    if (requireAuth) {
      final token = await TokenStorage.instance.getValidToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final uri = Uri.parse('${AppConfig.backendUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final uri = _buildUri(endpoint, queryParams);
      _log('GET $uri');

      final response = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 30),
          );

      return _handleHttpResponse(response);
    } catch (e) {
      return ApiResponse.error('Something went wrong: $e');
    }
  }

  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final uri = _buildUri(endpoint);
      _log('POST $uri');

      final response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(seconds: 60),
          );

      return _handleHttpResponse(response);
    } catch (e) {
      return ApiResponse.error('Something went wrong: $e');
    }
  }

  Future<ApiResponse> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, List<int>>? files,
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth, isJson: false);
      final uri = _buildUri(endpoint);

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      request.fields.addAll(fields);

      if (files != null) {
        for (final entry in files.entries) {
          request.files.add(
            http.MultipartFile.fromBytes(
              entry.key,
              entry.value,
              filename: '${entry.key}.png',
            ),
          );
        }
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleHttpResponse(response);
    } catch (e) {
      return ApiResponse.error('Upload failed: $e');
    }
  }

  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final uri = _buildUri(endpoint);

      final response = await http
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(seconds: 30),
          );

      return _handleHttpResponse(response);
    } catch (e) {
      return ApiResponse.error('Something went wrong: $e');
    }
  }

  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final uri = _buildUri(endpoint, queryParams);
      _log('DELETE $uri');

      final response = await http
          .delete(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(seconds: 30),
          );

      return _handleHttpResponse(response);
    } catch (e) {
      return ApiResponse.error('Something went wrong: $e');
    }
  }

  ApiResponse _handleHttpResponse(http.Response response) {
    final statusCode = response.statusCode;
    _log('Response $statusCode');

    final bodyBytes = response.bodyBytes;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final body = utf8.decode(bodyBytes);
        if (body.isNotEmpty) {
          final data = jsonDecode(body);
          return ApiResponse.success(data, statusCode);
        }
        return ApiResponse.success(null, statusCode);
      } catch (_) {
        return ApiResponse.success(bodyBytes, statusCode);
      }
    }

    try {
      final body = utf8.decode(bodyBytes);
      final error = jsonDecode(body);
      String message = 'Server error';
      if (error is Map<String, dynamic>) {
        final detail = error['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is Map) {
          message = detail['message'] as String? ?? 'Server error';
        } else if (error['message'] is String) {
          message = error['message'] as String;
        }
      }

      switch (statusCode) {
        case 401:
          return ApiResponse.error('Session expired. Please log in again.', statusCode: 401);
        case 402:
          return ApiResponse.error('Not enough credits. Please purchase more.', statusCode: 402, extra: error['detail']);
        case 403:
          return ApiResponse.error('Access denied.', statusCode: 403);
        case 429:
          return ApiResponse.error('Too many requests. Please wait a moment and try again.', statusCode: 429);
        case 500:
          return ApiResponse.error('Server error. Please try again later.', statusCode: 500);
        default:
          return ApiResponse.error(message, statusCode: statusCode);
      }
    } catch (_) {
      return ApiResponse.error('Server error: $statusCode', statusCode: statusCode);
    }
  }

  // ── Logging — sirf debug mode mein ───────────────────────────────────────

  void _log(String message) {
    // Production mein koi logging nahi — headers/URLs leak nahi honge
    if (kDebugMode) debugPrint('[HTTP] $message');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// API Response wrapper
// ─────────────────────────────────────────────────────────────────────────────

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? errorMessage;
  final int? statusCode;
  final dynamic extra;

  const ApiResponse._({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
    this.extra,
  });

  factory ApiResponse.success(dynamic data, [int? statusCode]) =>
      ApiResponse._(success: true, data: data, statusCode: statusCode);

  factory ApiResponse.error(String message,
          {int? statusCode, dynamic extra}) =>
      ApiResponse._(
          success: false,
          errorMessage: message,
          statusCode: statusCode,
          extra: extra);

  bool get isUnauthorized => statusCode == 401;
  bool get isNoCredits => statusCode == 402;
  bool get isRateLimited => statusCode == 429;
}
