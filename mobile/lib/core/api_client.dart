import 'package:dio/dio.dart';
import '../models/models.dart';
import 'auth_store.dart';
import 'config.dart';

/// Thin Dio wrapper: injects the JWT, refreshes it transparently on 401.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 70),
        sendTimeout: const Duration(seconds: 35),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _session?.access;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401 && _session?.refresh != null) {
            final ok = await _refresh();
            if (ok) {
              final req = e.requestOptions;
              req.headers['Authorization'] = 'Bearer ${_session!.access}';
              try {
                final clone = await _dio.fetch(req);
                return handler.resolve(clone);
              } catch (err) {
                return handler.next(e);
              }
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;
  Session? _session;

  Session? get session => _session;

  void setSession(Session? s) => _session = s;

  Future<bool> _refresh() async {
    try {
      final resp = await Dio().post(
        '${AppConfig.apiBase}/auth/refresh/',
        data: {'refresh': _session!.refresh},
      );
      final newAccess = resp.data['access'] as String;
      final newRefresh = resp.data['refresh'] as String?;
      _session = _session!.copyWith(access: newAccess, refresh: newRefresh);
      await AuthStore.save(_session!);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Verb helpers ────────────────────────────────────────────────────
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      (await _dio.get(path, queryParameters: query)).data;

  Options _optionsFor(Object? body) => Options(
    contentType: body is FormData
        ? Headers.multipartFormDataContentType
        : Headers.jsonContentType,
  );

  Future<dynamic> post(String path, [Object? body]) async => (await _dio.post(
    path,
    data: body ?? {},
    options: _optionsFor(body),
  )).data;

  Future<dynamic> patch(String path, [Object? body]) async => (await _dio.patch(
    path,
    data: body ?? {},
    options: _optionsFor(body),
  )).data;

  Future<void> delete(String path) async => _dio.delete(path);

  /// Extracts a human message from a DioException for the UI.
  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return '${data['detail']}';

      const connErrors = {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.unknown,
      };
      if (connErrors.contains(e.type)) {
        return 'Не удалось подключиться к серверу. Проверьте интернет и попробуйте ещё раз.';
      }
      // Django rejects an unknown Host (DisallowedHost) with a 400 HTML page.
      if (e.response?.statusCode == 400) {
        return 'Сервер отклонил запрос (400). Проверьте ALLOWED_HOSTS и адрес API.';
      }
      return 'Ошибка сервера (${e.response?.statusCode ?? '—'})';
    }
    return 'Что-то пошло не так';
  }

  static String get apiBaseHint => AppConfig.apiBase;
}
