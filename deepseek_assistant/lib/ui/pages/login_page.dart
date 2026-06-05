import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _loginCodeController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _isLoginCodeMode = false;
  bool _isSendingOTP = false;
  String? _generatedLoginCode;
  DateTime? _loginCodeExpiry;
  int _otpResendCountdown = 0;
  Timer? _otpTimer;

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() => _isLoading = true);

    String? errorMessage;
    if (_isLoginCodeMode) {
      errorMessage = await ref.read(authProvider.notifier).loginWithCode(
            _loginCodeController.text.toUpperCase(),
          );
    } else if (_isRegisterMode) {
      // 使用验证码注册
      errorMessage = await ref.read(authProvider.notifier).verifyAndRegister(
            _emailController.text,
            _otpController.text,
            _passwordController.text,
            _nicknameController.text,
          );
    } else {
      errorMessage = await ref.read(authProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
    }

    setState(() => _isLoading = false);

    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入有效的邮箱地址')),
      );
      return;
    }

    setState(() => _isSendingOTP = true);
    final error = await ref.read(authProvider.notifier).sendOTP(email);
    setState(() => _isSendingOTP = false);

    if (error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送到您的邮箱')),
      );
      _startOTPCountdown();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? '发送验证码失败')),
      );
    }
  }

  void _startOTPCountdown() {
    _otpResendCountdown = 60;
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_otpResendCountdown > 0) {
          _otpResendCountdown--;
        } else {
          timer.cancel();
          _otpTimer = null;
        }
      });
    });
  }

  Future<void> _generateLoginCode() async {
    setState(() => _isLoading = true);
    final result = await ref.read(authProvider.notifier).generateLoginCode();
    setState(() => _isLoading = false);

    if (result != null && mounted) {
      setState(() {
        _generatedLoginCode = result['code'];
        _loginCodeExpiry = DateTime.tryParse(result['expires_at']);
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成登录码失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: authState.isAuthenticated
                    ? _buildLoginCodeGenerator()
                    : _isLoginCodeMode
                        ? _buildLoginCodeLoginForm()
                        : _buildNormalForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble,
            size: 64,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          Text(
            _isRegisterMode ? '注册' : '登录',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          if (_isRegisterMode)
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入昵称';
                }
                if (value.length < 2) {
                  return '昵称至少需要2个字符';
                }
                return null;
              },
            ),
          if (_isRegisterMode) const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入邮箱';
              }
              if (!value.contains('@')) {
                return '请输入有效的邮箱地址';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (_isRegisterMode)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      prefixIcon: Icon(Icons.security),
                      border: OutlineInputBorder(),
                      hintText: '请输入6位验证码',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入验证码';
                      }
                      if (value.length != 6) {
                        return '验证码必须是6位数字';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: _isSendingOTP || _otpResendCountdown > 0 ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSendingOTP
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _otpResendCountdown > 0
                            ? Text('${_otpResendCountdown}s')
                            : const Text('发送'),
                  ),
                ),
              ],
            ),
          if (_isRegisterMode) const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入密码';
              }
              if (value.length < 8) {
                return '密码至少需要8位';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text(_isRegisterMode ? '注册' : '登录'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoginCodeMode = true;
              });
            },
            child: const Text('使用登录码登录'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isRegisterMode = !_isRegisterMode;
                _emailController.clear();
                _passwordController.clear();
                _nicknameController.clear();
                _otpController.clear();
                _otpResendCountdown = 0;
              });
            },
            child: Text(
              _isRegisterMode
                  ? '已有账号？去登录'
                  : '没有账号？去注册',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCodeLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.key,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            '登录码登录',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '输入8位登录码',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _loginCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '登录码',
              prefixIcon: Icon(Icons.numbers),
              border: OutlineInputBorder(),
              hintText: '输入8位字符，例如: ABC12345',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入登录码';
              }
              if (value.length != 8) {
                return '登录码必须是8位字符';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.green,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('使用登录码登录', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoginCodeMode = false;
                _loginCodeController.clear();
              });
            },
            child: const Text('返回账号密码登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCodeGenerator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle,
          size: 64,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        Text(
          '你已登录',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '欢迎回来，${ref.watch(authProvider).nickname ?? '用户'}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        if (_generatedLoginCode != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              children: [
                Text(
                  '你的登录码',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _generatedLoginCode!,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                ),
                const SizedBox(height: 8),
                if (_loginCodeExpiry != null)
                  Text(
                    '有效期至: ${_loginCodeExpiry!.toLocal().toString().substring(0, 19)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton(
          onPressed: _isLoading ? null : _generateLoginCode,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('生成登录码'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
          ),
          child: const Text('退出登录', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _loginCodeController.dispose();
    _otpController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }
}
