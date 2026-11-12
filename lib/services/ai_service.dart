import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class AIService {
  /// 分析聊天截图
  /// 支持任意 OpenAI 兼容格式的 API 端点
  static Future<AnalysisResult> analyzeImage(
    Uint8List imageBytes, {
    required String scene,
    required List<String> baseValues,
    required Map<String, String> sceneValues,
  }) async {
    final storage = StorageService();
    final apiKey = storage.apiKey;
    final model = storage.model;
    final baseUrl = storage.baseUrl;
    final supportsVision = storage.supportsVision;

    if (apiKey.isEmpty) {
      throw Exception('请先在设置中配置 API Key');
    }
    if (baseUrl.isEmpty) {
      throw Exception('请先在设置中配置 API 地址');
    }

    final base64Image = base64Encode(imageBytes);
    final systemPrompt = _buildSystemPrompt(scene, baseValues, sceneValues);

    // 构建请求体 —— 兼容 OpenAI 格式
    final List<dynamic> userContent;
    if (supportsVision) {
      // 支持视觉的模型：图片 + 文本
      userContent = [
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
        },
        {'type': 'text', 'text': '分析这张聊天截图，输出JSON格式结果。'},
      ];
    } else {
      // 不支持视觉的模型：仅文本提示（无法分析图片内容）
      userContent = [
        {'type': 'text', 'text': '当前模型不支持图片输入，请切换到支持视觉的模型（如 GPT-4o、豆包 Vision、通义千问 VL 等）。'},
      ];
    }

    // v2.2: 从 StorageService 动态读取模型参数（不再硬编码）
    final temperature = storage.temperature;
    final maxTokens = storage.maxTokens;
    final topP = storage.topP;

    final requestBody = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': userContent,
        },
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      if (topP < 1.0) 'top_p': topP,
    };

    // 构建请求头
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    // 发送请求
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode(requestBody),
    ).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('请求超时，请检查网络或更换 API 端点'),
    );

    if (response.statusCode != 200) {
      String errMsg;
      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        errMsg = errData['error']?['message'] ?? response.body;
      } catch (_) {
        errMsg = response.body;
      }
      throw Exception('API请求失败 (${response.statusCode}): $errMsg');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final content = data['choices']?[0]?['message']?['content'] as String?;

    if (content == null || content.isEmpty) {
      throw Exception('AI返回结果为空，请检查模型是否支持视觉输入');
    }

    // v2.2: 解析 Token 用量并累加统计
    final usage = data['usage'] as Map<String, dynamic>?;
    if (usage != null) {
      final total = (usage['total_tokens'] as num?)?.toInt() ?? 0;
      if (total > 0) {
        await storage.addTokenUsage(total);
      }
    }

    return _parseContent(content, usage: usage);
  }

  // ==================== 模型自动识别 ====================

  /// 自动识别可用模型列表
  /// 调用 OpenAI 兼容的 /models 接口获取当前 API Key 可用的所有模型
  static Future<List<String>> fetchAvailableModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('请先填写 API Key');
    }
    if (baseUrl.isEmpty) {
      throw Exception('请先填写 API 地址');
    }

    final modelsUrl = Constants.deriveModelsUrl(baseUrl);
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
    };

    final response = await http.get(
      Uri.parse(modelsUrl),
      headers: headers,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('请求超时，请检查网络或 API 地址'),
    );

    if (response.statusCode != 200) {
      String errMsg;
      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        errMsg = errData['error']?['message'] ??
            errData['message'] ??
            utf8.decode(response.bodyBytes);
      } catch (_) {
        errMsg = utf8.decode(response.bodyBytes);
      }
      throw Exception('获取模型列表失败 (${response.statusCode}): $errMsg');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final modelsList = data['data'] as List<dynamic>? ?? [];

    final modelIds = <String>[];
    for (final model in modelsList) {
      final id = model['id'] as String?;
      if (id != null && id.isNotEmpty) {
        modelIds.add(id);
      }
    }

    if (modelIds.isEmpty) {
      throw Exception('未获取到可用模型，请检查 API 地址是否正确');
    }

    modelIds.sort();
    return modelIds;
  }

  // ==================== 测试连接 ====================

  /// 测试 API 连接是否可用
  /// 发送一条极简消息（max_tokens=5）验证 API Key、模型、端点三者是否匹配
  static Future<TestConnectionResult> testConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('请先填写 API Key');
    }
    if (baseUrl.isEmpty) {
      throw Exception('请先填写 API 地址');
    }
    if (model.isEmpty) {
      throw Exception('请先填写模型名称');
    }

    final requestBody = {
      'model': model,
      'messages': [
        {'role': 'user', 'content': 'Hi'},
      ],
      'max_tokens': 5,
      'temperature': 0,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final stopwatch = Stopwatch()..start();

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode(requestBody),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('请求超时，请检查网络或 API 地址'),
    );

    stopwatch.stop();
    final latencyMs = stopwatch.elapsedMilliseconds;

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final replyContent =
          data['choices']?[0]?['message']?['content'] as String? ?? '';
      final actualModel = data['model'] as String? ?? model;
      return TestConnectionResult(
        success: true,
        message: '连接成功！API Key、模型、端点均可用',
        latencyMs: latencyMs,
        modelUsed: actualModel,
        replyPreview: replyContent,
      );
    } else {
      String errMsg;
      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        errMsg = errData['error']?['message'] ??
            errData['message'] ??
            utf8.decode(response.bodyBytes);
      } catch (_) {
        errMsg = utf8.decode(response.bodyBytes);
      }
      return TestConnectionResult(
        success: false,
        message: '连接失败 (HTTP ${response.statusCode})',
        latencyMs: latencyMs,
        errorDetail: errMsg,
      );
    }
  }

  static String _buildSystemPrompt(
    String scene,
    List<String> baseValues,
    Map<String, String> sceneValues,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('你是一位资深心理咨询师和高情商沟通顾问。');
    buffer.writeln('当前场景：$scene');
    buffer.writeln();

    if (baseValues.isNotEmpty) {
      // 将 id 转为可读文本
      final valueTexts = baseValues.map((id) {
        // 尝试从预设列表中找到对应文本
        try {
          return '${baseValuesMap[id] ?? id}';
        } catch (_) {
          return id;
        }
      }).join('; ');
      buffer.writeln('价值观约束：$valueTexts');
      buffer.writeln();
    }

    final sceneValue = sceneValues[scene];
    if (sceneValue != null && sceneValue.isNotEmpty) {
      buffer.writeln('场景约束：$sceneValue');
      buffer.writeln();
    }

    buffer.writeln('分析要求：');
    buffer.writeln('1. 分析对方心理状态、真实意图');
    buffer.writeln('2. 检测风险（PUA、情感操控、职场施压等）');
    buffer.writeln('3. 给出2-3个符合价值观的回复建议');
    buffer.writeln();
    buffer.writeln('输出格式（严格JSON，不要输出其他内容）：');
    buffer.writeln(
      '{"psychology":"心理状态","intention":"意图","risk_warning":"风险（无风险则为空字符串）","replies":[{"style":"风格","content":"回复内容"}]}',
    );

    return buffer.toString();
  }

  /// 基础价值观 id -> 文本 映射
  static const Map<String, String> baseValuesMap = {
    'sincere': '待人真诚，不主动算计、挖坑套路别人',
    'no_sarcasm': '拒绝阴阳怪气、嘲讽、报复性话术',
    'no_beg': '不卑不亢，不卑微讨好任何人',
    'no_pushover': '不做无底线老好人，懂得委婉自保',
    'no_gossip': '不背后诋毁、挑拨他人关系',
    'gentle': '沟通优先温和体面，尽量避免正面冲突',
    'no_hurt': '不使用尖锐、伤人、对立的语言',
  };

  static AnalysisResult _parseContent(String content, {Map<String, dynamic>? usage}) {
    String jsonStr = content.trim();

    // 尝试提取 JSON 块
    if (jsonStr.contains('```json')) {
      jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
    } else if (jsonStr.contains('```')) {
      jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
    }

    // 尝试直接提取 JSON 对象
    if (!jsonStr.startsWith('{')) {
      final start = jsonStr.indexOf('{');
      final end = jsonStr.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        jsonStr = jsonStr.substring(start, end + 1);
      }
    }

    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    // v2.2: 注入 Token 用量到解析结果
    if (usage != null) {
      data['usage'] = usage;
    }
    return AnalysisResult.fromJson(data);
  }
}
