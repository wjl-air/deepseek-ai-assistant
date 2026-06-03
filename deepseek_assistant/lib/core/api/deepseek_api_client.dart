import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../config/app_config.dart';

class DeepSeekApiClient {
  static DeepSeekApiClient? _instance;
  static DeepSeekApiClient get instance {
    if (_instance == null) {
      _instance = DeepSeekApiClient._();
    }
    return _instance!;
  }

  final Dio _dio;
  String _apiKey;

  DeepSeekApiClient._() : _apiKey = AppConfig.apiKey, _dio = Dio() {
    _initDio();
  }

  void _initDio() {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    _dio.options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout:
          const Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout:
          const Duration(milliseconds: AppConfig.receiveTimeoutMs),
      headers: headers,
    );

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => developer.log(obj.toString(), name: 'API'),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          
          final shouldRetry = _shouldRetry(error);
          if (shouldRetry) {
            final retryCount = error.requestOptions.extra['retryCount'] ?? 0;
            if (retryCount < 3) {
              error.requestOptions.extra['retryCount'] = retryCount + 1;
              final delay = Duration(milliseconds: (1000 * (1 << retryCount)));
              await Future<void>.delayed(delay);
              try {
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } catch (_) {}
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  bool _shouldRetry(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    final statusCode = error.response?.statusCode;
    return statusCode == 429 || statusCode == 500 || statusCode == 503;
  }

  void updateApiKey(String newKey) {
    _apiKey = newKey;
    _dio.options.headers['Authorization'] = 'Bearer $newKey';
  }

  void _handleError(DioException error) {
    switch (error.response?.statusCode) {
      case 401:
        throw DeepSeekApiException('认证失败，请检查 API Key 是否正确', statusCode: 401);
      case 402:
        throw DeepSeekApiException('账户余额不足', statusCode: 402);
      case 429:
        throw DeepSeekApiException('请求频率超限，请稍后重试', statusCode: 429);
      case 500:
        throw DeepSeekApiException('服务器内部错误', statusCode: 500);
      case 503:
        throw DeepSeekApiException('服务暂时不可用', statusCode: 503);
      default:
        throw DeepSeekApiException(
          error.message ?? '未知网络错误',
          statusCode: error.response?.statusCode,
        );
    }
  }

  Future<Response> postJson({
    required String path,
    required Map<String, dynamic> data,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(path, data: data, cancelToken: cancelToken);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> postStream({
    required String path,
    required Map<String, dynamic> data,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }
}

class DeepSeekApiException implements Exception {
  final String message;
  final int? statusCode;

  DeepSeekApiException(this.message, {this.statusCode});

  @override
  String toString() => 'DeepSeekApiException($statusCode): $message';
}
