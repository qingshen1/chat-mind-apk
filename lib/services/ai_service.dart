import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class AIService {
  static Future<AnalysisResult> analyzeImage(
    Uint8List imageBytes, {
    required String scene,
    required List<String> baseValues,
    required Map<String, String> sceneValues,
  }) async {
    final apiKey = StorageService().apiKey;
    final model = StorageService().model;
    final endpoint = _resolveEndpoint(StorageService().apiUrl);

    if (apiKey.isEmpty) {
      throw Exception('请先在设置里配置 API Key');
    }

    final base64Image = base64Encode(imageBytes);
    final systemPrompt = _buildSystemPrompt(scene, baseValues, sceneValues);

    final requestBody = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
            {'type': 'text', 'text': '分析这张聊天截图，输出JSON格式结果。'},
          ],
        },
      ],
      'temperature': 0.3,
      'max_tokens': 1000,
    };

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 90), onTimeout: () {
      throw Exception('AI请求超时，请检查 API 地址和网络');
    });

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      throw Exception('AI请求失败: ${response.statusCode} ${_snippet(body)}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final content = data['choices']?[0]?['message']?['content'] as String?;

    if (content == null || content.isEmpty) {
      throw Exception('AI返回结果为空');
    }

    return _parseContent(content);
  }

  /// 把用户填的地址整理成完整的 chat/completions 接口地址。
  /// 空值用默认豆包接口；只填到 /v1、/v3 时自动补全；填了完整地址则原样使用。
  static String _resolveEndpoint(String raw) {
    var url = raw.trim();
    if (url.isEmpty) url = Constants.defaultApiUrl;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || (uri.host.isEmpty && uri.path.isEmpty)) {
      throw Exception('API 地址格式不正确，请填完整地址，例如 https://api.example.com/v1/chat/completions');
    }

    final lower = url.toLowerCase();
    if (lower.endsWith('/chat/completions') || lower.endsWith('/completions')) {
      return url;
    }

    // 末尾已经是版本段（/v1、/v3、/v4 ...）时只补 chat/completions
    final lastSegment = url.split('/').last;
    if (RegExp(r'^v\d+([a-z0-9.+-]*)$', caseSensitive: false).hasMatch(lastSegment)) {
      return '$url/chat/completions';
    }

    return '$url/v1/chat/completions';
  }

  /// 用当前配置发一个最小请求，验证地址、Key 和模型是否可用。
  /// 只消耗极少 token；失败时抛出可直接展示的说明。
  static Future<String> testConnection() async {
    final apiKey = StorageService().apiKey;
    final model = StorageService().model;
    final endpoint = _resolveEndpoint(StorageService().apiUrl);

    if (apiKey.isEmpty) {
      throw Exception('请先填写 API Key / Token');
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'ping'},
              ],
              'max_tokens': 8,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      throw Exception('连不上接口：${_snippet(e.toString())}');
    }

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      throw Exception('HTTP ${response.statusCode}：${_snippet(body)}');
    }

    return '连接成功（HTTP 200，模型 $model）';
  }

  static String _snippet(String text, [int max = 160]) {
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= max ? oneLine : '${oneLine.substring(0, max)}…';
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
      buffer.writeln('价值观约束：${baseValues.join('; ')}');
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
    buffer.writeln('输出格式（严格JSON）：');
    buffer.writeln(
      '{"psychology":"心理状态","intention":"意图","risk_warning":"风险","replies":[{"style":"风格","content":"回复"}]}',
    );

    return buffer.toString();
  }

  static AnalysisResult _parseContent(String content) {
    String jsonStr = content.trim();

    if (jsonStr.contains('```json')) {
      jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
    } else if (jsonStr.contains('```')) {
      jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
    }

    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AnalysisResult.fromJson(data);
  }
}
