
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import '../models/analysis_result.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // API Key 缓存（SecureStorage 是异步的，用缓存保证同步读取）
  String _apiKeyCache = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // v2.2 迁移：将旧明文 API Key 移入 SecureStorage
    await _migrateApiKey();

    // 从 SecureStorage 加载 API Key 到缓存
    final secureKey = await _secureStorage.read(key: Constants.prefApiKey);
    _apiKeyCache = secureKey ?? '';
  }

  /// 迁移旧的明文 API Key 到加密存储
  Future<void> _migrateApiKey() async {
    final migrated = _prefs?.getBool(Constants.prefKeyMigrated) ?? false;
    if (migrated) return;

    final oldKey = _prefs?.getString(Constants.prefApiKey);
    if (oldKey != null && oldKey.isNotEmpty) {
      await _secureStorage.write(key: Constants.prefApiKey, value: oldKey);
      await _prefs?.remove(Constants.prefApiKey);
    }
    await _prefs?.setBool(Constants.prefKeyMigrated, true);
  }

  // ==================== API 配置 ====================

  /// API Key（加密存储，同步读取缓存）
  String get apiKey => _apiKeyCache;

  Future<void> setApiKey(String value) async {
    _apiKeyCache = value;
    await _secureStorage.write(key: Constants.prefApiKey, value: value);
  }

  String get model => _prefs?.getString(Constants.prefModel) ?? Constants.defaultModel;
  Future<void> setModel(String value) => _prefs?.setString(Constants.prefModel, value) ?? Future.value();

  String get baseUrl {
    final stored = _prefs?.getString(Constants.prefBaseUrl);
    if (stored != null && stored.isNotEmpty) return stored;
    final provider = Constants.getProviderById(apiProvider);
    return provider?['base_url'] as String? ?? Constants.defaultBaseUrl;
  }
  Future<void> setBaseUrl(String value) => _prefs?.setString(Constants.prefBaseUrl, value) ?? Future.value();

  String get apiProvider => _prefs?.getString(Constants.prefApiProvider) ?? Constants.defaultApiProvider;
  Future<void> setApiProvider(String value) => _prefs?.setString(Constants.prefApiProvider, value) ?? Future.value();

  /// 当前服务商是否支持视觉
  bool get supportsVision {
    final provider = Constants.getProviderById(apiProvider);
    return provider?['supports_vision'] as bool? ?? true;
  }

  /// 当前服务商显示名称
  String get providerName {
    final provider = Constants.getProviderById(apiProvider);
    return provider?['name'] as String? ?? '未知';
  }

  // ==================== v2.2 模型参数 ====================

  double get temperature => _prefs?.getDouble(Constants.prefTemperature) ?? Constants.defaultTemperature;
  Future<void> setTemperature(double value) => _prefs?.setDouble(Constants.prefTemperature, value) ?? Future.value();

  int get maxTokens => _prefs?.getInt(Constants.prefMaxTokens) ?? Constants.defaultMaxTokens;
  Future<void> setMaxTokens(int value) => _prefs?.setInt(Constants.prefMaxTokens, value) ?? Future.value();

  double get topP => _prefs?.getDouble(Constants.prefTopP) ?? Constants.defaultTopP;
  Future<void> setTopP(double value) => _prefs?.setDouble(Constants.prefTopP, value) ?? Future.value();

  // ==================== 场景设置 ====================

  String get currentScene => _prefs?.getString(Constants.prefScene) ?? Constants.scenes.first;
  Future<void> setScene(String value) => _prefs?.setString(Constants.prefScene, value) ?? Future.value();

  // ==================== 悬浮窗设置 ====================

  double get floatOpacity => _prefs?.getDouble(Constants.prefOpacity) ?? 0.85;
  Future<void> setOpacity(double value) => _prefs?.setDouble(Constants.prefOpacity, value) ?? Future.value();

  // ==================== 隐私 & 首次启动 ====================

  bool get privacyAgreed => _prefs?.getBool(Constants.prefPrivacyAgreed) ?? false;
  Future<void> setPrivacyAgreed(bool value) => _prefs?.setBool(Constants.prefPrivacyAgreed, value) ?? Future.value();

  bool get isFirstLaunch => _prefs?.getBool(Constants.prefFirstLaunch) ?? true;
  Future<void> setFirstLaunch(bool value) => _prefs?.setBool(Constants.prefFirstLaunch, value) ?? Future.value();

  // ==================== 价值观设置 ====================

  List<String> get baseValues => _prefs?.getStringList(Constants.prefValuesBase) ?? [];
  Future<void> setBaseValues(List<String> values) => _prefs?.setStringList(Constants.prefValuesBase, values) ?? Future.value();

  Map<String, String> get sceneValues {
    final raw = _prefs?.getString(Constants.prefValuesScene);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setSceneValues(Map<String, String> values) =>
      _prefs?.setString(Constants.prefValuesScene, jsonEncode(values)) ?? Future.value();

  // ==================== v2.2 评分反馈 ====================

  /// 保存回复评分
  /// rating: 1=赞, -1=踩
  Future<void> saveFeedback({
    required String scene,
    required String replyStyle,
    required int rating,
  }) async {
    final stats = _loadFeedbackStats();
    final key = scene;
    final current = stats[key] ?? {'good': 0, 'bad': 0};
    if (rating > 0) {
      current['good'] = (current['good'] ?? 0) + 1;
    } else {
      current['bad'] = (current['bad'] ?? 0) + 1;
    }
    stats[key] = current;
    await _prefs?.setString(Constants.prefFeedback, jsonEncode(stats));
  }

  /// 获取某场景的满意度百分比
  int getSceneSatisfaction(String scene) {
    final stats = _loadFeedbackStats();
    final s = stats[scene];
    if (s == null) return 0;
    final good = (s['good'] ?? 0) as int;
    final bad = (s['bad'] ?? 0) as int;
    final total = good + bad;
    if (total == 0) return 0;
    return (good * 100 / total).round();
  }

  Map<String, dynamic> _loadFeedbackStats() {
    final raw = _prefs?.getString(Constants.prefFeedback);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ==================== v2.2 回复模板库 ====================

  /// 保存回复为模板（点赞时自动调用）
  Future<void> saveTemplate(String scene, ReplyOption reply) async {
    final templates = loadTemplates();
    templates.insert(0, ReplyTemplate(
      scene: scene,
      style: reply.style,
      content: reply.content,
      savedAt: DateTime.now().toIso8601String(),
    ));
    // 最多保存 100 条
    final limited = templates.take(100).toList();
    final jsonList = limited.map((t) => t.toJson()).toList();
    await _prefs?.setString(Constants.prefTemplates, jsonEncode(jsonList));
  }

  /// 加载所有模板
  List<ReplyTemplate> loadTemplates() {
    final raw = _prefs?.getString(Constants.prefTemplates);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ReplyTemplate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 按场景过滤模板
  List<ReplyTemplate> loadTemplatesByScene(String scene) {
    return loadTemplates().where((t) => t.scene == scene).toList();
  }

  /// 删除模板
  Future<void> deleteTemplate(int index) async {
    final templates = loadTemplates();
    if (index < 0 || index >= templates.length) return;
    templates.removeAt(index);
    final jsonList = templates.map((t) => t.toJson()).toList();
    await _prefs?.setString(Constants.prefTemplates, jsonEncode(jsonList));
  }

  // ==================== v2.2 Token 统计 ====================

  /// 累加今日 Token 消耗
  Future<void> addTokenUsage(int tokens) async {
    final stats = _loadTokenStats();
    final today = _todayKey();
    stats[today] = (stats[today] ?? 0) + tokens;
    // 只保留最近 30 天
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    stats.removeWhere((k, v) {
      try {
        return DateTime.parse(k).isBefore(cutoff);
      } catch (_) {
        return true;
      }
    });
    await _prefs?.setString(Constants.prefTokenStats, jsonEncode(stats));
  }

  /// 获取今日 Token 消耗
  int get todayTokenUsage {
    final stats = _loadTokenStats();
    return stats[_todayKey()] ?? 0;
  }

  /// 获取总 Token 消耗
  int get totalTokenUsage {
    final stats = _loadTokenStats();
    return stats.values.fold(0, (a, b) => a + (b as int));
  }

  Map<String, int> _loadTokenStats() {
    final raw = _prefs?.getString(Constants.prefTokenStats);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
