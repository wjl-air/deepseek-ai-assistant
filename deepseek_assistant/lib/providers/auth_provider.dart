import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  return AuthProvider();
});

class AuthState {
  final bool isAuthenticated;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? nickname;

  AuthState({
    required this.isAuthenticated,
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.nickname,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? accessToken,
    String? refreshToken,
    String? userId,
    String? nickname,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
    );
  }
}

class AuthProvider extends StateNotifier<AuthState> {
  AuthProvider() : super(AuthState(isAuthenticated: false)) {
    _initDio();
    _loadTokens();
  }

  late final Dio _dio;
  bool _isRefreshing = false;
  final List<Completer<void>> _refreshQueue = [];

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.backendApiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (state.accessToken != null) {
          options.headers['Authorization'] = 'Bearer ${state.accessToken}';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          if (path == '/auth/logout' || path.startsWith('/sessions')) {
            return handler.next(error);
          }
          if (state.refreshToken == null) {
            await logout();
            return handler.next(error);
          }

          if (_isRefreshing) {
            // Another request is already refreshing - wait for it
            final completer = Completer<void>();
            _refreshQueue.add(completer);
            await completer.future;

            if (state.accessToken == null) {
              // Refresh failed, logged out
              return handler.next(error);
            }

            // Retry with new token
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer ${state.accessToken}';
            try {
              final retryResponse = await _dio.fetch(retryOptions);
              return handler.resolve(retryResponse);
            } catch (retryError) {
              return handler.next(retryError is DioException ? retryError : DioException(requestOptions: retryOptions, error: retryError));
            }
          }

          _isRefreshing = true;
          try {
            final refreshed = await _performRefreshToken();
            _isRefreshing = false;

            // Wake up all waiting requests
            for (final completer in _refreshQueue) {
              if (!completer.isCompleted) completer.complete();
            }
            _refreshQueue.clear();

            if (refreshed) {
              final retryOptions = error.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer ${state.accessToken}';
              try {
                final retryResponse = await _dio.fetch(retryOptions);
                return handler.resolve(retryResponse);
              } catch (retryError) {
                return handler.next(retryError is DioException ? retryError : DioException(requestOptions: retryOptions, error: retryError));
              }
            } else {
              await logout();
            }
          } catch (e) {
            _isRefreshing = false;
            for (final completer in _refreshQueue) {
              if (!completer.isCompleted) completer.complete();
            }
            _refreshQueue.clear();
            await logout();
            return handler.next(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> _loadTokens() async {
    String? accessToken;
    String? refreshToken;

    try {
      accessToken = await _secureStorage.read(key: 'access_token');
      refreshToken = await _secureStorage.read(key: 'refresh_token');
    } catch (e) {
      debugPrint('Secure storage read error: $e');
      // Fallback: try to read from SharedPreferences on web
      try {
        final prefs = await SharedPreferences.getInstance();
        accessToken = prefs.getString('access_token_web');
        refreshToken = prefs.getString('refresh_token_web');
      } catch (e2) {
        debugPrint('SharedPreferences fallback error: $e2');
      }
    }

    if (accessToken != null && refreshToken != null) {
      final prefs = await SharedPreferences.getInstance();
      String? nickname = prefs.getString('nickname');
      final userId = prefs.getString('user_id');

      // Set tokens in memory so Dio interceptor can use them
      state = state.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        nickname: nickname,
      );

      // Validate tokens by calling /auth/me
      try {
        final meResponse = await _dio.get('/auth/me');
        if (meResponse.statusCode == 200) {
          nickname = meResponse.data['nickname'];
          if (nickname != null) {
            await prefs.setString('nickname', nickname);
          }
          state = state.copyWith(
            isAuthenticated: true,
            nickname: nickname,
          );
          return;
        }
      } catch (e) {
        debugPrint('Token validation failed on load: $e');
      }

      // If we reach here, tokens are invalid - clear everything
      await _clearStoredTokens();
      state = AuthState(isAuthenticated: false);
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      debugPrint('Attempting login for: $email');
      debugPrint('API base URL: ${AppConfig.backendApiBaseUrl}');

      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      debugPrint('Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('Login response data: $data');

        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final userId = data['user_id'].toString();

        debugPrint('Storing tokens...');
        try {
          await _secureStorage.write(key: 'access_token', value: accessToken);
          await _secureStorage.write(key: 'refresh_token', value: refreshToken);
          debugPrint('Tokens stored in secure storage');
        } catch (storageError) {
          debugPrint('Secure storage error, using SharedPreferences fallback: $storageError');
        }

        debugPrint('Getting SharedPreferences...');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
          // Also store tokens in SharedPreferences as fallback for web
          await prefs.setString('access_token_web', accessToken);
          await prefs.setString('refresh_token_web', refreshToken);
          debugPrint('SharedPreferences updated');
        } catch (prefsError) {
          debugPrint('SharedPreferences error: $prefsError');
        }

        String? nickname;
        try {
          final meResponse = await _dio.get(
            '/auth/me',
            options: Options(
              headers: {'Authorization': 'Bearer $accessToken'},
            ),
          );
          if (meResponse.statusCode == 200) {
            nickname = meResponse.data['nickname'];
          }
        } catch (e) {
          debugPrint('Failed to fetch user info: $e');
        }

        nickname ??= email.split('@')[0];

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('nickname', nickname);
        } catch (e) {
          debugPrint('Failed to save nickname: $e');
        }

        state = state.copyWith(
          isAuthenticated: true,
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
          nickname: nickname,
        );
        debugPrint('Login successful!');
        return null;
      }
      return '用户名或密码错误';
    } on DioException catch (e) {
      debugPrint('Login DioException: ${e.message}');
      debugPrint('Response data: ${e.response?.data}');
      debugPrint('Status code: ${e.response?.statusCode}');
      final detail = e.response?.data?['detail'];
      if (detail != null && detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (e.response?.statusCode == 401) {
        return '用户名或密码错误';
      }
      return '登录失败: ${e.message}';
    } catch (e, stackTrace) {
      debugPrint('Login unexpected error: $e');
      debugPrint('Stack trace: $stackTrace');
      return '登录失败: $e';
    }
  }

  Future<String?> register(String email, String password, String nickname) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {'email': email, 'password': password, 'nickname': nickname},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final loginError = await login(email, password);
        return loginError;
      }
      return '注册失败';
    } on DioException catch (e) {
      debugPrint('Register error: ${e.response?.data}');
      final detail = e.response?.data?['detail'];
      if (detail != null && detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (e.response?.statusCode == 400) {
        return '该账号已注册';
      }
      return '注册失败，请检查网络后重试';
    } catch (e) {
      debugPrint('Register error: $e');
      return '注册失败，请检查网络后重试';
    }
  }

  Future<String?> sendOTP(String email) async {
    try {
      final response = await _dio.post(
        '/auth/send-otp',
        data: {'email': email},
      );
      if (response.statusCode == 200) {
        return null; // success, no error
      }
      return '发送验证码失败';
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      return detail ?? '发送验证码失败';
    } catch (e) {
      debugPrint('Send OTP error: $e');
      return '发送验证码失败';
    }
  }

  Future<Map<String, dynamic>?> generateLoginCode() async {
    try {
      final response = await _dio.post('/auth/login-code/generate');
      if (response.statusCode == 201) {
        return response.data;
      }
    } on DioException catch (e) {
      debugPrint('Generate login code error: ${e.response?.data}');
    } catch (e) {
      debugPrint('Generate login code error: $e');
    }
    return null;
  }

  Future<String?> loginWithCode(String code) async {
    try {
      final response = await _dio.post(
        '/auth/login-code/login',
        data: {'code': code},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final userId = data['user_id'].toString();

        await _secureStorage.write(key: 'access_token', value: accessToken);
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userId);

        String? nickname;
        try {
          final meResponse = await _dio.get(
            '/auth/me',
            options: Options(
              headers: {'Authorization': 'Bearer $accessToken'},
            ),
          );
          if (meResponse.statusCode == 200) {
            nickname = meResponse.data['nickname'];
          }
        } catch (e) {
          debugPrint('Failed to fetch user info: $e');
        }

        nickname ??= 'User';
        await prefs.setString('nickname', nickname);

        state = state.copyWith(
          isAuthenticated: true,
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
          nickname: nickname,
        );
        return null;
      }
      return '登录码无效';
    } on DioException catch (e) {
      debugPrint('Login with code error: ${e.response?.data}');
      final detail = e.response?.data?['detail'];
      if (detail != null && detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (e.response?.statusCode == 401) {
        return '无效或已过期的登录码';
      }
      return '登录失败，请检查网络后重试';
    } catch (e) {
      debugPrint('Login with code error: $e');
      return '登录失败，请检查网络后重试';
    }
  }

  Future<String?> verifyAndRegister(String email, String code, String password, String nickname) async {
    try {
      final response = await _dio.post(
        '/auth/verify-and-register',
        data: {
          'email': email,
          'code': code,
          'password': password,
          'nickname': nickname,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final loginError = await login(email, password);
        if (loginError == null) return null; // success
        return '自动登录失败：$loginError';
      }
      return '注册失败';
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      return detail ?? '注册失败';
    } catch (e) {
      debugPrint('Verify and register error: $e');
      return '注册失败';
    }
  }

  Future<void> logout() async {
    if (state.refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': state.refreshToken});
      } catch (e) {
        debugPrint('Logout error: $e');
      }
    }

    await _clearStoredTokens();
    state = AuthState(isAuthenticated: false);
  }

  Future<void> _clearStoredTokens() async {
    try {
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
    } catch (e) {
      debugPrint('Secure storage delete error: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('nickname');
      await prefs.remove('access_token_web');
      await prefs.remove('refresh_token_web');
    } catch (e) {
      debugPrint('SharedPreferences clear error: $e');
    }
  }

  Future<bool> _performRefreshToken() async {
    if (state.refreshToken == null) return false;

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': state.refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final newAccessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];

        await _secureStorage.write(key: 'access_token', value: newAccessToken);
        await _secureStorage.write(key: 'refresh_token', value: newRefreshToken);

        state = state.copyWith(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Refresh token error: $e');
      rethrow;
    }
    return false;
  }

  Future<bool> refreshToken() async {
    return await _performRefreshToken();
  }

  Dio get dio => _dio;
}
