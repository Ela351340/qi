import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API Key 的安全存储。
///
/// 为什么不放 SharedPreferences：
/// prefs 是明文 XML，root/备份/调试都能直接读到；而且默认会被系统云备份。
/// 这里用 flutter_secure_storage，Android 上走 Keystore 加密的
/// EncryptedSharedPreferences，Key 不会以明文落盘。
class ApiKeyStore {
  static const String _prefix = 'llm_key_';

  // v11 默认就是 AES-GCM + Keystore 包装，无需额外开关
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// 读取所有 provider 的 Key，key = provider.id
  static Future<Map<String, String>> loadAll() async {
    try {
      final all = await _storage.readAll();
      final out = <String, String>{};
      all.forEach((k, v) {
        if (k.startsWith(_prefix)) {
          out[k.substring(_prefix.length)] = v;
        }
      });
      return out;
    } catch (_) {
      return const {};
    }
  }

  static Future<void> save(String providerId, String key) async {
    try {
      if (key.isEmpty) {
        await _storage.delete(key: '$_prefix$providerId');
      } else {
        await _storage.write(key: '$_prefix$providerId', value: key);
      }
    } catch (_) {
      // 安全存储不可用时降级：这一次不保存 Key，但不影响其余设置
    }
  }

  /// 把明文 Key 从旧版 prefs 里搬进安全存储后清空
  static Future<void> delete(String providerId) async {
    try {
      await _storage.delete(key: '$_prefix$providerId');
    } catch (_) {}
  }

  /// 调试用：导出键名（不含值）
  static Future<List<String>> keyNames() async {
    try {
      final all = await _storage.readAll();
      return all.keys.map((k) => k.replaceFirst(_prefix, '')).toList();
    } catch (_) {
      return const [];
    }
  }
}

/// 从 JSON 里剥离 Key 后再落盘的小工具
Map<String, dynamic> stripKeys(Map<String, dynamic> json) {
  final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  final providers = copy['providers'];
  if (providers is List) {
    for (final p in providers) {
      if (p is Map) p['apiKey'] = '';
    }
  }
  return copy;
}
