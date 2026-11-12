import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../models/analysis_progress.dart';
import '../models/test_connection_result.dart';
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
    // 自动补全 /chat/completions，避免用户只填到 /v1 时 404
    final endpoint = Constants.normalizeChatUrl(baseUrl);
    final response = await http.post(
      Uri.parse(endpoint),
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

  // ==================== 流式分析（v2.2.2） ====================

  /// 流式分析聊天截图。
  ///
  /// 与 [analyzeImage] 的一次性返回不同，这里解析 SSE 增量，
  /// 每收到一段内容就产出一帧进度，界面可实时展示，首屏响应快得多。
  ///
  /// 若服务商忽略 stream 参数直接返回完整 JSON，也会自动兼容解析。
  static Stream<AnalysisProgress> analyzeImageStream(
    Uint8List imageBytes, {
    required String scene,
    required List<String> baseValues,
    required Map<String, String> sceneValues,
  }) async* {
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

    final List<dynamic> userContent;
    if (supportsVision) {
      userContent = [
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
        },
        {'type': 'text', 'text': '分析这张聊天截图，输出JSON格式结果。'},
      ];
    } else {
      userContent = [
        {
          'type': 'text',
          'text': '当前模型不支持图片输入，请切换到支持视觉的模型（如 GPT-4o、豆包 Vision、通义千问 VL 等）。',
        },
      ];
    }

    final requestBody = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      'temperature': storage.temperature,
      'max_tokens': storage.maxTokens,
      if (storage.topP < 1.0) 'top_p': storage.topP,
      'stream': true,
    };

    final endpoint = Constants.normalizeChatUrl(baseUrl);
    final client = http.Client();
    final stopwatch = Stopwatch()..start();
    int? firstTokenMs;
    final rawResponse = StringBuffer();
    final contentBuffer = StringBuffer();

    try {
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'text/event-stream',
      });
      request.body = jsonEncode(requestBody);

      final streamed = await client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('连接超时，请检查网络或 API 地址'),
      );

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw Exception(
          'API请求失败 (${streamed.statusCode}): ${_snippet(_extractErrorMessage(body))}',
        );
      }

      await for (final line
          in streamed.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        rawResponse.writeln(line);
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;

        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') break;

        try {
          final obj = jsonDecode(payload);
          final delta = obj['choices']?[0]?['delta']?['content'] as String?;
          if (delta == null || delta.isEmpty) continue;

          firstTokenMs ??= stopwatch.elapsedMilliseconds;
          contentBuffer.write(delta);
          yield AnalysisProgress(
            raw: contentBuffer.toString(),
            preview: _extractPreview(contentBuffer.toString()),
            receivedChars: contentBuffer.length,
            firstTokenMs: firstTokenMs,
          );
        } catch (_) {
          // 忽略无法解析的心跳行、注释行
        }
      }

      // 服务商忽略 stream 参数、直接返回完整 JSON 时走这里
      if (contentBuffer.isEmpty) {
        final fullContent = _extractContentFromFullResponse(rawResponse.toString());
        if (fullContent == null || fullContent.isEmpty) {
          throw StreamUnsupportedException(
            '接口没有返回可解析的流式内容（已尝试地址：$endpoint）',
          );
        }
        yield AnalysisProgress(
          raw: fullContent,
          preview: _extractPreview(fullContent),
          receivedChars: fullContent.length,
          firstTokenMs: stopwatch.elapsedMilliseconds,
          result: _parseContent(fullContent),
        );
        return;
      }

      final text = contentBuffer.toString();
      yield AnalysisProgress(
        raw: text,
        preview: _extractPreview(text),
        receivedChars: text.length,
        firstTokenMs: firstTokenMs,
        result: _parseContent(text),
      );
    } finally {
      client.close();
    }
  }

  /// 从完整的非流式响应体里取出 choices[0].message.content
  static String? _extractContentFromFullResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      final data = jsonDecode(trimmed);
      if (data is Map<String, dynamic>) {
        return data['choices']?[0]?['message']?['content'] as String?;
      }
    } catch (_) {
      // 不是完整 JSON，忽略
    }
    return null;
  }

  /// 从错误响应体里提取可读的错误信息
  static String _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map && err['message'] != null) {
          return err['message'].toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
    } catch (_) {
      // 直接返回原文
    }
    return body;
  }

  /// 截断过长的错误文本，避免刷屏
  static String _snippet(String text, [int max = 200]) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= max ? flat : '${flat.substring(0, max)}…';
  }

  /// 从流式累积的 JSON 文本里提取已完成字段，供界面实时预览
  static String _extractPreview(String text) {
    final parts = <String>[];

    final psychology = _extractStringField(text, 'psychology');
    if (psychology != null && psychology.isNotEmpty) {
      parts.add('对方心理：$psychology');
    }
    final intention = _extractStringField(text, 'intention');
    if (intention != null && intention.isNotEmpty) {
      parts.add('真实意图：$intention');
    }
    final risk = _extractStringField(text, 'risk_warning');
    if (risk != null && risk.isNotEmpty) {
      parts.add('风险提示：$risk');
    }
    return parts.join('\n\n');
  }

  /// 提取已完成（字符串已闭合）的 JSON 字段值，未闭合时返回 null
  static String? _extractStringField(String text, String key) {
    final pattern = RegExp('"' + key + r'"\s*:\s*"((?:[^"\\]|\\.)*)"');
    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final raw = match.group(1) ?? '';
    try {
      return jsonDecode('"' + raw + '"') as String;
    } catch (_) {
      return raw;
    }
  }

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
      // 404/405：多数第三方 / 中转站不开放 /models 接口，这不代表配置错了
      if (response.statusCode == 404 || response.statusCode == 405) {
        throw Exception(
          '该服务商没有开放模型列表接口（HTTP ${response.statusCode}）。\n\n'
          '这不影响正常使用，请直接在「模型名称」里手动填写你要用的模型，'
          '例如 gpt-4o、claude-3-5-sonnet、deepseek-chat 等。\n\n'
          '已尝试地址：$modelsUrl',
        );
      }
      String errMsg;
      try {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        errMsg = errData['error']?['message'] ??
            errData['message'] ??
            utf8.decode(response.bodyBytes);
      } catch (_) {
        errMsg = utf8.decode(response.bodyBytes);
      }
      throw Exception('获取模型列表失败 (${response.statusCode}): $errMsg\n已尝试地址：$modelsUrl');
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
      throw Exception(
        '接口有响应但没有返回模型列表。\n\n'
        '请直接在「模型名称」里手动填写模型名称。\n'
        '已尝试地址：$modelsUrl',
      );
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
      Uri.parse(Constants.normalizeChatUrl(baseUrl)),
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
