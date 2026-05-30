import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/search_provider.dart';
import '../services/bilibili_login.dart';
import '../services/log_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _login = BilibiliLogin();
  LoginQrCode? _qrCode;
  String _status = '正在获取二维码...';
  Timer? _pollTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQrCode();
  }

  Future<void> _fetchQrCode() async {
    setState(() {
      _isLoading = true;
      _status = '正在获取二维码...';
    });

    final result = await _login.getQrCode();
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _qrCode = result;
        _isLoading = false;
        _status = '请使用 Bilibili APP 扫码登录';
      });
      _startPolling();
    } else {
      setState(() {
        _isLoading = false;
        _status = result.message;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final result = await _login.checkLogin();
      if (!mounted) return;

      if (result.success && result.cookies.isNotEmpty) {
        _pollTimer?.cancel();
        // 保存 cookies
        await context.read<SettingsProvider>().setBilibiliCookies(result.cookies);
        context.read<SearchProvider>().updateCookies(result.cookies);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录成功！')),
          );
          Navigator.pop(context);
        }
        return;
      }

      setState(() {
        _status = result.message;
        if (result.message.contains('已失效')) {
          _pollTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bilibili 扫码登录')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_qrCode != null)
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.network(
                        'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(_qrCode!.url)}',
                        width: 200,
                        height: 200,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 200,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.qr_code, size: 80),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _status.contains('成功')
                            ? Colors.green
                            : _status.contains('失效')
                                ? theme.colorScheme.error
                                : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_status.contains('失效'))
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新获取二维码'),
                        onPressed: _fetchQrCode,
                      ),
                  ],
                )
              else
                Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(_status, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                      onPressed: _fetchQrCode,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
