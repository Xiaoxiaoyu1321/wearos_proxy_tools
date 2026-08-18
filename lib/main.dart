import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ProxyToolsApp());
}

const MethodChannel _channel = MethodChannel('wearos_proxy_tools/shizuku');

class ProxyToolsApp extends StatelessWidget {
  const ProxyToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WearOS Proxy Tools',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: const ProxyPage(),
    );
  }
}

class ProxyPage extends StatefulWidget {
  const ProxyPage({super.key});

  @override
  State<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends State<ProxyPage> {
  final TextEditingController _inputController = TextEditingController();

  String _currentProxy = '';
  String _status = '正在检查 Shizuku...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshProxy();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _refreshProxy() async {
    setState(() {
      _busy = true;
      _status = '正在读取当前代理...';
    });
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getProxy');
      if (!mounted) return;
      setState(() {
        _currentProxy = (result?['proxy'] as String?) ?? '';
        _status = '已读取当前代理';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.message ?? '读取失败';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '读取失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _ensurePermission() async {
    try {
      final availability =
          await _channel.invokeMapMethod<String, dynamic>('isAvailable');
      final available = availability?['available'] == true;
      final granted = availability?['granted'] == true;
      if (!available) {
        setState(() {
          _status = 'Shizuku 未运行，请先启动 Shizuku';
        });
        return false;
      }
      if (granted) return true;

      final result = await _channel
          .invokeMapMethod<String, dynamic>('requestPermission');
      final ok = result?['granted'] == true;
      if (!ok) {
        setState(() {
          _status = '未获得 Shizuku 权限';
        });
      }
      return ok;
    } on PlatformException catch (e) {
      setState(() {
        _status = e.message ?? 'Shizuku 权限请求失败';
      });
      return false;
    } catch (e) {
      setState(() {
        _status = 'Shizuku 权限请求失败: $e';
      });
      return false;
    }
  }

  Future<void> _setProxy() async {
    final value = _inputController.text.trim();
    if (value.isEmpty) {
      setState(() {
        _status = '请输入代理地址';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = '正在设置代理...';
    });

    final ok = await _ensurePermission();
    if (!ok) {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
      return;
    }

    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('setProxy', {
        'value': value,
      });
      if (!mounted) return;
      setState(() {
        _status = (result?['message'] as String?) ?? '设置完成';
      });
      await _refreshProxy();
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.message ?? '设置失败';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '设置失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _clearProxy() async {
    setState(() {
      _busy = true;
      _status = '正在清除代理...';
    });

    final ok = await _ensurePermission();
    if (!ok) {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
      return;
    }

    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('clearProxy');
      if (!mounted) return;
      setState(() {
        _status = (result?['message'] as String?) ?? '已清除代理';
      });
      await _refreshProxy();
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.message ?? '清除失败';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '清除失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('代理设置'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('当前代理', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _currentProxy),
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '未设置',
                  isDense: true,
                ),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text('设置新代理', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '例如 192.168.1.100:8080',
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _setProxy,
                icon: const Icon(Icons.save),
                label: const Text('设置代理'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _clearProxy,
                icon: const Icon(Icons.delete_forever),
                label: const Text('清除代理'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

